# CocoaPods → Swift Package Manager 迁移实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 AniXPlayer 三平台的 `FirebaseCrashlytics` 依赖从 CocoaPods 迁移到 SPM，并彻底移除 CocoaPods。

**Architecture:** 新增一次性迁移脚本 `scripts/migrate_to_spm.rb`（基于 `xcodeproj` gem）按平台改写 pbxproj：删除 `[CP]` build phase、Pods xcconfig 基配置与文件引用，为 iOS/Mac 添加 Firebase SPM package 与 product，修正 Crashlytics run-script 路径。随后删除所有 CocoaPods 产物，更新发布脚本、文档与 Git hooks 安装方式。

**Tech Stack:** Ruby + `xcodeproj` gem 1.27.0、Swift Package Manager、Xcode 26.6、Firebase iOS SDK 12.19.2。

**Spec:** `docs/superpowers/specs/2026-10-02-cocoapods-to-spm-design.md`

## Global Constraints

- Firebase SPM 仓库：`https://github.com/firebase/firebase-ios-sdk.git`
- Firebase 版本：`exact 12.19.2`（不追未发布 tag 的 13.x）
- SPM products：`FirebaseCrashlytics`、`FirebaseCore`，仅加到 target `AniXPlayer`
- iOS 项目级 `IPHONEOS_DEPLOYMENT_TARGET` 改为 `15.0`（App target 已是 15）；macOS、tvOS 部署目标不变
- 不修改业务代码（`Share/CocoaShare/Launcher.swift` 的 import / `FirebaseApp.configure()` 保持不变）
- pbxproj 只允许通过脚本修改，禁止手动编辑
- 提交信息遵循 Conventional Commits（type 用 `chore(build)` / `docs` / `refactor`）
- 删除 `.xcworkspace`，构建与打开工程统一改用 `.xcodeproj`
- Git hooks 由新增的 `scripts/bootstrap.sh` 安装

## Review Focus

1. Crashlytics dSYM 上传路径：迁移后必须指向 `SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run`，路径错误会导致符号化失效（构建时该 run-script 阶段会因找不到文件而报错，可作为验证）。
2. 删除 Pods xcconfig 基配置：可能同时移除链接/搜索路径设置，构建必须仍能链接成功。
3. iOS 部署目标 12→15：可能暴露可用性假设，构建须通过。
4. tvOS 工程虽无有效 pod，但仍残留 `[CP]` 引用与 xcconfig，清理后须仍能构建。
5. 全仓库对 `.xcworkspace` / `pod install` 的引用必须清零，否则贡献者会执行到失效命令。

---

### Task 1: 迁移脚本 + iOS 工程

**Files:**
- Create: `scripts/migrate_to_spm.rb`
- Modify: `iOS/AniXPlayer.xcodeproj/project.pbxproj`（通过运行脚本产生）
- Modify: `docs/superpowers/specs/2026-10-02-cocoapods-to-spm-design.md`（已在计划前同步脚本方案，无需再改）

**Interfaces:**
- Consumes: 无
- Produces: 可执行 `ruby scripts/migrate_to_spm.rb <ios|mac|tvos> [--dry-run]`，供 Task 2 / Task 3 复用；常量 `FIREBASE_URL == "https://github.com/firebase/firebase-ios-sdk.git"`、`FIREBASE_VERSION == "12.19.2"`。

- [ ] **Step 1: 创建 `scripts/migrate_to_spm.rb`，内容如下**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# 一次性迁移脚本：把某平台 Xcode 工程从 CocoaPods 迁到 Firebase SPM。
#
# 用法:
#   ruby scripts/migrate_to_spm.rb <ios|mac|tvos> [--dry-run]

ENV['GEM_HOME'] = File.expand_path('~/.gem/ruby/2.6.0')
require 'xcodeproj'

PROJECT_ROOT = File.expand_path("#{__dir__}/..")

