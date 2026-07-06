# AniXPlayer

AniXPlayer 是一款跨平台视频播放器，支持 iOS、tvOS 和 macOS。

> 你问我为啥叫这个名？当然是群友选的。

## 功能

- MKV、MP4、AVI 等常见格式播放，VLCKit / MPV 双内核可切换
- 接入 [弹弹Play](https://doc.dandanplay.com/open/) 弹幕库，在线自动匹配，同时支持本地弹幕文件
- 浏览 Emby、Jellyfin 媒体服务器内容
- SMB、WebDAV、FTP、PC 文件共享
- 内挂/外挂字幕切换，多音轨选择

## 平台支持


| 平台    | 最低版本 | 播放内核         |
| ----- | ---- | ------------ |
| iOS   | 12.0 | VLCKit / MPV |
| tvOS  | 17.6 | VLCKit / MPV |
| macOS | 12.0 | VLCKit / MPV |


## 快速开始

**环境：** Xcode 16.0+、CocoaPods 1.15+

以下以 iOS 为例。

### 1. 安装依赖

```bash
cd iOS && pod install
```

### 2. 配置 AppKey

在 `iOS/AniXPlayer/` 目录下创建 `AppKey.swift`（[申请地址](https://doc.dandanplay.com/open/)）：

```swift
struct AppKey {
    static var appId = "你的 AppId"
    static var appSec = "你的 AppSec"
}
```

### 3. 打开工程

```bash
open iOS/AniXPlayer.xcworkspace    # 注意是 .xcworkspace，不是 .xcodeproj
```



## License

[MIT](LICENSE)