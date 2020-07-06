#import "DandanplayfilepickerPlugin.h"
#if __has_include(<dandanplayfilepicker/dandanplayfilepicker-Swift.h>)
#import <dandanplayfilepicker/dandanplayfilepicker-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "dandanplayfilepicker-Swift.h"
#endif

@implementation DandanplayfilepickerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftDandanplayfilepickerPlugin registerWithRegistrar:registrar];
}
@end
