//
//  MPV.swift
//  CocoaShare
//
//  libmpv C API 的 Swift 风格封装
//  将 mpv_* C 函数封装为面向对象的 Swift 接口
//  参考 mpv 官方文档 (https://mpv.io/manual/stable/) 进行模块化设计
//

#if os(iOS) || os(tvOS)

import Foundation
import Libmpv
import UIKit
#elseif os(macOS)
import Foundation
import Libmpv
import AppKit
#else
import Foundation
#endif

#if os(iOS) || os(macOS) || os(tvOS)

// MARK: - MPV 事件类型

/// MPV 事件 ID
///
/// 详细说明参考 mpv 官方文档: https://mpv.io/manual/stable/
public enum MPVEventID: Int {
    /// 无事件发生。超时或偶发唤醒时触发。
    case none = 0

    /// 播放器退出时触发。播放器进入状态，尝试断开所有客户端的连接。
    /// 大多数对播放器的请求将失败，客户端应该响应此事件并尽快调用 mpv_destroy() 退出。
    case shutdown = 1

    /// 查看 mpv_request_log_messages()。
    case logMessage = 2

    /// 响应 mpv_get_property_async() 请求。
    /// 参见 mpv_event 和 mpv_event_property。
    case getPropertyReply = 3

    /// 响应 mpv_set_property_async() 请求。
    case setPropertyReply = 4

    /// 响应 mpv_command_async() 或 mpv_command_node_async() 请求。
    /// 参见 mpv_event 和 mpv_event_command。
    case commandReply = 5

    /// 文件播放开始前触发（文件加载前）。
    /// 参见 mpv_event 和 mpv_event_start_file。
    case startFile = 6

    /// 播放结束后触发（文件卸载后）。
    /// 参见 mpv_event 和 mpv_event_end_file。
    case endFile = 7

    /// 文件加载完成时触发（已读取头信息等），解码开始。
    case fileLoaded = 8

    /// 进入空闲模式。没有文件播放，播放核心等待新命令。
    ///
    /// @deprecated 等同于使用 mpv_observe_property() 观察 "idle-active" 属性。
    ///             此事件是冗余的，可能会在将来被移除。
    case idle = 11

    /// 每次显示视频帧后触发。当前如果没有视频或播放暂停，会以较低频率发送。
    ///
    /// @deprecated 建议使用 mpv_observe_property() 观察相关属性（如 "playback-time"）。
    case tick = 14

    /// 由 script-message 输入命令触发。命令使用第一个参数作为客户端名称来分发消息，
    /// 并将第二个参数开始的所有参数作为字符串传递。
    /// 参见 mpv_event 和 mpv_event_client_message。
    case clientMessage = 16

    /// 视频以某种方式改变时触发。可能发生在分辨率变化、像素格式变化或视频滤镜变化时。
    /// 此事件在视频滤镜和 VO 重新配置后发送。嵌入 mpv 窗口的应用程序应监听此事件以便调整窗口大小。
    /// 注意：此事件可能随机发生，在执行昂贵操作之前应自行检查视频参数是否真的发生了变化。
    case videoReconfig = 17

    /// 类似于 MPV_EVENT_VIDEO_RECONFIG。由于没有音频输出嵌入等功能，这个事件相对不太有趣。
    case audioReconfig = 18

    /// 开始跳转时触发。播放停止。通常跳转完成后会通过 MPV_EVENT_PLAYBACK_RESTART 恢复播放。
    case seek = 20

    /// 发生某种不连续（如跳转），播放重新初始化。通常在播放开始和跳转后发生。
    /// 主要目的是允许客户端检测跳转请求何时完成。
    case playbackRestart = 21

    /// 因 mpv_observe_property() 发送的事件。
    /// 参见 mpv_event 和 mpv_event_property。
    case propertyChange = 22

    /// 如果内部每个 mpv_handle 的环形缓冲区溢出，至少有 1 个事件被丢弃时触发。
    /// 可能发生在客户端没有足够快地使用 mpv_wait_event() 读取事件队列，
    /// 或者客户端一次发出大量异步调用时。
    ///
    /// 返回此事件后，事件传递将正常继续（这会强制客户端完全清空队列）。
    case queueOverflow = 24

    /// 如果使用 mpv_hook_add() 注册了钩子处理程序，并且钩子被调用时触发。
    /// 收到此事件后必须处理它，并使用 mpv_hook_continue() 继续钩子。
    /// 参见 mpv_event 和 mpv_event_hook。
    case hook = 25

    init(from rawValue: mpv_event_id) {
        self = MPVEventID(rawValue: Int(rawValue.rawValue)) ?? .none
    }
}

// MARK: - 事件类型匹配

/// 事件类型，用于注册处理器
public enum MPVEventType {
    /// 属性变化事件
    case propertyChange(String)
    /// 文件加载完成
    case fileLoaded
    /// 文件开始播放
    case startFile
    /// 文件播放结束
    case endFile
    /// 播放重启（seek后等）
    case playbackRestart
    /// seek开始
    case seek
    /// 视频重新配置
    case videoReconfig
    /// 音频重新配置
    case audioReconfig
    /// 关机
    case shutdown
    /// 日志消息
    case logMessage
    /// 客户端消息
    case clientMessage
    /// 空闲状态
    case idle
    /// 任意事件（用于 onEvent）
    case any

