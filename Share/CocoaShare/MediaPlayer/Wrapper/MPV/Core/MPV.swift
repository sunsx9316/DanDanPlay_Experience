//
//  MPV.swift
//  CocoaShare
//
//  libmpv C API 的 Swift 风格封装
//  将 mpv_* C 函数封装为面向对象的 Swift 接口
//  参考 mpv 官方文档 (https://mpv.io/manual/stable/) 进行模块化设计
//
// ⚠️ 此文件必须包含在 target membership 中（iOS + tvOS 都要勾选），漏勾会报 "Cannot find 'MPV' in scope"

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

#if os(iOS) || os(tvOS)
public typealias MPVColor = UIColor
#elseif os(macOS)
public typealias MPVColor = NSColor
#endif

// MARK: - MPV 媒体

public class MPVMedia {
    public private(set) var url: URL
    public var options: [String: String]?

    public init(url: URL, options: [String: String]? = nil) {
        self.url = url
        self.options = options
    }
}

// MARK: - MPV 主类

public class MPV {

    // MARK: - 嵌套类型

    /// 事件 ID
    public enum EventID: Int {
        case none = 0
        case shutdown = 1
        case logMessage = 2
        case getPropertyReply = 3
        case setPropertyReply = 4
        case commandReply = 5
        case startFile = 6
        case endFile = 7
        case fileLoaded = 8
        case idle = 11
        case tick = 14
        case clientMessage = 16
        case videoReconfig = 17
        case audioReconfig = 18
        case seek = 20
        case playbackRestart = 21
        case propertyChange = 22
        case queueOverflow = 24
        case hook = 25

        init(from rawValue: mpv_event_id) {
            self = EventID(rawValue: Int(rawValue.rawValue)) ?? .none
        }
    }

    /// 事件类型，用于注册处理器
    public enum EventType {
        case propertyChange(name: String)
        case fileLoaded, startFile, endFile, playbackRestart, seek
        case videoReconfig, audioReconfig
        case shutdown, logMessage, clientMessage, idle
        case any

        func matches(_ event: Event) -> Bool {
            switch self {
            case .any: return true
            case .propertyChange(let name):
                if case .property(let propName, _) = event.data { return propName == name }
                return event.id == .propertyChange && name.isEmpty
            case .fileLoaded: return event.id == .fileLoaded
            case .startFile: return event.id == .startFile
            case .endFile: return event.id == .endFile
            case .playbackRestart: return event.id == .playbackRestart
            case .seek: return event.id == .seek
            case .videoReconfig: return event.id == .videoReconfig
            case .audioReconfig: return event.id == .audioReconfig
            case .shutdown: return event.id == .shutdown
            case .logMessage: return event.id == .logMessage
            case .clientMessage: return event.id == .clientMessage
            case .idle: return event.id == .idle
            }
        }
    }

    /// 节点值（用于复杂数据结构）
    public enum NodeValue {
        case string(String)
        case flag(Bool)
        case int64(Int64)
        case double(Double)
        case array([NodeValue])
        case map([String: NodeValue])
        case byteArray(Data)

        init(from node: mpv_node) {
            switch node.format {
            case MPV_FORMAT_STRING: self = .string(String(cString: node.u.string))
            case MPV_FORMAT_FLAG: self = .flag(node.u.flag != 0)
            case MPV_FORMAT_INT64: self = .int64(node.u.int64)
            case MPV_FORMAT_DOUBLE: self = .double(node.u.double_)
            case MPV_FORMAT_NODE_ARRAY: self = .array(Self.parseArray(node.u.list))
            case MPV_FORMAT_NODE_MAP: self = .map(Self.parseMap(node.u.list))
            case MPV_FORMAT_BYTE_ARRAY:
                if let ba = node.u.ba { self = .byteArray(Data(bytes: ba.pointee.data, count: ba.pointee.size)) }
                else { self = .byteArray(Data()) }
            default: self = .string("")
            }
        }

        private static func parseArray(_ list: UnsafeMutablePointer<mpv_node_list>?) -> [NodeValue] {
            guard let list = list else { return [] }
            var result: [NodeValue] = []
            let count = Int(list.pointee.num)
            for i in 0..<count { result.append(NodeValue(from: list.pointee.values[i])) }
            return result
        }

        private static func parseMap(_ list: UnsafeMutablePointer<mpv_node_list>?) -> [String: NodeValue] {
            guard let list = list else { return [:] }
            var result: [String: NodeValue] = [:]
            let count = Int(list.pointee.num)
            for i in 0..<count {
                guard let keyPtr = list.pointee.keys[i] else { continue }
                let key = String(cString: keyPtr)
                result[key] = NodeValue(from: list.pointee.values[i])
            }
            return result
        }
    }

    /// 节点包装器
    public struct Node {
        public let value: NodeValue
        public init(from node: mpv_node) { self.value = NodeValue(from: node) }

