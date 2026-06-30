#!/usr/bin/env ruby
# frozen_string_literal: true

# Xcode 工程文件管理（添加/删除/同步）
#
# 用法:
#   ruby scripts/xcode_project.rb ios add path/to/File.swift
#   ruby scripts/xcode_project.rb tvos remove path/to/File.swift
#   ruby scripts/xcode_project.rb ios --sync path/to/Directory/
#   ruby scripts/xcode_project.rb ios --list-targets
#   ruby scripts/xcode_project.rb ios --dry-run path/to/File.swift
#
# 自动推断 build phase:
#   .swift / .m / .mm → Sources
#   .xcstrings / .plist / .xcassets / .json / .storyboard / .xib → Resources
#   其他 → 仅加入 group，不加入 build phase

ENV['GEM_HOME'] = File.expand_path('~/.gem/ruby/2.6.0')
require 'xcodeproj'
require 'pathname'
require 'find'

PROJECT_ROOT = File.expand_path("#{__dir__}/..")

PROJECT_MAP = {
  'ios' => {
    project: "#{PROJECT_ROOT}/iOS/AniXPlayer.xcodeproj",
    source_root: "#{PROJECT_ROOT}/iOS",
  },
  'tvos' => {
    project: "#{PROJECT_ROOT}/tvOS/AniXPlayer.xcodeproj",
    source_root: "#{PROJECT_ROOT}/tvOS",
  },
  'mac' => {
    project: "#{PROJECT_ROOT}/Mac/AniXPlayer.xcodeproj",
    source_root: "#{PROJECT_ROOT}/Mac",
  },
}.freeze

IGNORED_NAMES = %w[.DS_Store .git .gitignore Pods DerivedData .build].freeze

# ---- helpers ----

def source_extensions
  %w[.swift .m .mm .c .cpp .h .hpp]
end

def resource_extensions
  %w[.xcstrings .plist .xcassets .json .storyboard .xib .png .jpg .jpeg .gif .pdf .svg .ttf .otf .lproj]
end

def build_phase_for(file_path)
  ext = File.extname(file_path).downcase
  return :sources if source_extensions.include?(ext)
  return :resources if resource_extensions.include?(ext)
  nil
end

def infer_target_name(_platform)
  'AniXPlayer'
end

# ---- core logic ----

def open_project(platform)
  config = PROJECT_MAP[platform]
  raise "Unknown platform: #{platform}. Valid: ios, tvos, mac" unless config
  Xcodeproj::Project.open(config[:project])
end

def list_targets(platform)
  project = open_project(platform)
  puts "Targets in #{platform}:"
  project.targets.each { |t| puts "  #{t.name} (#{t.product_type})" }
end

# 解析文件路径（相对 → 绝对）
def resolve_path(platform, file_path)
  config = PROJECT_MAP[platform]
  unless file_path.start_with?('/')
    candidates = [File.join(PROJECT_ROOT, file_path), File.join(config[:source_root], file_path)]
    file_path = candidates.find { |c| File.exist?(c) } || candidates.first
  end
  File.expand_path(file_path)
end

# 按 real_path 在 group 树中递归搜索已有 group
def find_group_by_real_path(group, target_path)
  return group if group.real_path.to_s == target_path
  group.groups.each do |g|
    result = find_group_by_real_path(g, target_path)
    return result if result
  end
  nil
end

# 在 group 树下创建或找到匹配物理路径的 group
def ensure_group(project, group_path_parts)
  group = project.main_group

  # 路径含 .. 时，先按物理路径查找已有 group 复用，避免创建平行 group 树
  if group_path_parts.first == '..'
    full_path = File.expand_path(File.join(group.real_path, *group_path_parts))
    existing = find_group_by_real_path(project.main_group, full_path)
    return existing if existing
  end

  group_path_parts.each do |part|
    next_group = group.groups.find { |g| g.path == part }
    unless next_group
      next_group = group.new_group(part, part)
    end
    group = next_group
  end
  group
end

# 单个文件加入工程（需传入已打开的 project/target）
def add_file_to_project(project, target, platform, file_path, source_root, base_group_path: nil)
  relative = Pathname.new(file_path).relative_path_from(Pathname.new(source_root)).to_s

  group_path = base_group_path || File.dirname(relative)
  group_parts = group_path.split('/').reject(&:empty?)
  group = ensure_group(project, group_parts)

  filename = File.basename(file_path)
  existing = group.files.find { |f| f.path == filename }
  return :skip if existing

  file_ref = group.new_reference(file_path)

  phase_type = build_phase_for(file_path)
  case phase_type
  when :sources
    target.source_build_phase.add_file_reference(file_ref)
  when :resources
    target.resources_build_phase.add_file_reference(file_ref)
  end

  { relative: relative, phase: phase_type }
end

# 从工程中删除文件引用
def remove_file_from_project(project, target, file_path, source_root)
  absolute = File.expand_path(file_path)
  filename = File.basename(file_path)

  # 在所有 group 中递归查找匹配的文件引用
  file_ref = nil
  project.main_group.recursive_children.each do |child|
    next unless child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
    child_path = child.real_path.to_s rescue nil
    if child_path && File.expand_path(child_path) == absolute
      file_ref = child
      break
    end
  end

  return :not_found unless file_ref

  # 从 build phases 中移除
  [target.source_build_phase, target.resources_build_phase].each do |phase|
    phase.files.each do |bf|
      if bf.file_ref == file_ref
        phase.files.delete(bf)
        break
      end
    end
  end

  # 从 group 中移除文件引用
  file_ref.remove_from_project

  relative = Pathname.new(file_path).relative_path_from(Pathname.new(source_root)).to_s
  { relative: relative }
