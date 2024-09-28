//
//  ANXAddressModel.m
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/1.
//

#import "ANXAddressModel.h"
#include <arpa/inet.h>

@interface ANXAddressModel()
@property (assign, nonatomic) ANXAddressModelType type;
@property (strong, nonatomic) NSString *address;
@property (assign, nonatomic) int port;
@end

@implementation ANXAddressModel

- (NSString *)description {
    return [NSString stringWithFormat:@"type: %@, address: %@, port: %@", @(self.type), self.address, @(self.port)];
}

- (NSUInteger)hash {
    return self.address.hash ^ self.type ^ self.port;
}

- (BOOL)isEqual:(ANXAddressModel *)other {
    if (other == self) {
        return YES;
    } else if (![super isEqual:other]) {
        return NO;
    } else {
        return [self.address isEqual:other.address] && self.type == other.type && self.port == other.port;
    }
}

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        char addressBuffer[INET6_ADDRSTRLEN];

        memset(addressBuffer, 0, INET6_ADDRSTRLEN);

        typedef union {
            struct sockaddr sa;
            struct sockaddr_in ipv4;
            struct sockaddr_in6 ipv6;
        } ip_socket_address;

        ip_socket_address *socketAddress = (ip_socket_address *)[data bytes];

        ANXAddressModelType type = ANXAddressModelTypeUnknow;
        
        if (socketAddress->sa.sa_family == AF_INET) {
            type = ANXAddressModelTypeIPV4;
        } else if (socketAddress->sa.sa_family == AF_INET6) {
            type = ANXAddressModelTypeIPV6;
        }
        
        if (socketAddress && (type == ANXAddressModelTypeIPV4 || type == ANXAddressModelTypeIPV6)) {
            const char *addressStr = inet_ntop(
                    socketAddress->sa.sa_family,
                    (type == ANXAddressModelTypeIPV4 ? (void *)&(socketAddress->ipv4.sin_addr) : (void *)&(socketAddress->ipv6.sin6_addr)),
                    addressBuffer,
                    sizeof(addressBuffer));

            int port = ntohs(type == ANXAddressModelTypeIPV4 ? socketAddress->ipv4.sin_port : socketAddress->ipv6.sin6_port);

            if (addressStr && port) {
                self.address = [NSString stringWithCString:addressStr encoding:NSUTF8StringEncoding];
                self.port = port;
                self.type = type;
            }
        }
    }
    
    return self;
}

@end
