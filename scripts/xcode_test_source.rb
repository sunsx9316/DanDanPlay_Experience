#!/usr/bin/env ruby
# frozen_string_literal: true

# 把测试源文件加入 AniXPlayerTests target（无宿主测试）。
#
# 用法:
#   ruby scripts/xcode_test_source.rb Mac/AniXPlayerTests/MembershipTests.swift
#   ruby scripts/xcode_test_source.rb Mac/AniXPlayerTests/A.swift Mac/AniXPlayerTests/B.swift
#
# 说明:
#   - 测试 target 的源文件不在主 App target 中；
#   - 该脚本只处理 AniXPlayerTests，重复执行是幂等的。

ENV['GEM_HOME'] = File.expand_path('~/.gem/ruby/2.6.0')
require 'xcodeproj'
require 'pathname'

ROOT = File.expand_path("#{__dir__}/..")
PROJECT_PATH = "#{ROOT}/Mac/AniXPlayer.xcodeproj"

if ARGV.empty?
  warn '用法: ruby scripts/xcode_test_source.rb Mac/AniXPlayerTests/FooTests.swift [...]'
  exit 1
end

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == 'AniXPlayerTests' }
abort '找不到 AniXPlayerTests target' unless target

group = project.main_group.groups.find { |g| g.name == 'AniXPlayerTests' }
abort '找不到 AniXPlayerTests group' unless group

ARGV.each do |arg|
  absolute = File.expand_path(arg, ROOT)
  unless File.exist?(absolute)
    warn "跳过（文件不存在）: #{absolute}"
    next
  end

  relative = Pathname.new(absolute).relative_path_from(Pathname.new("#{ROOT}/Mac")).to_s
  filename = File.basename(absolute)

  file_ref = group.files.find { |f| f.path == relative || f.path == filename }
  unless file_ref
    file_ref = group.new_reference(relative)
  end

  already_added = target.source_build_phase.files.any? { |bf| bf.file_ref == file_ref }
  target.source_build_phase.add_file_reference(file_ref) unless already_added

  puts "[Tests] #{already_added ? 'EXISTS' : 'ADDED'}: #{relative}"
end

project.save