PROJECT_MAP = {
  'ios'  => "#{PROJECT_ROOT}/iOS/AniXPlayer.xcodeproj",
  'mac'  => "#{PROJECT_ROOT}/Mac/AniXPlayer.xcodeproj",
  'tvos' => "#{PROJECT_ROOT}/tvOS/AniXPlayer.xcodeproj",
}.freeze

FIREBASE_URL = 'https://github.com/firebase/firebase-ios-sdk.git'
FIREBASE_VERSION = '12.19.2'
FIREBASE_PRODUCTS = %w[FirebaseCrashlytics FirebaseCore].freeze
TARGET_NAME = 'AniXPlayer'
OLD_RUN = '"${PODS_ROOT}/FirebaseCrashlytics/run"'
NEW_RUN = '"${BUILD_DIR%Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"'
IOS_DEPLOYMENT_TARGET = '15.0'

def strip_pods(project)
  project.targets.each do |target|
    target.build_phases.dup.each do |phase|
      target.build_phases.delete(phase) if phase.display_name.to_s.start_with?('[CP]')
    end
  end

  (project.build_configurations + project.targets.flat_map(&:build_configurations)).each do |config|
    config.base_configuration_reference = nil if config.base_configuration_reference
  end

  project.files.dup.each do |file|
    path = file.path.to_s
    file.remove_from_project if path.end_with?('.xcconfig') && path.include?('Pods-')
  end
end

def add_firebase_spm(project)
  target = project.targets.find { |t| t.name == TARGET_NAME }
  raise "target #{TARGET_NAME} not found" unless target

  package = project.root_object.package_references.find do |p|
    p.respond_to?(:repositoryURL) && p.repositoryURL == FIREBASE_URL
  end
  unless package
    package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    package.repositoryURL = FIREBASE_URL
    package.requirement = { 'kind' => 'exactVersion', 'version' => FIREBASE_VERSION }
    project.root_object.package_references << package
  end

  framework_phase = target.frameworks_build_phase
  FIREBASE_PRODUCTS.each do |product_name|
    next if target.package_product_dependencies.any? { |d| d.product_name == product_name }

    dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dep.package = package
    dep.product_name = product_name
    target.package_product_dependencies << dep

    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = dep
    framework_phase.files << build_file
  end
end

def fix_crashlytics_run_script(project)
  project.targets.each do |target|
    target.build_phases.grep(Xcodeproj::Project::Object::PBXShellScriptBuildPhase).each do |phase|
      next unless phase.shell_script.to_s.include?(OLD_RUN)

      phase.shell_script = phase.shell_script.gsub(OLD_RUN, NEW_RUN)
    end
  end
end

def set_ios_deployment_target(project)
  project.build_configurations.each do |config|
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = IOS_DEPLOYMENT_TARGET
  end
end

platform = ARGV.find { |a| PROJECT_MAP.key?(a) }
dry_run = ARGV.include?('--dry-run')
abort '用法: ruby scripts/migrate_to_spm.rb <ios|mac|tvos> [--dry-run]' unless platform

project = Xcodeproj::Project.open(PROJECT_MAP[platform])
strip_pods(project)
if %w[ios mac].include?(platform)
  add_firebase_spm(project)
  fix_crashlytics_run_script(project)
end
set_ios_deployment_target(project) if platform == 'ios'

if dry_run
  puts "[DRY RUN] #{platform} 变更未写入"
else
  project.save
  puts "迁移完成: #{platform}"
