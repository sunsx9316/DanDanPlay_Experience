//
//  NSNetService+Utils.h
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AddressModelType)
typedef NS_ENUM(NSUInteger, DDPAddressModelType) {
    DDPAddressModelTypeUnknow,
    DDPAddressModelTypeIPV4,
    DDPAddressModelTypeIPV6,
};

NS_SWIFT_NAME(AddressModel)
@interface DDPAddressModel : NSObject

@property (assign, nonatomic, readonly) DDPAddressModelType type;

@property (strong, nonatomic, readonly) NSString *address;

@property (assign, nonatomic, readonly) int port;

@end

@interface NSNetService (Util)

/// address解析成数组，目前只有ipv4地址
@property (strong, nonatomic, readonly) NSArray<DDPAddressModel *> *addressModels;
@end

NS_ASSUME_NONNULL_END