    func matches(_ event: MPVEvent) -> Bool {
        switch self {
        case .any:
            return true
        case .propertyChange(let name):
            if case .property(let propName, _) = event.data {
                return propName == name
            }
            return event.id == .propertyChange && name.isEmpty
        case .fileLoaded:
            return event.id == .fileLoaded
        case .startFile:
            return event.id == .startFile
        case .endFile:
            return event.id == .endFile
        case .playbackRestart:
            return event.id == .playbackRestart
        case .seek:
            return event.id == .seek
        case .videoReconfig:
            return event.id == .videoReconfig
        case .audioReconfig:
            return event.id == .audioReconfig
        case .shutdown:
            return event.id == .shutdown
        case .logMessage:
            return event.id == .logMessage
        case .clientMessage:
            return event.id == .clientMessage
        case .idle:
            return event.id == .idle
        }
    }
}

public class MPVMedia {
    
    
    public private(set)var url: URL
    
    public var options: [String: String]?
    
    public init(url: URL, options: [String: String]? = nil) {
        self.url = url
        self.options = options
    }
}

// MARK: - MPV Node 类型

/// MPV Node 值（用于复杂数据结构）
public enum MPVNodeValue {
    case string(String)
    case flag(Bool)
    case int64(Int64)
    case double(Double)
    case array([MPVNodeValue])
    case map([String: MPVNodeValue])
    case byteArray(Data)

    init(from node: mpv_node) {
        switch node.format {
        case MPV_FORMAT_STRING:
            self = .string(String(cString: node.u.string))
        case MPV_FORMAT_FLAG:
            self = .flag(node.u.flag != 0)
        case MPV_FORMAT_INT64:
            self = .int64(node.u.int64)
        case MPV_FORMAT_DOUBLE:
            self = .double(node.u.double_)
        case MPV_FORMAT_NODE_ARRAY:
            self = .array(Self.parseArray(node.u.list))
        case MPV_FORMAT_NODE_MAP:
            self = .map(Self.parseMap(node.u.list))
        case MPV_FORMAT_BYTE_ARRAY:
            if let ba = node.u.ba {
                self = .byteArray(Data(bytes: ba.pointee.data, count: ba.pointee.size))
            } else {
                self = .byteArray(Data())
            }
        default:
            self = .string("")
        }
    }

    private static func parseArray(_ list: UnsafeMutablePointer<mpv_node_list>?) -> [MPVNodeValue] {
        guard let list = list else { return [] }
        var result: [MPVNodeValue] = []
        let count = Int(list.pointee.num)
        for i in 0..<count {
            let value = list.pointee.values[i]
            result.append(MPVNodeValue(from: value))
        }
        return result
    }

    private static func parseMap(_ list: UnsafeMutablePointer<mpv_node_list>?) -> [String: MPVNodeValue] {
        guard let list = list else { return [:] }
        var result: [String: MPVNodeValue] = [:]
        let count = Int(list.pointee.num)
        for i in 0..<count {
            guard let keyPtr = list.pointee.keys[i] else { continue }
            let key = String(cString: keyPtr)
            let value = list.pointee.values[i]
            result[key] = MPVNodeValue(from: value)
        }
        return result
    }
}

/// MPV Node 包装器
public struct MPVNode {
    public let value: MPVNodeValue

    public init(from node: mpv_node) {
        self.value = MPVNodeValue(from: node)
    }

    /// 获取字符串值
    public var stringValue: String? {
        if case .string(let s) = value { return s }
        return nil
    }

    /// 获取布尔值
    public var flagValue: Bool? {
        if case .flag(let f) = value { return f }
        return nil
    }

    /// 获取整数值
    public var int64Value: Int64? {
        if case .int64(let i) = value { return i }
        return nil
    }

    /// 获取浮点值
    public var doubleValue: Double? {
        if case .double(let d) = value { return d }
        return nil
    }

    /// 获取数组
    public var arrayValue: [MPVNodeValue]? {
        if case .array(let a) = value { return a }
        return nil
    }

    /// 获取字典
    public var mapValue: [String: MPVNodeValue]? {
        if case .map(let m) = value { return m }
        return nil
    }
}

// MARK: - MPV 属性值

/// MPV 属性值类型
public enum MPVPropertyValue {
    case string(String)
    case osdString(String)
    case flag(Bool)
    case int64(Int64)
    case double(Double)
    case node(MPVNode)
    case none

