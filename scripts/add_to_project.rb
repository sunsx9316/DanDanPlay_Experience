#!/usr/bin/env ruby
# frozen_string_literal: true

# 将文件加入 Xcode 工程，group 与物理目录保持一致，reference 方式引入。
#
# 用法:
#   ruby scripts/add_to_project.rb ios path/to/File.swift
#   ruby scripts/add_to_project.rb tvos path/to/File.swift
#   ruby scripts/add_to_project.rb ios path/to/file.xcstrings
#   ruby scripts/add_to_project.rb ios path/to/file.xcassets --group "AniXPlayer/Resource"
#   ruby scripts/add_to_project.rb ios --list-targets
#   ruby scripts/add_to_project.rb ios --dry-run path/to/File.swift
#
# 自动推断 build phase:
#   .swift / .m / .mm → Sources
#   .xcstrings / .plist / .xcassets / .json / .storyboard / .xib → Resources
#   其他 → 仅加入 group，不加入 build phase

ENV['GEM_HOME'] = File.expand_path('~/.gem/ruby/2.6.0')
require 'xcodeproj'
require 'pathname'

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

def infer_target_name(platform)
  # All three platforms use "AniXPlayer" as the target name
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

def add_file(platform, file_path, target_name: nil, group_path: nil, dry_run: false)
  config = PROJECT_MAP[platform]
  # 相对路径先基于项目根目录解析，再试 source_root
  unless file_path.start_with?('/')
    candidates = [File.join(PROJECT_ROOT, file_path), File.join(config[:source_root], file_path)]
    file_path = candidates.find { |c| File.exist?(c) } || candidates.first
  end
  file_path = File.expand_path(file_path)
  target_name ||= infer_target_name(platform)

  unless File.exist?(file_path) || dry_run
    puts "ERROR: 文件不存在: #{file_path}"
    exit 1
  end

  source_root = config[:source_root]
  relative = Pathname.new(file_path).relative_path_from(Pathname.new(source_root)).to_s

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

  # Resolve or create group hierarchy matching physical directory
  base_group_path = group_path || File.dirname(relative)
  path_parts = base_group_path.split('/').reject(&:empty?)

  group = project.main_group
  path_parts.each do |part|
    next_group = group.groups.find { |g| g.path == part }
    unless next_group
      next_group = group.new_group(part, part)
      puts "  + group: #{part}"
    end
    group = next_group
  end

  # Check if already exists
  filename = File.basename(file_path)
  existing = group.files.find { |f| f.path == filename }
  if existing
    puts "ALREADY_EXISTS: #{relative}"
    return
  end

  # Add as reference (not copy)
  file_ref = group.new_reference(file_path)

  # Add to build phase
  phase_type = build_phase_for(file_path)
  case phase_type
  when :sources
    target.source_build_phase.add_file_reference(file_ref)
    puts "  + Sources: #{relative}"
  when :resources
    target.resources_build_phase.add_file_reference(file_ref)
    puts "  + Resources: #{relative}"
  else
    # For unknown types, just add to group without build phase
    # (or add to resources as catch-all)
    puts "  + Group only (unknown type): #{relative}"
  end

  project.save
  puts "ADDED: #{relative}"
end

# ---- main ----

def usage
  puts <<~USAGE
    用法:
      ruby scripts/add_to_project.rb <platform> <file_path>
      ruby scripts/add_to_project.rb <platform> --list-targets
      ruby scripts/add_to_project.rb <platform> --dry-run <file_path>
      ruby scripts/add_to_project.rb <platform> --group "Parent/Child" <file_path>

    platform: ios | tvos | mac

    自动推断:
      .swift/.m/.mm → Sources build phase
      .xcstrings/.plist/.xcassets → Resources build phase
  USAGE
  exit 1
end

if __FILE__ == $PROGRAM_NAME
  args = ARGV.dup

  platform = nil
  flags = []
  positional = []

  args.each do |a|
    if PROJECT_MAP.key?(a)
      platform = a
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
  group_idx = flags.index('--group')
  group_path = group_idx ? flags[group_idx + 1] : nil

  file_path = positional.first
  usage unless file_path

  add_file(platform, file_path, dry_run: dry_run, group_path: group_path)
end