end
```

- [ ] **Step 2: 语法检查**

Run: `ruby -c scripts/migrate_to_spm.rb`
Expected: `Syntax OK`

- [ ] **Step 3: 对 iOS 工程执行迁移**

Run: `ruby scripts/migrate_to_spm.rb ios`
Expected: 输出 `迁移完成: ios`

- [ ] **Step 4: 静态验证 iOS pbxproj**

Run:
```bash
grep -n "firebase-ios-sdk" iOS/AniXPlayer.xcodeproj/project.pbxproj
grep -n "productName = FirebaseCrashlytics\|productName = FirebaseCore" iOS/AniXPlayer.xcodeproj/project.pbxproj
grep -n "SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run" iOS/AniXPlayer.xcodeproj/project.pbxproj
grep -n "version = 12.19.2" iOS/AniXPlayer.xcodeproj/project.pbxproj
grep -n "IPHONEOS_DEPLOYMENT_TARGET = 15.0" iOS/AniXPlayer.xcodeproj/project.pbxproj
grep -c "PODS_ROOT\|Pods-\|\[CP\]" iOS/AniXPlayer.xcodeproj/project.pbxproj
```
Expected: 前五条各有命中；最后一条输出 `0`

- [ ] **Step 5: 构建 iOS（会触发 SPM 解析与 Crashlytics run-script）**

Run: `xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`（首次会联网拉取 Firebase 依赖，耗时较长）

- [ ] **Step 6: 确认 dSYM 脚本路径真实存在（Review Focus #1）**

Run: `find ~/Library/Developer/Xcode/DerivedData -path '*SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run' | head -1`
Expected: 输出一个真实文件路径（Step 5 已执行该脚本，路径不存在会构建失败）

- [ ] **Step 7: 提交**

```bash
git add scripts/migrate_to_spm.rb iOS/AniXPlayer.xcodeproj/project.pbxproj
git commit -m "chore(build): iOS 迁移 FirebaseCrashlytics 到 SPM"
```

---

### Task 2: Mac 工程

**Files:**
- Modify: `Mac/AniXPlayer.xcodeproj/project.pbxproj`（通过运行脚本产生）

**Interfaces:**
- Consumes: `scripts/migrate_to_spm.rb`（Task 1）
- Produces: 迁移后的 Mac 工程

- [ ] **Step 1: 执行迁移**

Run: `ruby scripts/migrate_to_spm.rb mac`
Expected: 输出 `迁移完成: mac`

- [ ] **Step 2: 静态验证 Mac pbxproj**

Run:
```bash
grep -n "firebase-ios-sdk\|productName = FirebaseCrashlytics\|productName = FirebaseCore" Mac/AniXPlayer.xcodeproj/project.pbxproj
grep -n "SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run" Mac/AniXPlayer.xcodeproj/project.pbxproj
grep -c "PODS_ROOT\|Pods-\|\[CP\]" Mac/AniXPlayer.xcodeproj/project.pbxproj
```
Expected: 前两条有命中；最后一条输出 `0`

- [ ] **Step 3: 构建 Mac（Review Focus #2）**

Run: `xcodebuild -project Mac/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
git add Mac/AniXPlayer.xcodeproj/project.pbxproj
git commit -m "chore(build): Mac 迁移 FirebaseCrashlytics 到 SPM"
```

---

### Task 3: tvOS 工程清理

**Files:**
- Modify: `tvOS/AniXPlayer.xcodeproj/project.pbxproj`（通过运行脚本产生）

**Interfaces:**
- Consumes: `scripts/migrate_to_spm.rb`（Task 1）
- Produces: 清理后的 tvOS 工程（无 SPM 变更，因 tvOS 无 Firebase）

- [ ] **Step 1: 执行迁移（仅清理 Pods）**

Run: `ruby scripts/migrate_to_spm.rb tvos`
Expected: 输出 `迁移完成: tvos`

- [ ] **Step 2: 静态验证 tvOS pbxproj（Review Focus #4）**

Run: `grep -c "PODS_ROOT\|Pods-\|\[CP\]" tvOS/AniXPlayer.xcodeproj/project.pbxproj`
Expected: `0`；并确认 `TVOS_DEPLOYMENT_TARGET = 17.6` 仍在

- [ ] **Step 3: 构建 tvOS**

Run: `xcodebuild -project tvOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=tvOS' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
git add tvOS/AniXPlayer.xcodeproj/project.pbxproj
git commit -m "chore(build): 清理 tvOS 工程的 CocoaPods 残留"
```

---

### Task 4: 删除 CocoaPods 产物 + bootstrap.sh + .gitignore

**Files:**
- Create: `scripts/bootstrap.sh`
- Delete: `iOS/Podfile`、`Mac/Podfile`、`tvOS/Podfile`
- Delete: `iOS/AniXPlayer.xcworkspace/`、`Mac/AniXPlayer.xcworkspace/`、`tvOS/AniXPlayer.xcworkspace/`
- Delete（本地未跟踪）: `iOS/Pods/`、`Mac/Pods/`、`tvOS/Pods/`、`iOS/Podfile.lock`、`Mac/Podfile.lock`、`tvOS/Podfile.lock`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `scripts/install_hooks.sh`（已存在，不改）
- Produces: `scripts/bootstrap.sh`（可执行），供 README 引用

- [ ] **Step 1: 创建 `scripts/bootstrap.sh`**

```bash
#!/bin/bash
set -euo pipefail

