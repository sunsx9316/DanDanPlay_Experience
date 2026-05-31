---
name: add-to-project
description: 将文件加入 Xcode 工程，group 与物理目录一致，reference 方式引入
---

# Xcode 工程文件管理

## 规则

- 新增文件**必须**加入 Xcode 工程才能编译/打包
- **必须**使用 reference 方式（不复制文件）
- **必须**让 group 结构与物理目录结构一致
- **禁止**手动编辑 `project.pbxproj`

## 工具脚本

使用 `scripts/add_to_project.rb` 操作。

### 添加文件

```bash
ruby scripts/add_to_project.rb <platform> <file_path>
```

`platform`: `ios` | `tvos` | `mac`
`file_path`: 项目根目录的相对路径 或 绝对路径

### 示例

```bash
# 加 Swift 文件 → 自动加入 Sources
ruby scripts/add_to_project.rb ios iOS/AniXPlayer/Files/Test.swift

# 加 xcstrings → 自动加入 Resources
ruby scripts/add_to_project.rb tvos tvOS/AniXPlayer/Localizable.xcstrings

# 指定 group 路径
ruby scripts/add_to_project.rb ios --group "AniXPlayer/Resource" iOS/.../file.plist
```

### 其他命令

```bash
ruby scripts/add_to_project.rb ios --list-targets
ruby scripts/add_to_project.rb ios --dry-run path/to/file
```

## 自动推断规则

| 扩展名 | Build Phase |
|--------|-------------|
| `.swift` / `.m` / `.mm` / `.c` / `.h` | Sources |
| `.xcstrings` / `.plist` / `.xcassets` / `.json` | Resources |
| 其他 | 仅加入 group，不加入 build phase |

## 行为

- 自动按文件所在目录层级创建 group
- 已存在则跳过（不重复添加）
- 文件不存在则报错
