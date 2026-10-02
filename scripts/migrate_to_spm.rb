#!/usr/bin/env ruby
# frozen_string_literal: true

# 一次性迁移脚本：把某平台 Xcode 工程从 CocoaPods 迁到 Firebase SPM。
#
# 注意: 仅用于本次迁移。脚本幂等，但工程迁移完成后不建议再对已迁移工程重跑，
#       以免误删人为保留的结构。
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

  remove_pods_frameworks(project)
  remove_empty_pods_groups(project)
end

# 删除 CocoaPods 留下的空 "Pods" group（引用已全部移除后残留）。
def remove_empty_pods_groups(project)
  project.main_group.recursive_children.dup.each do |child|
    next unless child.is_a?(Xcodeproj::Project::Object::PBXGroup)
    next unless child.display_name == 'Pods'
    next unless child.children.empty?

    child.remove_from_project
  end
end

# CocoaPods use_frameworks! 会生成 Pods_<target>.framework 并直接链接，
# 需连同其 PBXBuildFile 引用一起移除，否则链接报 framework not found。
def remove_pods_frameworks(project)
  project.targets.each do |target|
    target.build_phases.each do |phase|
      phase.files.dup.each do |build_file|
        name = build_file.file_ref&.path.to_s
        next unless name.match?(/Pods_.*\.framework\z/) || build_file.display_name.to_s.include?('Pods_')

        build_file.remove_from_project
      end
    end
  end

  project.files.dup.each do |file|
    file.remove_from_project if file.path.to_s.match?(/Pods_.*\.framework\z/)
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