# 首次 clone 后的环境初始化脚本
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 安装 Git hooks
"$SCRIPT_DIR/install_hooks.sh"

echo "Bootstrap 完成 ✓"
```

Run: `chmod +x scripts/bootstrap.sh`

- [ ] **Step 2: 删除受版本控制的 CocoaPods 文件**

```bash
git rm -r --quiet iOS/AniXPlayer.xcworkspace Mac/AniXPlayer.xcworkspace tvOS/AniXPlayer.xcworkspace
git rm --quiet iOS/Podfile Mac/Podfile tvOS/Podfile
```

- [ ] **Step 3: 删除本地未跟踪产物**

```bash
rm -rf iOS/Pods Mac/Pods tvOS/Pods
rm -f iOS/Podfile.lock Mac/Podfile.lock tvOS/Podfile.lock
```

- [ ] **Step 4: 清理 `.gitignore`**

删除文件末尾的 CocoaPods 段（`# CocoaPods` 注释块与 `Pods`、`Podfile.lock` 两行）；保留 `*.xcworkspace` 注释说明可一并删除。

- [ ] **Step 5: 验证文件删除与 bootstrap**

Run:
```bash
for d in iOS Mac tvOS; do [ -e "$d/AniXPlayer.xcworkspace" ] && echo "still exists: $d"; done
for d in iOS Mac tvOS; do [ -d "$d/Pods" ] && echo "pods still exists: $d"; done
bash -n scripts/bootstrap.sh
bash scripts/bootstrap.sh
git status --short | grep -c "^D "
```
Expected: 前两条无输出；`bash -n` 无报错；bootstrap 输出 `Bootstrap 完成 ✓`；最后一条统计删除的受版本控制文件数为正（Podfile ×3 + workspace ×3 目录及其内容）。

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "chore(build): 移除 CocoaPods 产物并新增 bootstrap 脚本"
```

---

### Task 5: 发布脚本改用 .xcodeproj、移除 pod 预检

**Files:**
- Modify: `scripts/release/archive_and_export.sh:66`
- Modify: `scripts/release/release.sh:67-77`

**Interfaces:**
- Consumes: Task 4 删除 workspace 的结果
- Produces: 可正常 archive 的发布脚本

- [ ] **Step 1: 修改 `archive_and_export.sh`**

把
```bash
    -workspace "$REPO_ROOT/$PLATFORM_DIR/AniXPlayer.xcworkspace" \
```
改为
```bash
    -project "$REPO_ROOT/$PLATFORM_DIR/AniXPlayer.xcodeproj" \
```

- [ ] **Step 2: 删除 `release.sh` 的 Pod 预检段**

删除从 `# 4. Pod install 检查 (macOS 用 CocoaPods)` 到该 `if` 块结束（含）的整段。

- [ ] **Step 3: 语法检查**

Run: `bash -n scripts/release/archive_and_export.sh && bash -n scripts/release/release.sh`
Expected: 无输出（语法 OK）

- [ ] **Step 4: 验证无残留**

Run: `grep -n "workspace\|pod install\|Podfile" scripts/release/*.sh`
Expected: 无命中

- [ ] **Step 5: 提交**