end

def remove_file(platform, file_path, target_name: nil, dry_run: false)
  config = PROJECT_MAP[platform]
  file_path = resolve_path(platform, file_path)
  target_name ||= infer_target_name(platform)

  unless File.exist?(file_path)
    puts "WARNING: 文件不存在，尝试从工程中移除引用: #{file_path}"
  end

  relative = Pathname.new(file_path).relative_path_from(Pathname.new(config[:source_root])).to_s

  if dry_run
    puts "[DRY RUN] remove platform=#{platform} file=#{file_path}"
    puts "          relative=#{relative}"
    return
  end

  project = open_project(platform)
  target = project.targets.find { |t| t.name == target_name }
  unless target
    puts "ERROR: target '#{target_name}' not found"
    exit 1
  end

  result = remove_file_from_project(project, target, file_path, config[:source_root])

  case result
  when :not_found
    puts "NOT_FOUND: #{relative}"
  else
    project.save
    puts "REMOVED: #{result[:relative]}"
  end
end

def add_file(platform, file_path, target_name: nil, group_path: nil, dry_run: false)
  config = PROJECT_MAP[platform]
  file_path = resolve_path(platform, file_path)
  target_name ||= infer_target_name(platform)

  unless File.exist?(file_path) || dry_run
    puts "ERROR: 文件不存在: #{file_path}"
    exit 1
  end

  unless dry_run || !File.directory?(file_path)
    puts "ERROR: 是目录，请用 --sync: #{file_path}"
    exit 1
  end

  relative = Pathname.new(file_path).relative_path_from(Pathname.new(config[:source_root])).to_s

  if dry_run
    puts "[DRY RUN] platform=#{platform} file=#{file_path}"
    puts "          relative=#{relative}"
    puts "          target=#{target_name}"
    puts "          build_phase=#{build_phase_for(file_path)}"
    return
  end

  project = open_project(platform)
  target = project.targets.find { |t| t.name == target_name }
  unless target
    puts "ERROR: target '#{target_name}' not found"
    exit 1
  end

  result = add_file_to_project(project, target, platform, file_path, config[:source_root], base_group_path: group_path)

  case result
  when :skip
    puts "ALREADY_EXISTS: #{relative}"
  else
    project.save
    tag = result[:phase] ? "[#{result[:phase].capitalize}]" : "[Group]"
    puts "#{tag} ADDED: #{result[:relative]}"
  end
end

def sync_directory(platform, dir_path, target_name: nil, dry_run: false)
  config = PROJECT_MAP[platform]
  dir_path = resolve_path(platform, dir_path)
  target_name ||= infer_target_name(platform)

  unless File.directory?(dir_path) || dry_run
    puts "ERROR: 目录不存在: #{dir_path}"
    exit 1
  end

  if dry_run
    puts "[DRY RUN] sync directory: #{dir_path}"
    return
  end

  project = open_project(platform)
  target = project.targets.find { |t| t.name == target_name }
  unless target
    puts "ERROR: target '#{target_name}' not found"
    exit 1
  end

  source_root = config[:source_root]
  added = 0
  skipped = 0
  errors = 0

  Find.find(dir_path) do |path|
    next if IGNORED_NAMES.any? { |n| path.include?("/#{n}") || path.include?("#{n}/") }
    next if File.directory?(path)

    result = add_file_to_project(project, target, platform, path, source_root)
    case result
    when :skip
      skipped += 1
    else
      tag = result[:phase] ? "[#{result[:phase].capitalize}]" : "[Group]"
      puts "#{tag} #{result[:relative]}"
      added += 1
    end
  rescue => e
    puts "ERROR: #{path} — #{e.message}"
    errors += 1
  end

  project.save
  puts "\nDone: #{added} added, #{skipped} skipped, #{errors} errors"
end

# ---- main ----

def usage
  puts <<~USAGE
    用法:
      ruby scripts/xcode_project.rb <platform> add <file_path>
      ruby scripts/xcode_project.rb <platform> remove <file_path>
      ruby scripts/xcode_project.rb <platform> --sync <directory>
      ruby scripts/xcode_project.rb <platform> --list-targets
      ruby scripts/xcode_project.rb <platform> --dry-run <file_path>

    platform: ios | tvos | mac

    add      添加单个文件到工程
    remove   从工程中移除文件引用
    --sync   递归同步目录下所有文件到工程
    --dry-run  预览，不实际修改

    自动推断:
      .swift/.m/.mm → Sources
      .xcstrings/.plist/.xcassets → Resources
  USAGE
  exit 1
end

if __FILE__ == $PROGRAM_NAME
  args = ARGV.dup

  platform = nil
  command = nil
  flags = []
  positional = []

  args.each do |a|
    if PROJECT_MAP.key?(a)
      platform = a
    elsif %w[add remove].include?(a)
      command = a
    elsif a.start_with?('--')
      flags << a
    else
      positional << a
    end
  end

  usage unless platform

  if flags.include?('--list-targets')
    list_targets(platform)
    exit 0
  end

  dry_run = flags.include?('--dry-run')

  path = positional.first

  # 兼容旧用法：无 command 且路径存在 → 默认 add
  if command.nil? && path
    if File.directory?(resolve_path(platform, path))
      command = 'sync'
    else
      command = 'add'
    end
  end

  usage unless path

  case command
  when 'remove'
    remove_file(platform, path, dry_run: dry_run)
  when 'sync'
    sync_directory(platform, path, dry_run: dry_run)
  when 'add'
    add_file(platform, path, dry_run: dry_run, group_path: nil)
  else
    usage
  end
end