    init(from format: mpv_format, data: UnsafeRawPointer?) {
        guard let data = data else {
            self = .none
            return
        }

        switch format {
        case MPV_FORMAT_STRING:
            let str = data.assumingMemoryBound(to: UnsafePointer<CChar>.self).pointee
            self = .string(String(cString: str))
        case MPV_FORMAT_OSD_STRING:
            let str = data.assumingMemoryBound(to: UnsafePointer<CChar>.self).pointee
            self = .osdString(String(cString: str))
        case MPV_FORMAT_FLAG:
            let flag = data.assumingMemoryBound(to: Int32.self).pointee
            self = .flag(flag != 0)
        case MPV_FORMAT_INT64:
            let value = data.assumingMemoryBound(to: Int64.self).pointee
            self = .int64(value)
        case MPV_FORMAT_DOUBLE:
            let value = data.assumingMemoryBound(to: Double.self).pointee
            self = .double(value)
        case MPV_FORMAT_NODE:
            let node = data.assumingMemoryBound(to: mpv_node.self).pointee
            self = .node(MPVNode(from: node))
        default:
            self = .none
        }
    }
}

// MARK: - MPV 事件数据

/// MPV 事件数据
public enum MPVEventData {
    /// 属性变化事件数据
    case property(name: String, value: MPVPropertyValue)
    /// 日志消息事件数据
    case logMessage(prefix: String, level: String, text: String)
    /// 客户端消息事件数据
    case clientMessage(args: [String])
    /// 文件开始事件数据
    case startFile(playlistEntryId: Int64)
    /// 文件结束事件数据
    case endFile(reason: MPVEndFileReason, error: Int, playlistEntryId: Int64, playlistInsertId: Int64, playlistInsertNumEntries: Int)
    /// 钩子事件数据
    case hook(name: String, id: UInt64)
    /// 命令回复事件数据
    case commandReply(result: mpv_node)
    /// 空数据（用于无data的事件）
    case none
}

/// MPV 文件结束原因
public enum MPVEndFileReason: UInt32 {
    /// 文件结束
    case eof = 0
    /// 播放停止
    case stop = 2
    /// 退出
    case quit = 3
    /// 错误
    case error = 4
    /// 重定向
    case redirect = 5

    init(from reason: Int32) {
        self = MPVEndFileReason(rawValue: UInt32(bitPattern: reason)) ?? .eof
    }
}

/// MPV 事件包装器
public struct MPVEvent {
    /// 事件ID
    public let id: MPVEventID
    /// 错误码（用于回复类事件：GET_PROPERTY_REPLY, SET_PROPERTY_REPLY, COMMAND_REPLY）
    public let error: Int
    /// 回复用户数据（用于回复类事件和 PROPERTY_CHANGE, HOOK）
    public let replyUserdata: UInt64
    /// 事件数据
    public let data: MPVEventData

    init(from event: UnsafeMutablePointer<mpv_event>) {
        self.id = MPVEventID(from: event.pointee.event_id)
        self.error = Int(event.pointee.error)
        self.replyUserdata = event.pointee.reply_userdata

        guard let eventData = event.pointee.data else {
            self.data = .none
            return
        }

        switch self.id {
        case .getPropertyReply, .propertyChange:
            let property = eventData.assumingMemoryBound(to: mpv_event_property.self).pointee
            let name = String(cString: property.name)
            let value = MPVPropertyValue(from: property.format, data: property.data)
            self.data = .property(name: name, value: value)

        case .logMessage:
            let logMsg = eventData.assumingMemoryBound(to: mpv_event_log_message.self).pointee
            let prefix = String(cString: logMsg.prefix)
            let level = String(cString: logMsg.level)
            let text = String(cString: logMsg.text)
            self.data = .logMessage(prefix: prefix, level: level, text: text)

        case .clientMessage:
            let clientMsg = eventData.assumingMemoryBound(to: mpv_event_client_message.self).pointee
            var args: [String] = []
            for i in 0..<Int(clientMsg.num_args) {
                if let arg = clientMsg.args?[i] {
                    args.append(String(cString: arg))
                }
            }
            self.data = .clientMessage(args: args)

        case .startFile:
            let startFile = eventData.assumingMemoryBound(to: mpv_event_start_file.self).pointee
            self.data = .startFile(playlistEntryId: startFile.playlist_entry_id)

        case .endFile:
            let endFile = eventData.assumingMemoryBound(to: mpv_event_end_file.self).pointee
            let reason = MPVEndFileReason(rawValue: endFile.reason.rawValue) ?? .eof
            self.data = .endFile(
                reason: reason,
                error: Int(endFile.error),
                playlistEntryId: endFile.playlist_entry_id,
                playlistInsertId: endFile.playlist_insert_id,
                playlistInsertNumEntries: Int(endFile.playlist_insert_num_entries)
            )

        case .hook:
            let hook = eventData.assumingMemoryBound(to: mpv_event_hook.self).pointee
            let name = String(cString: hook.name)
            self.data = .hook(name: name, id: hook.id)

        case .commandReply:
            let commandReply = eventData.assumingMemoryBound(to: mpv_event_command.self).pointee
            self.data = .commandReply(result: commandReply.result)

        default:
            self.data = .none
        }
    }
}

// MARK: - MPV 属性

