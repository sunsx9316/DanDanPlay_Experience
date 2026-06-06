#!/usr/bin/env python3
"""
多语言字符串管理 — 支持 iOS / tvOS / Mac，不加载文件到上下文。
新增文件时自动加入 Xcode 工程。

用法:
  python3 scripts/add_localization.py <platform> --check "备注"
  python3 scripts/add_localization.py <platform> --add "备注" "Remark"
  python3 scripts/add_localization.py <platform> --list
  python3 scripts/add_localization.py <platform> --sync          # 扫描代码批量同步

platform: ios | tvos | mac | all
  all = 对所有已有文件的平台操作

文件路径:
  iOS:  iOS/AniXPlayer/Resource/Localizable.xcstrings
  tvOS: tvOS/AniXPlayer/Resource/Localizable.xcstrings
  Mac:  Mac/AniXPlayer/Resource/Localizable.xcstrings
"""

import json
import sys
import os
import re
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

PLATFORM_CONFIG = {
    "ios": {
        "xcstrings": os.path.join(PROJECT_ROOT, "iOS", "AniXPlayer", "Resource", "Localizable.xcstrings"),
        "project": os.path.join(PROJECT_ROOT, "iOS", "AniXPlayer.xcodeproj"),
        "code_dir": os.path.join(PROJECT_ROOT, "iOS"),
    },
    "tvos": {
        "xcstrings": os.path.join(PROJECT_ROOT, "tvOS", "AniXPlayer", "Resource", "Localizable.xcstrings"),
        "project": os.path.join(PROJECT_ROOT, "tvOS", "AniXPlayer.xcodeproj"),
        "code_dir": os.path.join(PROJECT_ROOT, "tvOS"),
    },
    "mac": {
        "xcstrings": os.path.join(PROJECT_ROOT, "Mac", "AniXPlayer", "Localizable.xcstrings"),
        "project": os.path.join(PROJECT_ROOT, "Mac", "AniXPlayer.xcodeproj"),
        "code_dir": os.path.join(PROJECT_ROOT, "Mac"),
    },
}

TEMPLATE = {
    "sourceLanguage": "en",
    "strings": {},
    "version": "1.1"
}


def _ensure_file(path):
    """目录或文件不存在时自动创建。返回 True 表示新创建。"""
    if os.path.exists(path):
        return False
    dirpath = os.path.dirname(path)
    if not os.path.exists(dirpath):
        os.makedirs(dirpath)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(TEMPLATE, f, ensure_ascii=False, indent=2)
    return True


def _load(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _save(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def _resolve_platforms(platform):
    if platform == "all":
        return [p for p in PLATFORM_CONFIG if os.path.exists(PLATFORM_CONFIG[p]["xcstrings"])]
    return [platform]


def _add_to_xcode_project(xcstrings_path, project_path):
    """通过 add_to_project.rb 将文件加入 Xcode 工程。"""
    add_script = os.path.join(SCRIPT_DIR, "add_to_project.rb")
    # 计算平台
    platform_map = {
        "iOS": "ios", "tvOS": "tvos", "Mac": "mac"
    }
    platform = None
    for key, val in platform_map.items():
        if key in xcstrings_path:
            platform = val
            break
    if not platform:
        print(f"  [!] 无法推断平台: {xcstrings_path}")
        return

    # 用相对于项目根目录的路径
    relative_path = os.path.relpath(xcstrings_path, PROJECT_ROOT)
    result = subprocess.run(
        ["ruby", add_script, platform, relative_path],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"  [!] 加入 Xcode 工程失败: {result.stderr.strip()}")
    else:
        # 脚本输出 "ADDED: ..." 或 "ALREADY_EXISTS: ..."
        print(f"  [✓] {result.stdout.strip().splitlines()[-1]}")


# ---- commands ----

def cmd_check(path, key):
    if not os.path.exists(path):
        print(f"NO_FILE: {path}")
        return False
    data = _load(path)
    strings = data.get("strings", {})
    if key in strings:
        loc = strings[key].get("localizations", {})
        en = loc.get("en", {}).get("stringUnit", {}).get("value", "")
        zh = loc.get("zh-Hans", {}).get("stringUnit", {}).get("value", "")
        print(f"EXISTS: {key}")
        print(f"  en: {en}")
        print(f"  zh-Hans: {zh}")
        return True
    else:
        print(f"NOT_FOUND: {key}")
        return False


def cmd_add(path, key, en_value, zh_value=None, project_path=None):
    if zh_value is None:
        zh_value = key

    is_new = _ensure_file(path)
    data = _load(path)
    strings = data.get("strings", {})

    if key in strings:
        print(f"ALREADY_EXISTS: {key} — 未修改")
        return

    strings[key] = {
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en_value}},
            "zh-Hans": {"stringUnit": {"state": "translated", "value": zh_value}},
        }
    }
    data["strings"] = strings
    _save(path, data)
    print(f"ADDED: {key} → en={en_value}, zh-Hans={zh_value}")

    if is_new and project_path and os.path.exists(project_path):
        _add_to_xcode_project(path, project_path)


