//
//  NSNetService+Util.m
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/1.
//

#import "NSNetService+Util.h"
#include <arpa/inet.h>

@interface DDPAddressModel()
@property (assign, nonatomic) DDPAddressModelType type;
@property (strong, nonatomic) NSString *address;
@property (assign, nonatomic) int port;
@end

@implementation DDPAddressModel

- (NSString *)description {
    return [NSString stringWithFormat:@"type: %@, address: %@, port: %@", @(self.type), self.address, @(self.port)];
}

- (NSUInteger)hash {
    return self.address.hash ^ self.type ^ self.port;
}

- (BOOL)isEqual:(DDPAddressModel *)other {
    if (other == self) {
        return YES;
    } else if (![super isEqual:other]) {
        return NO;
    } else {
        return [self.address isEqual:other.address] && self.type == other.type && self.port == other.port;
    }
}

@end

@implementation NSNetService (Util)

- (NSArray<DDPAddressModel *> *)addressModels {
    
    char addressBuffer[INET6_ADDRSTRLEN];
    NSMutableArray *mAddress = [NSMutableArray array];

    for (NSData *data in self.addresses) {
        memset(addressBuffer, 0, INET6_ADDRSTRLEN);

        typedef union {
            struct sockaddr sa;
            struct sockaddr_in ipv4;
            struct sockaddr_in6 ipv6;
        } ip_socket_address;

        ip_socket_address *socketAddress = (ip_socket_address *)[data bytes];

        DDPAddressModelType type = DDPAddressModelTypeUnknow;
        
        if (socketAddress->sa.sa_family == AF_INET) {
            type = DDPAddressModelTypeIPV4;
        } else if (socketAddress->sa.sa_family == AF_INET6) {
            type = DDPAddressModelTypeIPV6;
        }
        
        if (socketAddress && (type == DDPAddressModelTypeIPV4 || type == DDPAddressModelTypeIPV6)) {
            const char *addressStr = inet_ntop(
                    socketAddress->sa.sa_family,
                    (type == DDPAddressModelTypeIPV4 ? (void *)&(socketAddress->ipv4.sin_addr) : (void *)&(socketAddress->ipv6.sin6_addr)),
                    addressBuffer,
                    sizeof(addressBuffer));

            int port = ntohs(type == DDPAddressModelTypeIPV4 ? socketAddress->ipv4.sin_port : socketAddress->ipv6.sin6_port);

            if (addressStr && port) {
                if (type == DDPAddressModelTypeIPV4) {
                    DDPAddressModel *model = [[DDPAddressModel alloc] init];
                    model.address = [NSString stringWithCString:addressStr encoding:NSUTF8StringEncoding];
                    model.port = port;
                    model.type = type;
                    [mAddress addObject:model];                    
                }
            }
        }
    }

    return mAddress;
}

@end