/// MPV 属性名称
public enum MPVProperty {
    // Playback
    case pause
    case cache
    case playbackTime
    case speed
    case endOfReached

    // Time
    case timePos
    case timeStart
    case duration
    case remaining

    // Audio
    case audioId
    case audioDevice
    case audioDelay
    case volume
    case mute

    // Video
    case videoId
    case videoAspect
    case fullscreen
    case windowId
    case hwdec

    // Subtitle
    case subtitleId
    case secondarySubtitleId
    case subtitleDelay
    case subtitleYPosition
    case subtitleFontSize
    case subtitleColor
    case subtitleBackColor
    case subtitleFont
    case subtitleFontsDir
    case subtitleAss
    case subtitleAssOverride
    case subtitleAuto
    case subtitleUseMargins
    case subtitleMarginY
    case subtitlePos

    // Track
    case trackList
    case trackType(Int)
    case trackId(Int)
    case trackTitle(Int)
    case trackLang(Int)

    // Screenshot
    case screenshotMode

    // VO
    case vo
    case gpuApi
    case gpuContext

    case protocolList

    public var rawValue: String {
        switch self {
        case .pause: return "pause"
        case .cache: return "cache"
        case .playbackTime: return "playback-time"
        case .speed: return "speed"
        case .timePos: return "time-pos"
        case .timeStart: return "time-start"
        case .duration: return "duration"
        case .remaining: return "remaining"
        case .audioId: return "aid"
        case .audioDevice: return "audio-device"
        case .audioDelay: return "audio-delay"
        case .volume: return "volume"
        case .mute: return "mute"
        case .videoId: return "vid"
        case .videoAspect: return "video-aspect-override"
        case .fullscreen: return "fullscreen"
        case .windowId: return "wid"
        case .hwdec: return "hwdec"
        case .subtitleId: return "sid"
        case .secondarySubtitleId: return "secondary-sid"
        case .subtitleDelay: return "sub-delay"
        case .subtitleYPosition: return "sub-margin"
        case .subtitleFontSize: return "sub-font-size"
        case .subtitleColor: return "sub-color"
        case .subtitleBackColor: return "sub-back-color"
        case .subtitleFont: return "sub-font"
        case .subtitleFontsDir: return "sub-fonts-dir"
        case .subtitleAss: return "sub-ass"
        case .subtitleAssOverride: return "sub-ass-override"
        case .subtitleAuto: return "sub-auto"
        case .subtitleUseMargins: return "sub-use-margins"
        case .subtitleMarginY: return "sub-margin-y"
        case .subtitlePos: return "sub-pos"
        case .trackList: return "track-list"
        case .trackType(let i): return "track-list/\(i)/type"
        case .trackId(let i): return "track-list/\(i)/id"
        case .trackTitle(let i): return "track-list/\(i)/title"
        case .trackLang(let i): return "track-list/\(i)/lang"
        case .screenshotMode: return "screenshot-mode"
        case .vo: return "vo"
        case .gpuApi: return "gpu-api"
        case .gpuContext: return "gpu-context"
        case .protocolList: return "protocol-list"
        case .endOfReached: return "eof-reached"
        }
    }
}

// MARK: - MPV 命令

/// MPV 命令
public enum MPVCommand {
    // File
    case loadFile
    case stop

    // Seek
    case seek
    case revertSeek

    // Track
    case trackSelect
    case subAdd
    case subRemove
    case audioAdd
    case audioRemove

    // Subtitle
    case subSeek

    // Property
    case set
    case add
    case multiply
    case cycle
    case cycleValues

    // Screenshot
    case screenshot
    case screenshotToFile

    // OSD
    case showText
    case overlayAdd
    case overlayRemove

    // Other
    case quit

    public var rawValue: String {
        switch self {
        case .loadFile: return "loadfile"
        case .stop: return "stop"
        case .seek: return "seek"
        case .revertSeek: return "revert-seek"
        case .trackSelect: return "track-select"
        case .subAdd: return "sub-add"
        case .subRemove: return "sub-remove"
        case .audioAdd: return "audio-add"
        case .audioRemove: return "audio-remove"
        case .subSeek: return "sub-seek"
        case .set: return "set"
        case .add: return "add"
        case .multiply: return "multiply"
        case .cycle: return "cycle"
        case .cycleValues: return "cycle-values"
        case .screenshot: return "screenshot"
        case .screenshotToFile: return "screenshot-to-file"
        case .showText: return "show-text"
        case .overlayAdd: return "overlay-add"
        case .overlayRemove: return "overlay-remove"
        case .quit: return "quit"
        }
    }
}

// MARK: - 辅助方法扩展

extension MPV {
    /// 执行 mpv 命令
    public func execute(_ command: MPVCommand, args: [String] = []) {
        let newArgs = [command.rawValue] + args
        var cargs = newArgs.map { UnsafePointer<CChar>(strdup($0)) }
        cargs.append(nil)
        
        cargs.withUnsafeMutableBufferPointer { [weak self] buffer in
            guard let self = self else { return }
            mpv_command(self.mpv, buffer.baseAddress)
        }
        
        for ptr in cargs {
            if let p = ptr {
                free(UnsafeMutablePointer(mutating: p))
            }
        }
    }

