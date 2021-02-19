#
# Be sure to run `pod lib lint DDPShare.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DDPShare'
  s.version          = '0.1.0'
  s.summary          = 'A short description of DDPShare.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/sunsx9316/DDPShare'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'sunsx9316' => 'sun_8434@163.com' }
  s.source           = { :git => 'https://github.com/sunsx9316/DDPShare.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform = :osx
  s.osx.deployment_target = "10.10"
  s.ios.deployment_target = '11.0'

  s.source_files = 'DDPShare/Classes/**/*'

  # s.resource_bundles = {
  #   'DDPShare' => ['DDPShare/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'Cocoa'
  s.dependency 'JHDanmakuRender'
  s.dependency 'HandyJSON'
end