        public var stringValue: String? { if case .string(let s) = value { return s }; return nil }
        public var flagValue: Bool? { if case .flag(let f) = value { return f }; return nil }
        public var int64Value: Int64? { if case .int64(let i) = value { return i }; return nil }
        public var doubleValue: Double? { if case .double(let d) = value { return d }; return nil }
        public var arrayValue: [NodeValue]? { if case .array(let a) = value { return a }; return nil }
        public var mapValue: [String: NodeValue]? { if case .map(let m) = value { return m }; return nil }
        public var byteArrayValue: Data? { if case .byteArray(let b) = value { return b }; return nil }
    }

    /// 属性值类型
    public enum Value {
        case string(String)
        case osdString(String)
        case flag(Bool)
        case int64(Int64)
        case double(Double)
        case node(Node)
        case none

        init(from format: mpv_format, data: UnsafeRawPointer?) {
            guard let data = data else { self = .none; return }
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
                self = .int64(data.assumingMemoryBound(to: Int64.self).pointee)
            case MPV_FORMAT_DOUBLE:
                self = .double(data.assumingMemoryBound(to: Double.self).pointee)
            case MPV_FORMAT_NODE:
                let node = data.assumingMemoryBound(to: mpv_node.self).pointee
                self = .node(Node(from: node))
            default: self = .none
            }
        }
    }

    /// 事件数据
    public enum EventData {
        case property(name: String, value: Value)
        case logMessage(prefix: String, level: String, text: String)
        case clientMessage(args: [String])
        case startFile(playlistEntryId: Int64)
        case endFile(reason: EndFileReason, error: Int, playlistEntryId: Int64, playlistInsertId: Int64, playlistInsertNumEntries: Int)
        case hook(name: String, id: UInt64)
        case commandReply(result: mpv_node)
        case none
    }

    /// 文件结束原因
    public enum EndFileReason: UInt32 {
        case eof = 0
        case stop = 2
        case quit = 3
        case error = 4
        case redirect = 5

        init(from reason: Int32) {
            self = EndFileReason(rawValue: UInt32(bitPattern: reason)) ?? .eof
        }
    }

    /// 事件包装器
    public struct Event {
        public let id: EventID
        public let error: Int
        public let replyUserdata: UInt64
        public let data: EventData

        init(from event: UnsafeMutablePointer<mpv_event>) {
            self.id = EventID(from: event.pointee.event_id)
            self.error = Int(event.pointee.error)
            self.replyUserdata = event.pointee.reply_userdata

            guard let eventData = event.pointee.data else { self.data = .none; return }

            switch self.id {
            case .getPropertyReply, .propertyChange:
                let property = eventData.assumingMemoryBound(to: mpv_event_property.self).pointee
                let name = String(cString: property.name)
                let value = Value(from: property.format, data: property.data)
                self.data = .property(name: name, value: value)
            case .logMessage:
                let logMsg = eventData.assumingMemoryBound(to: mpv_event_log_message.self).pointee
                self.data = .logMessage(prefix: String(cString: logMsg.prefix), level: String(cString: logMsg.level), text: String(cString: logMsg.text))
            case .clientMessage:
                let clientMsg = eventData.assumingMemoryBound(to: mpv_event_client_message.self).pointee
                var args: [String] = []
                for i in 0..<Int(clientMsg.num_args) {
                    if let arg = clientMsg.args?[i] { args.append(String(cString: arg)) }
                }
                self.data = .clientMessage(args: args)
            case .startFile:
                let startFile = eventData.assumingMemoryBound(to: mpv_event_start_file.self).pointee
                self.data = .startFile(playlistEntryId: startFile.playlist_entry_id)
            case .endFile:
                let endFile = eventData.assumingMemoryBound(to: mpv_event_end_file.self).pointee
                let reason = EndFileReason(rawValue: endFile.reason.rawValue) ?? .eof
                self.data = .endFile(reason: reason, error: Int(endFile.error), playlistEntryId: endFile.playlist_entry_id, playlistInsertId: endFile.playlist_insert_id, playlistInsertNumEntries: Int(endFile.playlist_insert_num_entries))
            case .hook:
                let hook = eventData.assumingMemoryBound(to: mpv_event_hook.self).pointee
                self.data = .hook(name: String(cString: hook.name), id: hook.id)
            case .commandReply:
                let commandReply = eventData.assumingMemoryBound(to: mpv_event_command.self).pointee
                self.data = .commandReply(result: commandReply.result)
            default: self.data = .none
            }
        }
    }

    /// 标记类型：仅用于 observe，不可直接 get/set
    public enum ObservableOnly {}

    /// 属性名称（类型安全）
    public struct Property<ValueType> {
        public let rawValue: String
        public init(_ rawValue: String) { self.rawValue = rawValue }
    }

    /// 命令
    public enum Command {
        case loadFile, stop, seek, revertSeek
        case trackSelect, subAdd, subRemove, audioAdd, audioRemove
        case subSeek
        case set, add, multiply, cycle, cycleValues
        case screenshot, screenshotToFile
        case showText, overlayAdd, overlayRemove
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

    // MARK: - 私有属性

    public private(set) var mpv: OpaquePointer?
    private let eventQueue: DispatchQueue = DispatchQueue(label: "com.cocoashare.mpv.event")
    private var eventHandlers: [EventHandler] = []
    private var observedProperties: Set<String> = []
    private var propertyChangeHandlers: [String: [(Value) -> Void]] = [:]

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
        let type: EventType
        let handler: (Event) -> Void
    }

    // MARK: - 类型安全的 API (lazy 存储)

    public lazy var playback = PlaybackAPI(mpv: self)
    public lazy var time = TimeAPI(mpv: self)
    public lazy var audio = AudioAPI(mpv: self)
    public lazy var video = VideoAPI(mpv: self)
    public lazy var subtitle = SubtitleAPI(mpv: self)
    public lazy var track = TrackAPI(mpv: self)

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

    /// 设置整数属性
    func setProperty(_ property: Property<Int64>, _ value: Int64) {
        guard let mpv = mpv else { return }
        var data = value
        mpv_set_property(mpv, property.rawValue, MPV_FORMAT_INT64, &data)
    }

    /// 设置浮点数属性
    func setProperty(_ property: Property<Double>, _ value: Double) {
        guard let mpv = mpv else { return }
        var data = value
        mpv_set_property(mpv, property.rawValue, MPV_FORMAT_DOUBLE, &data)
    }

    /// 设置布尔属性
    func setProperty(_ property: Property<Bool>, _ value: Bool) {
        guard let mpv = mpv else { return }
        var data: Int = value ? 1 : 0
        mpv_set_property(mpv, property.rawValue, MPV_FORMAT_FLAG, &data)
    }

    public func setProperty(_ property: Property<String>, _ value: String) {
        guard let mpv = mpv else { return }
        value.withCString { cString in
            var mutableCString: UnsafePointer<Int8>? = cString
            mpv_set_property(mpv, property.rawValue, MPV_FORMAT_STRING, &mutableCString)
        }
    }

    // MARK: - 属性获取

    /// 获取整数属性
    public func getProperty(_ property: Property<Int64>) -> Int64? {
        guard let mpv = mpv else { return nil }
        var data = Int64()
        let ret = mpv_get_property(mpv, property.rawValue, MPV_FORMAT_INT64, &data)
        return ret >= 0 ? data : nil
    }

    /// 获取浮点数属性
    public func getProperty(_ property: Property<Double>) -> Double? {
        guard let mpv = mpv else { return nil }
        var data = Double()
        let ret = mpv_get_property(mpv, property.rawValue, MPV_FORMAT_DOUBLE, &data)
        return ret >= 0 ? data : nil
    }

    /// 获取布尔属性
    public func getProperty(_ property: Property<Bool>) -> Bool? {
        guard let mpv = mpv else { return nil }
        var data = Int64()
        let ret = mpv_get_property(mpv, property.rawValue, MPV_FORMAT_FLAG, &data)
        return ret >= 0 ? data > 0 : nil
    }

    /// 获取字符串属性
    public func getProperty(_ property: Property<String>) -> String? {
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
    public func observe<T>(_ property: Property<T>, handler: @escaping (Value) -> Void) {
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
    public func on(_ type: EventType, handler: @escaping (Event) -> Void) {
        let wrapper: (Event) -> Void
        switch type {
        case .propertyChange(let name) where !name.isEmpty:
            // 特定属性名的处理
            wrapper = { event in
                if case .property(let propName, _) = event.data, propName == name {
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
                let event = Event(from: eventPointer)

                // shutdown 事件时停止循环
                if event.id == .shutdown {
                    self.loopState = .idle
                }

                self.dispatchEvent(event)
            }
        }
    }

    /// 分发事件到处理器
    private func dispatchEvent(_ event: Event) {
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

    // MARK: - 命令执行

    /// 执行 mpv 命令
    public func execute(_ command: Command, args: [String] = []) {
        let newArgs = [command.rawValue] + args
        var cargs = newArgs.map { UnsafePointer<CChar>(strdup($0)) }
        cargs.append(nil)

        cargs.withUnsafeMutableBufferPointer { [weak self] buffer in
            guard let self = self else { return }
            mpv_command(self.mpv, buffer.baseAddress)
        }

        for ptr in cargs {
            if let p = ptr { free(UnsafeMutablePointer(mutating: p)) }
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

    // MARK: - 截图（供 PiP 捕获帧）

    /// 视频宽度
    /// 视频尺寸
    public var videoSize: CGSize {
        guard let handle = mpv else { return .zero }
        var w = Int64(0), h = Int64(0)
        guard mpv_get_property(handle, "video-params/w", MPV_FORMAT_INT64, &w) >= 0,
              mpv_get_property(handle, "video-params/h", MPV_FORMAT_INT64, &h) >= 0,
              w > 0, h > 0 else { return .zero }
        return CGSize(width: Int(w), height: Int(h))
    }
}
