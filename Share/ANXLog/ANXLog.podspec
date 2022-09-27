#
# Be sure to run `pod lib lint ANXLog.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ANXLog'
  s.version          = '0.1.0'
  s.summary          = '日志库'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/jimhuang/ANXLog'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'jimhuang' => 'jimhuang@futunn.com' }
  s.source           = { :git => 'https://github.com/jimhuang/ANXLog.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'

  s.source_files = 'ANXLog/Classes/**/*'
  s.ios.vendored_frameworks = 'ANXLog/Resources/iOS/mars.framework'
  s.osx.vendored_frameworks = 'ANXLog/Resources/Mac/mars.framework'
  s.libraries = 'resolv.9', 'z'
  s.frameworks = 'SystemConfiguration', 'CoreTelephony'
  # s.dependency 'SSZipArchive'
  # s.resource_bundles = {
  #   'ANXLog' => ['ANXLog/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
