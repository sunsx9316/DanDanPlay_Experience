---
name: localization
description: 补全 iOS / tvOS / Mac Localizable.xcstrings 中缺失的翻译
---

# 多语言翻译补全

## 重要：Xcode 自动管理 key

Xcode 在每次 build **自动扫描代码**中的 `NSLocalizedString` / `LocalizedString()` 调用，自动向 `Localizable.xcstrings` 添加或删除 key。

**不要手动添加或删除 key**，Xcode 会处理。本工具只负责补全**已有 key 的缺失翻译**。

## 翻译规则

- `zh-Hans`：使用 key 自身（key 是中文原文）
- `en`：提供准确的英文翻译

## 工具脚本

使用 `scripts/add_localization.py` 操作，**禁止**直接 Read 或 Edit `.xcstrings` 文件（会浪费上下文）。

### 语法

```bash
python3 scripts/add_localization.py <platform> <command> [args...]
```

`platform`: `ios` | `tvos` | `mac` | `all`

### 批量补全缺翻译

扫描代码中的 key，将 xcstrings 文件里已有但缺翻译的条目自动填充：

```bash
python3 scripts/add_localization.py ios --sync
```

- 已存在的 key 且有翻译 → 跳过
- 已存在的 key 但缺翻译 → 用 key 填充，zh-Hans=key，en=key（占位待翻）
- 代码里有但 xcstrings 里没有 → 新增并用 key 填充

### 手动添加翻译

```bash
python3 scripts/add_localization.py ios --add "备注" "Remark"
```

- 参数1: key（也作为 zh-Hans）
- 参数2: 英文翻译

### 检查 key

```bash
python3 scripts/add_localization.py ios --check "备注"
```

### 列出所有 key

```bash
python3 scripts/add_localization.py ios --list
```

## 文件路径

| 平台 | 路径 |
|------|------|
| iOS | `iOS/AniXPlayer/Resource/Localizable.xcstrings` |
| tvOS | `tvOS/AniXPlayer/Resource/Localizable.xcstrings` |
| Mac | `Mac/AniXPlayer/Localizable.xcstrings` |

## 格式说明

```json
{
  "sourceLanguage": "en",
  "strings": {
    "中文原文": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "English Translation"
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "中文原文"
          }
        }
      }
    }
  },
  "version": "1.1"
}
```

## 工作流

1. 代码中写 `NSLocalizedString("新字符串", comment: "")`
2. 下次 build 时 Xcode 自动将 key 加入 xcstrings
3. 运行 `--sync` 补全缺翻译，或用 `--add` 手动添加翻译