    /// 转换颜色为十六进制字符串
    #if os(iOS) || os(tvOS)
    fileprivate static func colorToHex(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    #elseif os(macOS)
    fileprivate static func colorToHex(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X",
                      Int(rgb.redComponent * 255),
                      Int(rgb.greenComponent * 255),
                      Int(rgb.blueComponent * 255))
    }
    #endif
}

// MARK: - MPV 主类

public class MPV {

    // MARK: - 私有属性

    private var mpv: OpaquePointer?
    private let eventQueue: DispatchQueue = DispatchQueue(label: "com.cocoashare.mpv.event")
    private var eventHandlers: [EventHandler] = []
    private var observedProperties: Set<String> = []
    private var propertyChangeHandlers: [String: [(MPVPropertyValue) -> Void]] = [:]

    /// 事件循环状态
    /// - idle: 循环未运行，可以启动新循环
    /// - running: 循环正在运行，shutdown时会转为idle
    private enum LoopState {
        case idle
        case running
    }
    private var loopState: LoopState = .idle

    /// 事件处理器结构
    private struct EventHandler {
        let type: MPVEventType
        let handler: (MPVEvent) -> Void
    }

    // MARK: - 类型安全的 API (lazy 存储)

    public lazy var playback = PlaybackAPI(mpv: self)
    public lazy var time = TimeAPI(mpv: self)
    public lazy var audio = AudioAPI(mpv: self)
    public lazy var video = VideoAPI(mpv: self)
    public lazy var subtitle = SubtitleAPI(mpv: self)
    public lazy var track = TrackAPI(mpv: self)
    public lazy var screenshot = ScreenshotAPI(mpv: self)

    // MARK: - 初始化

    public init?() {
        guard let handle = mpv_create() else {
            return nil
        }
        self.mpv = handle
    }

    deinit {
        if let mpv = mpv {
            mpv_terminate_destroy(mpv)
        }
    }

    // MARK: - 选项设置

    /// 设置字符串选项
    public func setOptionString(_ property: MPVProperty, _ value: String) {
        guard let mpv = mpv else { return }
        mpv_set_option_string(mpv, property.rawValue, value)
    }

    /// 设置整数属性
    func setProperty(_ property: MPVProperty, _ value: Int64) {
        guard let mpv = mpv else { return }
        var data = value
        mpv_set_property(mpv, property.rawValue, MPV_FORMAT_INT64, &data)
    }

    /// 设置浮点数属性
    func setProperty(_ property: MPVProperty, _ value: Double) {
        guard let mpv = mpv else { return }
        var data = value
        mpv_set_property(mpv, property.rawValue, MPV_FORMAT_DOUBLE, &data)
    }

    /// 设置布尔属性
    func setProperty(_ property: MPVProperty, _ value: Bool) {
        guard let mpv = mpv else { return }
        var data: Int = value ? 1 : 0
        mpv_set_property(mpv, property.rawValue, MPV_FORMAT_FLAG, &data)
    }
    
    func setProperty(_ property: MPVProperty, _ value: String) {
        guard let mpv = mpv else { return }
        value.withCString { cString in
            var mutableCString: UnsafePointer<Int8>? = cString
            mpv_set_property(mpv, property.rawValue, MPV_FORMAT_STRING, &mutableCString)
        }
    }

    // MARK: - 属性获取

    /// 获取整数属性
    func getPropertyInt64(_ property: MPVProperty) -> Int64? {
        guard let mpv = mpv else { return nil }
        var data = Int64()
        let ret = mpv_get_property(mpv, property.rawValue, MPV_FORMAT_INT64, &data)
        return ret >= 0 ? data : nil
    }

    /// 获取浮点数属性
    func getPropertyDouble(_ property: MPVProperty) -> Double? {
        guard let mpv = mpv else { return nil }
        var data = Double()
        let ret = mpv_get_property(mpv, property.rawValue, MPV_FORMAT_DOUBLE, &data)
        return ret >= 0 ? data : nil
    }

    /// 获取布尔属性
    func getPropertyFlag(_ property: MPVProperty) -> Bool? {
        guard let mpv = mpv else { return nil }
        var data = Int64()
        let ret = mpv_get_property(mpv, property.rawValue, MPV_FORMAT_FLAG, &data)
        return ret >= 0 ? data > 0 : nil
    }

    /// 获取字符串属性
    func getPropertyString(_ property: MPVProperty) -> String? {
        guard let mpv = mpv else { return nil }
        let cstr = mpv_get_property_string(mpv, property.rawValue)
        defer { mpv_free(cstr) }
        return cstr == nil ? nil : String(cString: cstr!)
    }

    // MARK: - 初始化

    /// 初始化 mpv 实例
    @discardableResult public func initialize() -> Int32 {
        guard let mpv = mpv else { return -1 }
        return mpv_initialize(mpv)
    }

    // MARK: - 属性观察

