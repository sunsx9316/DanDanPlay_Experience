---
name: add-to-project
description: 将文件/目录加入或移出 Xcode 工程，group 与物理目录一致，reference 方式引入
---

# Xcode 工程文件管理

## 规则

- 新增/删除文件**必须**同步更新 Xcode 工程才能编译/打包
- **必须**使用 reference 方式（不复制文件）
- **必须**让 group 结构与物理目录结构一致
- **禁止**手动编辑 `project.pbxproj`

## 工具脚本

使用 `scripts/xcode_project.rb` 操作。

### 添加单个文件

```bash
ruby scripts/xcode_project.rb <platform> add <file_path>
# 或省略 add（兼容旧用法）
ruby scripts/xcode_project.rb <platform> <file_path>
```

### 删除文件

```bash
ruby scripts/xcode_project.rb <platform> remove <file_path>
```

### 递归同步目录

```bash
ruby scripts/xcode_project.rb <platform> --sync <directory>
# 或简写（传入目录路径自动识别）
ruby scripts/xcode_project.rb <platform> <directory>
```

`platform`: `ios` | `tvos` | `mac`
`file_path` / `directory`: 项目根目录的相对路径 或 绝对路径

### 示例

```bash
# 加 Swift 文件 → 自动加入 Sources
ruby scripts/xcode_project.rb ios add iOS/AniXPlayer/Files/Test.swift

# 删除文件
ruby scripts/xcode_project.rb mac remove Mac/AniXPlayer/Base/ViewController/NavigationProtocol.swift

# 递归同步整个目录（子目录自动创建匹配的 group）
ruby scripts/xcode_project.rb tvos --sync tvOS/AniXPlayer/FileBrowser

# 加 xcstrings → 自动加入 Resources
ruby scripts/xcode_project.rb tvos add tvOS/AniXPlayer/Localizable.xcstrings

# 预览
ruby scripts/xcode_project.rb ios --dry-run iOS/AniXPlayer/NewDir/
```

## 自动推断规则

| 扩展名 | Build Phase |
|--------|-------------|
| `.swift` / `.m` / `.mm` / `.c` / `.h` | Sources |
| `.xcstrings` / `.plist` / `.xcassets` / `.json` | Resources |
| 其他 | 仅加入 group，不加入 build phase |

## 行为

- `add`: 子目录自动创建匹配的 group，与物理目录层级一致；已存在则跳过
- `remove`: 从 build phase 和 group 中移除文件引用
- `--sync`: 递归遍历所有文件，忽略 `.DS_Store`、`.git`、`Pods` 等
- `--dry-run` 预览不修改
