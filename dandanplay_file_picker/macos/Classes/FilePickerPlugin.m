#import "FilePickerPlugin.h"
#import <Cocoa/Cocoa.h>
#import "FileUtils.h"

@interface FilePickerPlugin()
@property (nonatomic, copy) FlutterResult result;
@end

@implementation FilePickerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"miguelruivo.flutter.plugins.file_picker"
                                     binaryMessenger:[registrar messenger]];
    FilePickerPlugin* instance = [[FilePickerPlugin alloc] init];
    
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if (_result) {
        result([FlutterError errorWithCode:@"multiple_request"
                                    message:@"Cancelled by a second request"
                                    details:nil]);
        _result = nil;
        return;
    }
    
    _result = result;
    BOOL isMultiplePick = [call.arguments boolValue];
    if (isMultiplePick || [call.method isEqualToString:@"ANY"] || [call.method containsString:@"__CUSTOM"]) {
        NSString *fileType = [FileUtils resolveType:call.method];
        if(fileType == nil) {
            _result([FlutterError errorWithCode:@"Unsupported file extension"
                                        message:@"Make sure that you are only using the extension without the dot, (ie., jpg instead of .jpg). This could also have happened because you are using an unsupported file extension.  If the problem persists, you may want to consider using FileType.ALL instead."
                                        details:nil]);
            _result = nil;
        } else {
            [self pickFileWithType:fileType allowsMultipleSelection:isMultiplePick];
        }
    } else if([call.method isEqualToString:@"VIDEO"] ||
              [call.method isEqualToString:@"AUDIO"] ||
              [call.method isEqualToString:@"IMAGE"]) {
        NSString *fileType = [FileUtils resolveType:call.method];
        [self pickFileWithType:fileType allowsMultipleSelection:isMultiplePick];
    } else {
        result(FlutterMethodNotImplemented);
        _result = nil;
    }
    
}

#pragma mark - Resolvers

- (void)pickFileWithType:(NSString *)type allowsMultipleSelection:(BOOL)allowsMultipleSelection {
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    if (type.length > 0) {
        panel.allowedFileTypes = @[type];
    }
    
    panel.allowsMultipleSelection = allowsMultipleSelection;
    __weak typeof(self)weakSelf = self;
    
    [panel beginSheetModalForWindow:NSApp.keyWindow completionHandler:^(NSModalResponse result) {
        __strong typeof(weakSelf)self = weakSelf;
        if (!self) {
            self.result(@[]);
            self.result = nil;
            return;
        }
        
        if (result == NSModalResponseOK) {
            NSArray <NSString *>*paths = [FileUtils resolvePath:panel.URLs];
            if([paths count] > 1) {
                self.result(paths);
            } else {
                self.result(paths.firstObject);
            }
        }
        
        self.result = nil;
    }];
}

@end