    /// 观察属性变化
    /// - Parameter property: 要观察的属性
    /// - Parameter handler: 属性变化时的回调，参数为属性值
    public func observe(_ property: MPVProperty, handler: @escaping (MPVPropertyValue) -> Void) {
        let name = property.rawValue
        observedProperties.insert(name)

        // 注册特定属性的处理函数
        if propertyChangeHandlers[name] == nil {
            propertyChangeHandlers[name] = []
        }
        propertyChangeHandlers[name]?.append(handler)

        // 注册到 mpv
        guard let mpv = mpv else { return }
        mpv_observe_property(mpv, 0, name, MPV_FORMAT_NONE)

        // 启动事件循环
        startEventLoopIfNeeded()
    }

    // MARK: - 事件处理

    /// 注册通用事件处理器
    /// - Parameters:
    ///   - type: 事件类型
    ///   - handler: 事件回调
    public func on(_ type: MPVEventType, handler: @escaping (MPVEvent) -> Void) {
        let wrapper: (MPVEvent) -> Void
        switch type {
        case .propertyChange(let name) where !name.isEmpty:
            // 特定属性名的处理
            wrapper = { event in
                if case .property(let propName, let value) = event.data, propName == name {
                    handler(event)
                }
            }
        default:
            wrapper = handler
        }

        eventHandlers.append(EventHandler(type: type, handler: wrapper))
        startEventLoopIfNeeded()
    }

    /// 停止事件循环
    public func stopEventLoop() {
        loopState = .idle
    }

    // MARK: - 私有方法

    /// 启动事件循环（如果尚未运行）
    private func startEventLoopIfNeeded() {
        eventQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.loopState == .idle else { return }

            self.loopState = .running

            while self.loopState == .running {
                // 检查 mpv 是否已销毁
                guard let mpv = self.mpv else { break }

                guard let eventPointer = mpv_wait_event(mpv, 0.1) else { continue }
                let event = MPVEvent(from: eventPointer)

                // shutdown 事件时停止循环
                if event.id == .shutdown {
                    self.loopState = .idle
                }

                self.dispatchEvent(event)
            }
        }
    }

    /// 分发事件到处理器
    private func dispatchEvent(_ event: MPVEvent) {
        // 1. 如果是属性变化事件，调用对应的 property handler
        if case .property(let name, let value) = event.data {
            if let handlers = propertyChangeHandlers[name] {
                for handler in handlers {
                    handler(value)
                }
            }
        }

        // 2. 分发到通用事件处理器
        for eh in eventHandlers {
            if eh.type.matches(event) {
                eh.handler(event)
            }
        }
    }

    // MARK: - 文件操作

    /// 加载文件
    public func loadFile(_ path: String, replace: Bool = true) {
        let action = replace ? "replace" : "append"
        execute(.loadFile, args: [path, action])
    }

    /// 停止播放
    public func stop() {
        execute(.stop)
    }

    // MARK: - 终止

    /// 异步退出 mpv 
    public func quit() {
        execute(.quit)
    }
}

// MARK: - Playback API

public class PlaybackAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 暂停/恢复播放
    public var isPaused: Bool {
        get { player?.getPropertyFlag(.pause) ?? false }
        set { player?.setProperty(.pause, newValue) }
    }

    /// 切换暂停状态
    public func togglePause() {
        player?.execute(.cycle, args: ["pause"])
    }

    /// 设置播放速度
    public func setSpeed(_ speed: Double) {
        player?.setProperty(.speed, speed)
    }
}

// MARK: - Time API

public class TimeAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 当前播放位置（秒）
    public var position: Double? {
        player?.getPropertyDouble(.timePos)
    }

    /// 媒体总时长（秒）
    public var duration: Double? {
        player?.getPropertyDouble(.duration)
    }

    /// 剩余播放时间（秒）
    public var remaining: Double? {
        player?.getPropertyDouble(.remaining)
    }

    /// 跳转到指定时间
    public func seek(to seconds: Double, absolute: Bool = true) {
        let type = absolute ? "absolute" : "relative"
        player?.execute(.seek, args: [String(seconds), type])
    }
}

// MARK: - Audio API

public class AudioAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 当前音频轨道 ID
    public var audioId: Int64? {
        get { player?.getPropertyInt64(.audioId) }
        set {
            if let id = newValue {
                player?.setProperty(.audioId, id)
            }
        }
    }

    /// 音量 (0-100)
    public var volume: Int64? {
        get { player?.getPropertyInt64(.volume) }
        set {
            if let vol = newValue {
                player?.setProperty(.volume, vol)
            }
        }
    }

    /// 静音状态
    public var isMuted: Bool {
        get { player?.getPropertyFlag(.mute) ?? false }
        set { player?.setProperty(.mute, newValue) }
    }

    /// 音频设备名称
    public var audioDevice: String? {
        player?.getPropertyString(.audioDevice)
    }

    /// 音频延迟（秒）
    public var delay: Double? {
        get { player?.getPropertyDouble(.audioDelay) }
        set {
            if let d = newValue {
                player?.setProperty(.audioDelay, d)
            }
        }
    }

    /// 切换静音状态
    public func toggleMute() {
        player?.execute(.cycle, args: ["mute"])
    }

    /// 增加音量
    public func addVolume(_ delta: Int64) {
        player?.execute(.add, args: ["volume", String(delta)])
    }
}

