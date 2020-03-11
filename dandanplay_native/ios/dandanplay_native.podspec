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
  s.source_files = 'Classes/**/*'
  s.platform = :ios, '9.0'
  s.static_framework = true
  s.dependency 'Flutter'
  s.dependency 'JHDanmakuRender'
  s.dependency 'MobileVLCKit'
  s.dependency 'MBProgressHUD'
  s.dependency 'HandyJSON'
  s.dependency 'YYCategories'
  s.dependency 'SnapKit'
  

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
end
