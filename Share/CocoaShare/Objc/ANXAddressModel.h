//
//  ANXAddressModel.h
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AddressModelType)
typedef NS_ENUM(NSUInteger, ANXAddressModelType) {
    ANXAddressModelTypeUnknow,
    ANXAddressModelTypeIPV4,
    ANXAddressModelTypeIPV6,
};

NS_SWIFT_NAME(AddressModel)
@interface ANXAddressModel : NSObject

@property (assign, nonatomic, readonly) ANXAddressModelType type;

@property (strong, nonatomic, readonly) NSString *address;

@property (assign, nonatomic, readonly) int port;

- (instancetype)initWithData:(NSData *)data;

@end


NS_ASSUME_NONNULL_END