// MARK: - Video API

public class VideoAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 当前视频轨道 ID
    public var videoId: Int64? {
        get { player?.getPropertyInt64(.videoId) }
        set {
            if let id = newValue {
                player?.setProperty(.videoId, id)
            }
        }
    }

    /// 宽高比 (nil = 自动, 0 = 自动, -1 = 禁用)
    public var aspectRatio: Double? {
        get { player?.getPropertyDouble(.videoAspect) }
        set {
            if let ratio = newValue {
                player?.setProperty(.videoAspect, ratio)
            }
        }
    }

    /// 禁用宽高比覆盖，恢复视频原始比例
    public func resetAspectRatio() {
        player?.setProperty(.videoAspect, -1.0)
    }

    /// 全屏状态
    public var isFullscreen: Bool {
        get { player?.getPropertyFlag(.fullscreen) ?? false }
        set { player?.setProperty(.fullscreen, newValue) }
    }

    /// 窗口 ID (用于嵌入)
    public var windowId: Int64? {
        get { player?.getPropertyInt64(.windowId) }
        set {
            if let id = newValue {
                player?.setProperty(.windowId, id)
            }
        }
    }

    /// 硬件解码模式
    public var hardwareDecoding: String? {
        get { player?.getPropertyString(.hwdec) }
        set { player?.setOptionString(.hwdec, newValue ?? "no") }
    }
}

// MARK: - Subtitle API

public class SubtitleAPI {
    
    public enum AutoLoadMode: String {
        case no
        case exact //精确匹配 - 默认值)
        case fuzzy //模糊匹配
        case all //全部加载
    }
    
    public enum AssOverride: String {
        case no // 完全不覆盖。严格遵循字幕脚本（ASS/SSA）定义的样式进行渲染。
        case yes //     基础覆盖（默认值）。应用所有的 --sub-ass-* 样式覆盖选项。这可能会导致某些精细特效显示异常。
        case scale //缩放覆盖。类似于 yes，但额外应用 --sub-scale 属性进行缩放。
        case force // 强制全面覆盖。强制应用所有以 --sub-* 开头的通用字幕属性（如 sub-color, sub-font 等），会极大地破坏特效字幕的原始布局。
        case strip //    彻底剥离样式。将 ASS/SSA 字幕的所有标签和样式信息移除，直接作为纯文本渲染。
    }
    
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 当前字幕轨道 ID
    public var subtitleId: Int64? {
        get { player?.getPropertyInt64(.subtitleId) }
        set {
            if let id = newValue {
                player?.setProperty(.subtitleId, id)
            }
        }
    }

    /// 副字幕轨道 ID
    public var secondarySubtitleId: Int64? {
        get { player?.getPropertyInt64(.secondarySubtitleId) }
        set {
            if let id = newValue {
                player?.setProperty(.secondarySubtitleId, id)
            }
        }
    }

    /// 字幕延迟（秒）
    public var delay: Double? {
        get { player?.getPropertyDouble(.subtitleDelay) }
        set {
            if let d = newValue {
                player?.setProperty(.subtitleDelay, d)
            }
        }
    }

    /// 字幕字体大小
    public var fontSize: Int64? {
        get { player?.getPropertyInt64(.subtitleFontSize) }
        set {
            if let size = newValue {
                player?.setOptionString(.subtitleFontSize, "\(size)")
            }
        }
    }
    
    public var assOverride: AssOverride? {
        get {
            if let value = player?.getPropertyString(.subtitleAssOverride) {
                return AssOverride(rawValue: value)
            }
            return nil
        }
        
        set {
            if let value = newValue {
                player?.setOptionString(.subtitleAssOverride, value.rawValue)
            }
        }
    }
    
    public var position: Int64 {
        get {
            player?.getPropertyInt64(.subtitlePos) ?? 0
        }
        
        set {
            player?.setProperty(.subtitlePos, newValue)
        }
    }
    
    public var marginY: Int64 {
        get {
            player?.getPropertyInt64(.subtitleMarginY) ?? 0
        }
        
        set {
            player?.setProperty(.subtitleMarginY, newValue)
        }
    }
    
    public var autoLoad: AutoLoadMode? {
        get {
            if let value = player?.getPropertyString(.subtitleAuto) {
                return AutoLoadMode(rawValue: value)
            }
            return nil
        }
        
        set {
            if let value = newValue {
                player?.setProperty(.subtitleAuto, value.rawValue)
            }
        }
    }
    
    