def cmd_list(path):
    if not os.path.exists(path):
        print(f"NO_FILE: {path}")
        return
    data = _load(path)
    for key in data.get("strings", {}):
        print(key)


def cmd_sync(path, code_dir, project_path=None):
    """扫描代码中所有 NSLocalizedString key，从 iOS 参考翻译，批量同步。"""
    if not os.path.exists(path):
        is_new = True
        _ensure_file(path)
    else:
        is_new = False

    data = _load(path)
    strings = data.get("strings", {})

    # 扫描代码中的 key
    result = subprocess.run(
        ["grep", "-roh", 'NSLocalizedString("[^"]*"', code_dir, "--include=*.swift"],
        capture_output=True, text=True
    )
    code_keys = set(re.findall(r'NSLocalizedString\("([^"]*)"', result.stdout))

    def _has_translations(entry):
        return bool(entry and entry.get("localizations"))

    added = 0
    filled = 0
    for key in sorted(code_keys):
        entry = strings.get(key)
        if _has_translations(entry):
            continue

        strings[key] = {
            "localizations": {
                "en": {"stringUnit": {"state": "translated", "value": key}},
                "zh-Hans": {"stringUnit": {"state": "translated", "value": key}},
            }
        }
        if entry is None:
            added += 1
        else:
            filled += 1

    parts = [f"SYNCED: {added} new keys"]
    if filled:
        parts.append(f"{filled} filled")
    parts.append(f"{len(code_keys)} total")
    print(", ".join(parts))

    data["strings"] = strings
    _save(path, data)
    print(f"SYNCED: {added} new keys, {len(code_keys)} total")

    if is_new and project_path and os.path.exists(project_path):
        _add_to_xcode_project(path, project_path)


# ---- main ----

def _usage():
    print(__doc__)
    sys.exit(1)


if __name__ == "__main__":
    args = sys.argv[1:]

    platform = None
    flags = []
    for a in args:
        if a in ("ios", "tvos", "mac", "all"):
            platform = a
        else:
            flags.append(a)

    if not platform or not flags:
        _usage()

    cmd = flags[0]
    platform_keys = _resolve_platforms(platform)

    if cmd == "--check" and len(flags) >= 2:
        exit_code = 0
        for p in platform_keys:
            cfg = PLATFORM_CONFIG[p]
            print(f"[{p}] ", end="")
            if not cmd_check(cfg["xcstrings"], flags[1]):
                exit_code = 1
        sys.exit(exit_code)

    elif cmd == "--add" and len(flags) >= 3:
        en_val = flags[2]
        zh_val = flags[3] if len(flags) >= 4 else None
        for p in platform_keys:
            cfg = PLATFORM_CONFIG[p]
            print(f"[{p}] ", end="")
            cmd_add(cfg["xcstrings"], flags[1], en_val, zh_val, cfg["project"])

    elif cmd == "--list":
        for p in platform_keys:
            cfg = PLATFORM_CONFIG[p]
            print(f"--- {p} ---")
            cmd_list(cfg["xcstrings"])

    elif cmd == "--sync":
        for p in platform_keys:
            cfg = PLATFORM_CONFIG[p]
            print(f"[{p}] ", end="")
            cmd_sync(cfg["xcstrings"], cfg["code_dir"], cfg["project"])

    else:
        _usage()
