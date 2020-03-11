#import "DandanplayNativePlugin.h"
#if __has_include(<dandanplay_native/dandanplay_native-Swift.h>)
#import <dandanplay_native/dandanplay_native-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "dandanplay_native-Swift.h"
#endif

@implementation DandanplayNativePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftDandanplayNativePlugin registerWithRegistrar:registrar];
}
@end