    #if os(iOS) || os(tvOS)
    /// 字幕颜色
    public var color: UIColor? {
        get {
            guard let hex = player?.getPropertyString(.subtitleColor) else { return nil }
            return UIColor(hex: hex)
        }
        set {
            if let color = newValue {
                player?.setOptionString(.subtitleColor, MPV.colorToHex(color))
            } else {
                player?.setOptionString(.subtitleColor, MPV.colorToHex(UIColor.white))
            }
        }
    }

    /// 字幕后景色
    public var backColor: UIColor? {
        get {
            guard let hex = player?.getPropertyString(.subtitleBackColor) else { return nil }
            return UIColor(hex: hex)
        }
        set {
            if let color = newValue {
                player?.setOptionString(.subtitleBackColor, MPV.colorToHex(color) + "80") // 50% alpha
            } else {
                player?.setOptionString(.subtitleBackColor, "")
            }
        }
    }
    #elseif os(macOS)
    /// 字幕颜色
    public var color: NSColor? {
        get {
            guard let hex = player?.getPropertyString(.subtitleColor) else { return nil }
            return NSColor(hex: hex)
        }
        set {
            if let color = newValue {
                player?.setOptionString(.subtitleColor, MPV.colorToHex(color))
            } else {
                player?.setOptionString(.subtitleColor, "")
            }
        }
    }

    /// 字幕后景色
    public var backColor: NSColor? {
        get {
            guard let hex = player?.getPropertyString(.subtitleBackColor) else { return nil }
            return NSColor(hex: hex)
        }
        set {
            if let color = newValue {
                player?.setOptionString(.subtitleBackColor, MPV.colorToHex(color) + "80")
            }  else {
                player?.setOptionString(.subtitleBackColor, "")
            }
        }
    }
    #endif

    /// 添加外部字幕文件
    public func addExternal(path: String, select: Bool = true) {
        let action = select ? "select" : "auto"
        player?.execute(.subAdd, args: [path, action])
    }

    /// 移除外部字幕
    public func removeExternal(path: String) {
        player?.execute(.subRemove, args: [path])
    }
}

// MARK: - Track API

/// 轨道类型
public enum TrackType {
    case audio
    case subtitle
    case video
}

/// 轨道信息基类
public class TrackInfo {
    public let id: Int64
    public let title: String?
    public let lang: String?
    public let type: TrackType

    public var displayName: String {
        title ?? lang ?? "\(type) \(id)"
    }

    init(id: Int64, title: String?, lang: String?, type: TrackType) {
        self.id = id
        self.title = title
        self.lang = lang
        self.type = type
    }
}

/// 音频轨道
public class AudioTrack: TrackInfo {
    public init(id: Int64, title: String?, lang: String?) {
        super.init(id: id, title: title, lang: lang, type: .audio)
    }
}

/// 字幕轨道
public class SubtitleTrack: TrackInfo {
    public init(id: Int64, title: String?, lang: String?) {
        super.init(id: id, title: title, lang: lang, type: .subtitle)
    }
}

/// 视频轨道
public class VideoTrack: TrackInfo {
    public init(id: Int64, title: String?, lang: String?) {
        super.init(id: id, title: title, lang: lang, type: .video)
    }
}

public class TrackAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 所有轨道
    public var allTracks: [TrackInfo] {
        var tracks: [TrackInfo] = []
        var index = 0
        while true {
            guard let typeStr = player?.getPropertyString(.trackType(index)), !typeStr.isEmpty else {
                break
            }

            let id = player?.getPropertyInt64(.trackId(index)) ?? 0
            let title = player?.getPropertyString(.trackTitle(index))
            let lang = player?.getPropertyString(.trackLang(index))

            switch typeStr {
            case "audio":
                tracks.append(AudioTrack(id: id, title: title, lang: lang))
            case "sub":
                tracks.append(SubtitleTrack(id: id, title: title, lang: lang))
            case "video":
                tracks.append(VideoTrack(id: id, title: title, lang: lang))
            default:
                break
            }

            index += 1
        }
        return tracks
    }

    /// 音频轨道
    public var audioTracks: [AudioTrack] {
        allTracks.compactMap { $0 as? AudioTrack }
    }

    /// 字幕轨道
    public var subtitleTracks: [SubtitleTrack] {
        allTracks.compactMap { $0 as? SubtitleTrack }
    }

    /// 视频轨道
    public var videoTracks: [VideoTrack] {
        allTracks.compactMap { $0 as? VideoTrack }
    }
}

// MARK: - Screenshot API

public class ScreenshotAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 截图（包含字幕）
    public func capture() {
        player?.execute(.screenshot)
    }

    /// 截图（不包含字幕）
    public func captureWithoutSubtitle() {
        player?.execute(.screenshot, args: ["video"])
    }

    /// 截图（包含窗口元素，如 OSD）
    public func captureWithOSD() {
        player?.execute(.screenshot, args: ["window"])
    }

    /// 保存截图到指定文件
    public func saveToFile(path: String, format: String = "png") {
        player?.execute(.screenshotToFile, args: [path, format])
    }
}

// MARK: - 颜色扩展

#if os(iOS) || os(tvOS)
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#elseif os(macOS)
extension NSColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif

#endif
