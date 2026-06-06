//
//  MPVFrameRenderer.swift
//  CocoaShare
//
//  从 mpv_render_context 渲染帧到 CMSampleBuffer 的独立管线
//  MPVPlayerWrapper 和 MPVPiPProvider 共用，消除重复代码
//

import Foundation
import AVFoundation
#if !os(tvOS)
import ANXLog
#endif

class MPVFrameRenderer {

    // MARK: - 输出回调

    /// 帧就绪（主线程）
    var onFrame: ((CMSampleBuffer) -> Void)?

    /// 视频尺寸变化
    var onVideoSizeChange: ((CGSize) -> Void)?

    // MARK: - 外部数据源

    /// 当前位置（从 mpv.time.position 读取）
    var positionProvider: (() -> Double)?

    /// 视频原始尺寸（从 mpv.videoSize 读取）
    var videoSizeProvider: (() -> CGSize)?

    // MARK: - 配置

    /// 输出分辨率缩放（1.0 = 原生，0.5 = 半分辨率用于 PiP）
    var outputScale: CGFloat = 1.0

    // MARK: - 私有

    private var renderContext: MPVRenderContext?
    private let queue = DispatchQueue(label: "com.anxplayer.renderer", qos: .userInitiated)
    private var isCapturing = false
    private var frameRequested = false
    private var renderBuffer: UnsafeMutableRawPointer?
    private var renderBufferSize: Int = 0
    private(set) var videoSize: CGSize = .zero
    private var deliveredFrameCount = 0

    // MARK: - 生命周期

    /// 创建 render context 并注册 update callback。必须在 mpv_initialize() 之前调用。
    func create(mpvHandle: OpaquePointer) -> Bool {
        guard let ctx = MPVRenderContext(mpvHandle: mpvHandle) else {
            return false
        }
        self.renderContext = ctx
        ctx.setUpdateCallback { [weak self] in
            self?.onUpdateCallback()
        }
        return true
    }

    private func onUpdateCallback() {
        requestFrame()
    }

    /// 请求渲染一帧（去重：避免积压多余工作项）
    func requestFrame() {
        guard !frameRequested else { return }
        frameRequested = true
        queue.async { [weak self] in
            guard let self = self else { return }
            self.frameRequested = false
            self.captureAndDeliverFrame()
        }
    }

    /// 启动渲染（重置状态，下次 update callback 触发时开始产出帧）
    func startRendering() {
        videoSize = .zero
        deliveredFrameCount = 0
    }

    /// 停止渲染
    func stopRendering() {}

    /// 清理所有资源，与渲染队列同步
    func terminate() {
        queue.sync {
            renderBuffer?.deallocate()
            renderBuffer = nil
            renderBufferSize = 0
            renderContext = nil
            videoSize = .zero
        }
    }

    // MARK: - 帧捕获管线

    private func captureAndDeliverFrame() {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        guard let ctx = renderContext else { return }

        readVideoSizeIfNeeded()
        let srcSize = videoSize
        guard srcSize.width > 0, srcSize.height > 0 else { return }

        let scale = max(outputScale, 0.1)
        let width = max(Int(srcSize.width * scale), 1)
        let height = max(Int(srcSize.height * scale), 1)

        // 分配 / 调整 buffer
        let stride = width * 4
        let alignedStride = ((stride + pipBufferAlignment - 1) / pipBufferAlignment) * pipBufferAlignment
        let neededSize = alignedStride * height
        if neededSize != renderBufferSize {
            renderBuffer?.deallocate()
            renderBuffer = UnsafeMutableRawPointer.allocate(byteCount: neededSize, alignment: pipBufferAlignment)
            renderBufferSize = neededSize
        }

        guard let buffer = renderBuffer,
              ctx.render(to: buffer, width: width, height: height,
                         stride: alignedStride, format: "bgr0",
                         blockForTarget: false) else {
            ANX.logError(.player, "[FrameRenderer] mpv_render_context_render 失败")
            return
        }

        // CVPixelBuffer（iOS 需要 IOSurface 支持才能被 AVSampleBufferDisplayLayer 接受）
        var pixelBuffer: CVPixelBuffer?
        let pixelBufferAttrs: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferMetalCompatibilityKey: true,
        ]
        let cvRet = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, pixelBufferAttrs as CFDictionary, &pixelBuffer)
        guard cvRet == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            ANX.logError(.player, "[FrameRenderer] CVPixelBuffer 创建失败: \(cvRet)")
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let dstBaseAddr = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            ANX.logError(.player, "[FrameRenderer] CVPixelBuffer baseAddress 为 nil")
            return
        }
        let dstStride = CVPixelBufferGetBytesPerRow(pixelBuffer)

        let srcPtr = buffer.assumingMemoryBound(to: UInt8.self)
        let dstPtr = dstBaseAddr.assumingMemoryBound(to: UInt8.self)
        let copyBytes = width * 4
        for y in 0..<height {
            let srcRow = srcPtr.advanced(by: y * alignedStride)
            let dstRow = dstPtr.advanced(by: y * dstStride)
            dstRow.update(from: srcRow, count: copyBytes)
        }

        // CMSampleBuffer
        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDesc)
        guard let formatDesc = formatDesc else {
            ANX.logError(.player, "[FrameRenderer] CMVideoFormatDescription 创建失败")
            return
        }

        let pos = positionProvider?() ?? 0
        let pts = CMTime(seconds: pos, preferredTimescale: pipTimescale)
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: pts, decodeTimeStamp: .invalid)

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixelBuffer,
                                                  formatDescription: formatDesc,
                                                  sampleTiming: &timing,
                                                  sampleBufferOut: &sampleBuffer)
        guard let sampleBuffer = sampleBuffer else {
            ANX.logError(.player, "[FrameRenderer] CMSampleBuffer 创建失败")
            return
        }

        deliveredFrameCount += 1
        if deliveredFrameCount == 1 {
            ANX.logInfo(.player, "[FrameRenderer] 首帧交付成功 (\(width)x\(height))")
        }

        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(sampleBuffer)
        }
    }

    private func readVideoSizeIfNeeded() {
        guard videoSize == .zero else { return }
        guard let size = videoSizeProvider?(), size != .zero else { return }
        videoSize = size
        ANX.logInfo(.player, "[FrameRenderer] 视频尺寸: \(Int(size.width))x\(Int(size.height))")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onVideoSizeChange?(self.videoSize)
        }
    }
}
