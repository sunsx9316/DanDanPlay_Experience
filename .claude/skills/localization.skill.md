---
name: localization
description: 管理 iOS / tvOS / Mac Localizable.xcstrings 多语言字符串
---

# 多语言字符串管理

## 规则

每次在代码中使用 `NSLocalizedString` 或 `LocalizedString()` 引入新 key 时，**必须**同步更新 `Localizable.xcstrings`。

## 工具脚本

使用 `scripts/add_localization.py` 操作，**禁止**直接 Read 或 Edit `.xcstrings` 文件（会浪费上下文）。

### 语法

```bash
python3 scripts/add_localization.py <platform> <command> [args...]
```

`platform`: `ios` | `tvos` | `mac` | `all`（`all` = 对所有已有文件的平台操作）

### 检查 key 是否存在

```bash
python3 scripts/add_localization.py ios --check "备注"
```

- 输出 `EXISTS: 备注` → 已存在，无需添加
- 输出 `NOT_FOUND: 备注` → 需要添加
- 输出 `NO_FILE: ...` → 该平台尚无 xcstrings 文件

### 添加新 key

```bash
python3 scripts/add_localization.py ios --add "备注" "Remark"
```

- 参数1: 中文原文（同时作为 key 和 zh-Hans 的值）
- 参数2: 英文翻译
- 如果 key 已存在，不会重复添加
- 如果 xcstrings 文件/目录不存在，会自动创建

### 列出所有 key

```bash
python3 scripts/add_localization.py ios --list
```

## 文件路径

| 平台 | 路径 |
|------|------|
| iOS | `iOS/AniXPlayer/Resource/Localizable.xcstrings` |
| tvOS | `tvOS/AniXPlayer/Resource/Localizable.xcstrings` |
| Mac | `Mac/AniXPlayer/Resource/Localizable.xcstrings` |

## 格式说明

JSON 结构：
```json
{
  "sourceLanguage": "en",
  "strings": {
    "中文原文": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "English"
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

1. 代码中写了 `NSLocalizedString("新字符串", comment: "")`
2. 运行 `python3 scripts/add_localization.py <platform> --check "新字符串"`
3. 若 `NOT_FOUND`，运行 `python3 scripts/add_localization.py <platform> --add "新字符串" "English Translation"`
4. 若 `EXISTS`，跳过
