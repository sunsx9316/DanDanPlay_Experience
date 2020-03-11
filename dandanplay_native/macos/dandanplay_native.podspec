#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint dandanplay_native.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'dandanplay_native'
  s.version          = '0.0.1'
  s.summary          = 'dandanplay native plugin.'
  s.description      = <<-DESC
dandanplay native plugin.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,m,swift}', 'ios_mac_share/**/*.{h,m,swift}', 'DDPCategory/**/*.{h,m,swift}'
  s.static_framework = true
  s.dependency 'FlutterMacOS'
  s.dependency 'JHDanmakuRender'
  s.dependency 'VLCKit'
  s.dependency 'SnapKit'
  s.dependency 'HandyJSON'
  s.dependency 'Masonry'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

end
