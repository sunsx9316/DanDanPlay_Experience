Pod::Spec.new do |s|
  s.name         = 'VLCKit'
  s.version      = '3.6.0'
  s.summary      = 'VLCKit - local build with custom libass font support'
  s.description  = 'Locally built VLCKit xcframework with --ssa-fontfamily patch, supporting iOS, tvOS, and macOS.'
  s.homepage     = 'https://code.videolan.org/videolan/VLCKit'
  s.license      = { :type => 'LGPLv2.1' }
  s.author       = { 'VideoLAN' => '' }
  s.source       = { :git => 'https://code.videolan.org/videolan/VLCKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '13.0'
  s.osx.deployment_target = '12.0'

  s.vendored_frameworks = 'Sources/VLCKitSPM/VLCKit.xcframework'
end