```bash
git add scripts/release/archive_and_export.sh scripts/release/release.sh
git commit -m "chore(build): 发布脚本改用 xcodeproj 并移除 pod 预检"
```

---

### Task 6: 更新文档、规则与 skill

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `.claude/rules/build-ios.md`
- Modify: `.claude/rules/git-conventions.md`
- Modify: `.claude/skills/release-app/SKILL.md`

**Interfaces:**
- Consumes: Task 4 的产物（删除 workspace、新增 bootstrap.sh）
- Produces: 与迁移后现状一致的文档

- [ ] **Step 1: 更新 `CLAUDE.md`**

- 项目描述去掉 `Swift + CocoaPods`，改为 SPM。
- 构建命令 `-workspace iOS/AniXPlayer.xcworkspace` → `-project iOS/AniXPlayer.xcodeproj`（tvOS 同理）。
- 删除「打开项目用 `.xcworkspace`」「更新 Podfile 后运行 `pod install`」两条约束，替换为「打开/构建用 `.xcodeproj`」「首次 clone 运行 `scripts/bootstrap.sh`」。
- 部署目标 iOS 12.0+ → iOS 15.0+。

- [ ] **Step 2: 更新 `README.md`**

- 环境要求去掉 `CocoaPods 1.15+`，Xcode 版本写 `26.6+`。
- 删除「安装依赖 `cd iOS && pod install`」步骤，替换为「首次 clone 后运行 `bash scripts/bootstrap.sh`」。
- 打开工程改为 `open iOS/AniXPlayer.xcodeproj`。
- 平台支持表 iOS 最低版本 12.0 → 15.0。

- [ ] **Step 3: 更新 `.claude/rules/build-ios.md`**

所有 `-workspace ...xcworkspace` 命令改为 `-project ...xcodeproj`。

- [ ] **Step 4: 更新 `.claude/rules/git-conventions.md`**

删除「通过 Podfile 自动安装 Git hooks」相关描述与目录树中的 Podfile 行，改为「通过 `scripts/bootstrap.sh` 安装」。

- [ ] **Step 5: 更新 `.claude/skills/release-app/SKILL.md`**

删除 macOS `pod install` 检查步骤（`diff Mac/Podfile.lock ...` 与「如需 pod install」说明）。

- [ ] **Step 6: 验证无残留（Review Focus #5）**

Run: `grep -rn "xcworkspace\|pod install\|CocoaPods\|Podfile" CLAUDE.md README.md .claude/`
Expected: 无命中

- [ ] **Step 7: 提交**

```bash
git add CLAUDE.md README.md .claude/
git commit -m "docs(build): 更新文档与规则为 SPM/xcodeproj 工作流"
```

---

### Task 7: 端到端最终验证

**Files:** 无（仅验证）

**Interfaces:**
- Consumes: Task 1–6 的全部产物
- Produces: 迁移完成的确认

- [ ] **Step 1: 三平台全量构建（Review Focus #3）**

```bash
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Mac/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project tvOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=tvOS' build CODE_SIGNING_ALLOWED=NO
```
Expected: 三次均 `** BUILD SUCCEEDED **`

- [ ] **Step 2: 全仓库静态检查**

Run:
```bash
grep -rn "PODS_ROOT\|Pods-\|\[CP\]" --include="project.pbxproj" .
grep -rn "\.xcworkspace\|pod install\|CocoaPods\|Podfile" --include="*.sh" --include="*.md" --include="*.rb" . | grep -v "docs/superpowers/"
git status --short
```
Expected: 第一条无输出；第二条无输出；`git status` 干净

- [ ] **Step 3: 确认 SPM 依赖**

Run: `grep -c "firebase-ios-sdk" iOS/AniXPlayer.xcodeproj/project.pbxproj Mac/AniXPlayer.xcodeproj/project.pbxproj`
Expected: 各至少 `1`

- [ ] **Step 4: 收尾说明**

向用户报告：迁移完成、三平台构建通过、CocoaPods 已移除；提醒 `13.x` 正式发布后可再评估升级。
