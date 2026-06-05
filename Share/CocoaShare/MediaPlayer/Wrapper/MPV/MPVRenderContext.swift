//
//  MPVRenderContext.swift
//  CocoaShare
//
//  mpv SW render context 封装，mpv 直接渲染到调用方提供的内存 buffer
//

import Foundation
import Libmpv

/// 自由函数 trampoline，地址稳定，传递给 mpv 作为 C 回调不会变成野指针
private func mpvRenderUpdateTrampoline(_ userData: UnsafeMutableRawPointer?) {
    guard let userData = userData else { return }
    let ctx = Unmanaged<MPVRenderContext>.fromOpaque(userData).takeUnretainedValue()
    ctx.onUpdate()
}

/// `MPV_RENDER_API_TYPE_SW` 是 C `#define` 宏，不导入 Swift，需手动声明
private let kMPVRenderAPITypeSW = "sw"

/// 封装 mpv_render_context，使用 SW (software) 后端
/// mpv 直接渲染到调用方提供的内存 buffer，无 GPU 依赖
public class MPVRenderContext {
    private var ctx: OpaquePointer?

    /// 创建 SW render context。必须在 mpv_initialize() 之前调用。
    public init?(mpvHandle: OpaquePointer) {
        let ret = kMPVRenderAPITypeSW.withCString { apiTypePtr in
            var params = [
                mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: UnsafeMutableRawPointer(mutating: apiTypePtr)),
                mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
            ]
            var ctxPtr: OpaquePointer?
            let r = mpv_render_context_create(&ctxPtr, mpvHandle, &params)
            if r >= 0, let ctx = ctxPtr {
                self.ctx = ctx
            }
            return r
        }
        guard ret >= 0, ctx != nil else { return nil }
    }

    /// 渲染当前视频帧到指定内存 buffer
    /// - Parameters:
    ///   - data: 目标 buffer 指针（bgr0 格式）
    ///   - width: 渲染目标宽度
    ///   - height: 渲染目标高度
    ///   - stride: 每行字节数（width * 4，建议对齐到 64 字节）
    ///   - format: 像素格式，默认 "bgr0"
    ///   - blockForTarget: 是否等待到目标显示时间再返回
    public func render(to data: UnsafeMutableRawPointer,
                width: Int, height: Int,
                stride: Int, format: String = "bgr0",
                blockForTarget: Bool = false) -> Bool {
        guard let ctx = ctx else { return false }
        var swSize: [Int32] = [Int32(width), Int32(height)]
        var swStride = stride
        var block: Int32 = blockForTarget ? 1 : 0

        return swSize.withUnsafeMutableBytes { swSizeBytes in
            withUnsafeMutablePointer(to: &swStride) { swStridePtr in
                withUnsafeMutablePointer(to: &block) { blockPtr in
                    format.withCString { formatPtr in
                        var params = [
                            mpv_render_param(type: MPV_RENDER_PARAM_SW_SIZE, data: swSizeBytes.baseAddress),
                            mpv_render_param(type: MPV_RENDER_PARAM_SW_FORMAT, data: UnsafeMutableRawPointer(mutating: formatPtr)),
                            mpv_render_param(type: MPV_RENDER_PARAM_SW_STRIDE, data: swStridePtr),
                            mpv_render_param(type: MPV_RENDER_PARAM_SW_POINTER, data: data),
                            mpv_render_param(type: MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, data: blockPtr),
                            mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
                        ]
                        return mpv_render_context_render(ctx, &params) >= 0
                    }
                }
            }
        }
    }

    /// 设置更新回调。mpv 有新帧可渲染时触发。回调在 mpv 内部线程执行，不要在回调中调用 mpv API。
    public func setUpdateCallback(_ callback: @escaping () -> Void) {
        guard let ctx = ctx else { return }
        self.storedUpdateCallback = callback
        let unmanaged = Unmanaged.passUnretained(self)
        mpv_render_context_set_update_callback(ctx, mpvRenderUpdateTrampoline, unmanaged.toOpaque())
    }

    fileprivate func onUpdate() {
        storedUpdateCallback?()
    }

    private var storedUpdateCallback: (() -> Void)?

    deinit {
        if let ctx = ctx {
            mpv_render_context_free(ctx)
        }
    }
}
