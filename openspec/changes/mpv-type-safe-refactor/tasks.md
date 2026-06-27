## 1. 文件拆分

- [x] 1.1 从 `MPV.swift` 提取 `MPVProperty+Values.swift`：所有 `static let` 属性定义
- [x] 1.2 从 `MPV.swift` 提取 `MPV+APIs.swift`：API 外观类 + Track 类型
- [x] 1.3 从 `MPV.swift` 提取 `MPVColor+Hex.swift`：颜色 hex 转换扩展
- [x] 1.4 保留 `MPV.swift` 核心类 + 嵌套类型 + 核心方法（584 行，从 1133 缩减）

## 2. 目录重组

- [x] 2.1 创建 `MPV/Core/` 子目录
- [x] 2.2 将 4 个 core 文件移入 `MPV/Core/`
- [x] 2.3 更新 iOS pbxproj：创建 Core PBXGroup，移入 4 个 file reference
- [x] 2.4 更新 tvOS pbxproj：同上
- [x] 2.5 更新 Mac pbxproj：同上
- [x] 2.6 修复 `remove_from_project` 导致的 build phase 丢失（4 个文件重加入 MPVFramework target）

## 3. 编译验证

- [x] 3.1 iOS clean build 通过
- [x] 3.2 tvOS MPVFramework target 编译通过（AniXPlayer target 因 provisioning profile 失败，非代码问题）
- [ ] 3.3 Mac 编译验证（待有 Mac 构建环境时验证）
