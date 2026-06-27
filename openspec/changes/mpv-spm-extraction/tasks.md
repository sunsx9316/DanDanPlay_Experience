## 1. 创建 SPM 包

- [ ] 1.1 创建 `Share/MPVFramework/Package.swift` — 动态库，依赖 MPVKit，平台 iOS 14 / macOS 12 / tvOS 17
- [ ] 1.2 创建 `Share/MPVFramework/Sources/` 目录
- [ ] 1.3 复制 Core 4 文件到 `Sources/`：MPV.swift、MPV+APIs.swift、MPVProperty+Values.swift、MPVColor+Hex.swift
- [ ] 1.4 移除文件头部的 target membership 注释

## 2. 集成到 Xcode 工程

- [ ] 2.1 iOS pbxproj：AniXPlayer target 添加 SPM 依赖 `MPVFramework`（本地 path）
- [ ] 2.2 iOS pbxproj：集成层 4 文件从 MPVFramework target 移到 AniXPlayer target
- [ ] 2.3 iOS pbxproj：删除 MPVFramework target 及其 build phase 引用
- [ ] 2.4 iOS pbxproj：删除 Core 4 文件的 pbxproj 引用（改用 SPM）
- [ ] 2.5 tvOS pbxproj：重复 2.1-2.4
- [ ] 2.6 Mac pbxproj：重复 2.1-2.4

## 3. 编译验证

- [ ] 3.1 iOS 真机 clean build 通过
- [ ] 3.2 tvOS 真机 clean build 通过
- [ ] 3.3 Mac 编译通过
