// AFWebDAVManager.m
//
// Copyright (c) 2014 AFNetworking (http://afnetworking.com/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFWebDAVManager.h"
#import "ONOXMLDocument.h"

static NSString * const AFWebDAVXMLDeclarationString = @"<?xml version=\"1.0\" encoding=\"utf-8\"?>";

static NSString * AFWebDAVStringForDepth(AFWebDAVDepth depth) {
    switch (depth) {
        case AFWebDAVZeroDepth:
            return @"0";
        case AFWebDAVOneDepth:
            return @"1";
        case AFWebDAVInfinityDepth:
        default:
            return @"infinity";
    }
}

static NSString * AFWebDAVStringForLockScope(AFWebDAVLockScope scope) {
    switch (scope) {
        case AFWebDAVLockScopeShared:
            return @"shared";
        case AFWebDAVLockScopeExclusive:
        default:
            return @"exclusive";
    }
}

static NSString * AFWebDAVStringForLockType(AFWebDAVLockType type) {
    switch (type) {
        case AFWebDAVLockTypeWrite:
        default:
            return @"write";
    }
}

#pragma mark -

@interface AFWebDAVMultiStatusResponse ()
- (instancetype)initWithResponseElement:(ONOXMLElement *)element;
@end

#pragma mark -

@implementation AFWebDAVManager

- (instancetype)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }

    self.namespacesKeyedByAbbreviation = @{@"D": @"DAV:"};

    self.requestSerializer = [AFWebDAVRequestSerializer serializer];
    self.responseSerializer = [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:@[[AFWebDAVMultiStatusResponseSerializer serializer], [AFHTTPResponseSerializer serializer]]];

    self.operationQueue.maxConcurrentOperationCount = 1;

    return self;
}

#pragma mark -

- (void)contentsOfDirectoryAtURLString:(NSString *)URLString
                             recursive:(BOOL)recursive
                     completionHandler:(void (^)(NSArray<AFWebDAVMultiStatusResponse *> *, NSError *))completionHandler
{
    [self PROPFIND:URLString propertyNames:nil depth:(recursive ? AFWebDAVInfinityDepth : AFWebDAVOneDepth) success:^(__unused NSURLSessionDataTask *operation, id responseObject) {
        if (completionHandler) {
            completionHandler(responseObject, nil);
        }
    } failure:^(__unused NSURLSessionDataTask *operation, NSError *error) {
        if (completionHandler) {
            completionHandler(nil, error);
        }
    }];
}

- (void)createDirectoryAtURLString:(NSString *)URLString
       withIntermediateDirectories:(BOOL)createIntermediateDirectories
                 completionHandler:(void (^)(NSURL *directoryURL, NSError *error))completionHandler
{
    __weak __typeof(self) weakself = self;
    [self MKCOL:URLString success:^(__unused NSURLSessionDataTask *operation, NSURLResponse *response) {
        if (completionHandler) {
            if ([NSStringFromClass([response class]) isEqualToString:@"_NSZeroData"]) {
                completionHandler(nil, nil);
            } else {
                completionHandler([response URL], nil);
            }
        }
    } failure:^(__unused NSURLSessionDataTask *operation, NSError *error) {
        __strong __typeof(weakself) strongSelf = weakself;
        NSInteger statusCode = 0;
        if ([operation.response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)operation.response;
            statusCode = httpResponse.statusCode;
        }
        
        if (statusCode == 409 && createIntermediateDirectories) {
            NSArray *pathComponents = [[operation.currentRequest URL] pathComponents];
            if ([pathComponents count] > 1) {
                [pathComponents enumerateObjectsUsingBlock:^(NSString *component, NSUInteger idx, __unused BOOL *stop) {
                    NSString *intermediateURLString = [[[pathComponents subarrayWithRange:NSMakeRange(0, idx)] arrayByAddingObject:component] componentsJoinedByString:@"/"];
                    [strongSelf MKCOL:intermediateURLString success:^(__unused NSURLSessionDataTask *MKCOLOperation, __unused NSURLResponse *MKCOLResponse) {

                    } failure:^(__unused NSURLSessionDataTask *MKCOLOperation, NSError *MKCOLError) {
                        if (completionHandler) {
                            completionHandler(nil, MKCOLError);
                        }
                    }];
                }];
            }
        } else {
            if (completionHandler) {
                completionHandler(nil, error);
            }
        }
    }];
}

- (void)createFileAtURLString:(NSString *)URLString
  withIntermediateDirectories:(BOOL)createIntermediateDirectories
                     contents:(NSData *)contents
            completionHandler:(void (^)(NSURL *fileURL, NSError *error))completionHandler
{
    __weak __typeof(self) weakself = self;
    [self PUT:URLString data:contents success:^(NSURLSessionDataTask *operation, __unused id responseObject) {
        if (completionHandler) {
            completionHandler([operation.response URL], nil);
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        NSInteger statusCode = 0;
               if ([operation.response isKindOfClass:[NSHTTPURLResponse class]]) {
                   NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)operation.response;
                   statusCode = httpResponse.statusCode;
               }
        
        __strong __typeof(weakself) strongSelf = weakself;
        if (statusCode == 409 && createIntermediateDirectories) {
            NSArray *pathComponents = [[operation.currentRequest URL] pathComponents];
            if ([pathComponents count] > 1) {
                [strongSelf createDirectoryAtURLString:[[pathComponents subarrayWithRange:NSMakeRange(0, [pathComponents count] - 1)] componentsJoinedByString:@"/"] withIntermediateDirectories:YES completionHandler:^(__unused NSURL *directoryURL, NSError *MKCOLError) {
                    if (MKCOLError) {
                        if (completionHandler) {
                            completionHandler(nil, MKCOLError);
                        }
                    } else {
                        [strongSelf createFileAtURLString:URLString withIntermediateDirectories:NO contents:contents completionHandler:completionHandler];
                    }
                }];
            }
        } else {
            if (completionHandler) {
                completionHandler(nil, error);
            }
        }
    }];
}

- (void)removeFileAtURLString:(NSString *)URLString
            completionHandler:(void (^)(NSURL *fileURL, NSError *error))completionHandler
{
    [self DELETE:URLString parameters:nil headers:nil success:^(NSURLSessionDataTask *operation, __unused id responseObject) {
        if (completionHandler) {
            completionHandler([operation.response URL], nil);
        }
    } failure:^(__unused NSURLSessionDataTask *operation, NSError *error) {
        if (completionHandler) {
            completionHandler(nil, error);
        }
    }];
}

- (void)moveItemAtURLString:(NSString *)originURLString
                toURLString:(NSString *)destinationURLString
                  overwrite:(BOOL)overwrite
          completionHandler:(void (^)(NSURL *fileURL, NSError *error))completionHandler
{
    [self MOVE:originURLString destination:destinationURLString overwrite:overwrite conditions:nil success:^(NSURLSessionDataTask *operation, __unused id responseObject) {
        if (completionHandler) {
            completionHandler([operation.response URL], nil);
        }
    } failure:^(__unused NSURLSessionDataTask *operation, NSError *error) {
        if (completionHandler) {
            completionHandler(nil, error);
        }
    }];
}

- (void)copyItemAtURLString:(NSString *)originURLString
                toURLString:(NSString *)destinationURLString
                  overwrite:(BOOL)overwrite
          completionHandler:(void (^)(NSURL *fileURL, NSError *error))completionHandler
{
    [self COPY:originURLString destination:destinationURLString overwrite:overwrite conditions:nil success:^(NSURLSessionDataTask *operation, __unused id responseObject) {
        if (completionHandler) {
            completionHandler([operation.response URL], nil);
        }
    } failure:^(__unused NSURLSessionDataTask *operation, NSError *error) {
        if (completionHandler) {
            completionHandler(nil, error);
        }
    }];
}

- (void)contentsOfFileAtURLString:(NSString *)URLString
                completionHandler:(void (^)(NSData *contents, NSError *error))completionHandler
{
    [self GET:URLString parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask *operation, __unused id responseObject) {
        if (completionHandler) {
            completionHandler(responseObject, nil);
        }
    } failure:^(__unused NSURLSessionDataTask *operation, NSError *error) {
        if (completionHandler) {
            completionHandler(nil, error);
        }
    }];
}

#pragma mark -

- (NSURLSessionDataTask *)PUT:(NSString *)URLString
                           data:(NSData *)data
                        success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                        failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure
{
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"PUT" URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString] parameters:nil error:nil];
    request.HTTPBody = data;
    return [self dataTaskWithRequest:request success:success failure:failure];
}

- (NSURLSessionDataTask *)PUT:(NSString *)URLString
                           file:(NSURL *)fileURL
                        success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                        failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure
{
    NSParameterAssert(fileURL && [fileURL isFileURL]);
    
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"PUT" URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString] parameters:nil error:nil];
    request.HTTPBodyStream = [NSInputStream inputStreamWithURL:fileURL];
    return [self dataTaskWithRequest:request success:success failure:failure];
}

#pragma mark -


- (NSURLSessionDataTask *)PROPFIND:(NSString *)URLString
                       propertyNames:(NSArray *)propertyNames
                               depth:(AFWebDAVDepth)depth
                             success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                             failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure
{
    NSMutableString *mutableXMLString = [NSMutableString stringWithString:AFWebDAVXMLDeclarationString];
    {
        [mutableXMLString appendString:@"<D:propfind"];
        [self.namespacesKeyedByAbbreviation enumerateKeysAndObjectsUsingBlock:^(NSString *abbreviation, NSString *namespace, __unused BOOL *stop) {
            [mutableXMLString appendFormat:@" xmlns:%@=\"%@\"", abbreviation, namespace];
        }];
        [mutableXMLString appendString:@">"];

        if (propertyNames) {
            [propertyNames enumerateObjectsUsingBlock:^(NSString *property, __unused NSUInteger idx, __unused BOOL *stop) {
                [mutableXMLString appendFormat:@"<%@/>", property];
            }];
        } else {
            [mutableXMLString appendString:@"<D:allprop/>"];
        }

        [mutableXMLString appendString:@"</D:propfind>"];
    }

    NSString *path = [[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString];
    
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"PROPFIND" URLString:path parameters:nil error:nil];
	[request setValue:AFWebDAVStringForDepth(depth) forHTTPHeaderField:@"Depth"];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type:"];
    [request setHTTPBody:[mutableXMLString dataUsingEncoding:NSUTF8StringEncoding]];

    return [self dataTaskWithRequest:request success:success failure:failure];
}

- (NSURLSessionDataTask *)PROPPATCH:(NSString *)URLString
                                  set:(NSDictionary *)propertiesToSet
                               remove:(NSArray *)propertiesToRemove
                              success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                              failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure
{
    NSMutableString *mutableXMLString = [NSMutableString stringWithString:AFWebDAVXMLDeclarationString];
    {
        [mutableXMLString appendString:@"<D:propertyupdate"];
        [self.namespacesKeyedByAbbreviation enumerateKeysAndObjectsUsingBlock:^(NSString *abbreviation, NSString *namespace, __unused BOOL *stop) {
            [mutableXMLString appendFormat:@" xmlns:%@=\"%@\"", abbreviation, namespace];
        }];
        [mutableXMLString appendString:@">"];

        if (propertiesToSet) {
            [mutableXMLString appendString:@"<D:set>"];
            {
                [propertiesToSet enumerateKeysAndObjectsUsingBlock:^(NSString *property, id value, __unused BOOL *stop) {
                    [mutableXMLString appendFormat:@"<%@>", property];
                    [mutableXMLString appendString:[value description]];
                    [mutableXMLString appendFormat:@"</%@>", property];
                }];
            }
            [mutableXMLString appendString:@"</D:set>"];
        }

        if (propertiesToRemove) {
            [mutableXMLString appendString:@"<D:remove>"];
            {
                [propertiesToRemove enumerateObjectsUsingBlock:^(NSString *property, __unused NSUInteger idx, __unused BOOL *stop) {
                    [mutableXMLString appendFormat:@"<D:prop><%@/></D:prop>", property];
                }];
            }
            [mutableXMLString appendString:@"</D:remove>"];
        }

        [mutableXMLString appendString:@"</D:propertyupdate>"];
    }

    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"PROPPATCH" URLString:[[self.baseURL URLByAppendingPathComponent:URLString] absoluteString] parameters:nil error:nil];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type:"];
    [request setHTTPBody:[mutableXMLString dataUsingEncoding:NSUTF8StringEncoding]];
    
    return [self dataTaskWithRequest:request success:success failure:failure];
}

- (NSURLSessionDataTask *)MKCOL:(NSString *)URLString
                          success:(void (^)(NSURLSessionDataTask *operation, NSURLResponse *response))success
                          failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure
{
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"MKCOL" URLString:[[self.baseURL URLByAppendingPathComponent:URLString] absoluteString] parameters:nil error:nil];

    return [self dataTaskWithRequest:request success:success failure:failure];
}

- (NSURLSessionDataTask *)COPY:(NSString *)sourceURLString
                     destination:(NSString *)destinationURLString
                       overwrite:(BOOL)overwrite
                      conditions:(NSString *)IfHeaderFieldValue
                         success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure
{
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"COPY" URLString:[[self.baseURL URLByAppendingPathComponent:sourceURLString] absoluteString] parameters:nil error:nil];
    [request setValue:[[self.baseURL URLByAppendingPathComponent:destinationURLString] absoluteString] forHTTPHeaderField:@"Destination"];
    [request setValue:(overwrite ? @"T" : @"F") forHTTPHeaderField:@"Overwrite"];
    if (IfHeaderFieldValue) {
        [request setValue:IfHeaderFieldValue forHTTPHeaderField:@"If"];
    }

    return [self dataTaskWithRequest:request success:success failure:failure];
}

- (NSURLSessionDataTask *)MOVE:(NSString *)sourceURLString
                     destination:(NSString *)destinationURLString
                       overwrite:(BOOL)overwrite
                      conditions:(NSString *)IfHeaderFieldValue
                         success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure
{
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"MOVE" URLString:[[self.baseURL URLByAppendingPathComponent:sourceURLString] absoluteString] parameters:nil error:nil];
    [request setValue:[[self.baseURL URLByAppendingPathComponent:destinationURLString] absoluteString] forHTTPHeaderField:@"Destination"];
    [request setValue:(overwrite ? @"T" : @"F") forHTTPHeaderField:@"Overwrite"];
    if (IfHeaderFieldValue) {
        [request setValue:IfHeaderFieldValue forHTTPHeaderField:@"If"];
    }

    return [self dataTaskWithRequest:request success:success failure:failure];
}

- (NSURLSessionDataTask *)LOCK:(NSString *)URLString
                         timeout:(NSTimeInterval)timeoutInterval
                           depth:(AFWebDAVDepth)depth
                           scope:(AFWebDAVLockScope)scope
                            type:(AFWebDAVLockType)type
                           owner:(NSURL *)ownerURL
                         success:(void (^)(NSURLSessionDataTask *operation, NSString *lockToken))success
                         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure
{
    NSMutableString *mutableXMLString = [NSMutableString stringWithString:AFWebDAVXMLDeclarationString];
    {
        [mutableXMLString appendString:@"<D:lockinfo"];
        [self.namespacesKeyedByAbbreviation enumerateKeysAndObjectsUsingBlock:^(NSString *abbreviation, NSString *namespace, __unused BOOL *stop) {
            [mutableXMLString appendFormat:@" xmlns:%@=\"%@\"", abbreviation, namespace];
        }];
        [mutableXMLString appendString:@">"];

        [mutableXMLString appendFormat:@"<D:lockscope><D:%@/></D:lockscope>", AFWebDAVStringForLockScope(scope)];
        [mutableXMLString appendFormat:@"<D:locktype><D:%@/></D:locktype>", AFWebDAVStringForLockType(type)];
        if (ownerURL) {
            [mutableXMLString appendFormat:@"<D:owner><D:href>%@</D:href></D:owner>", [ownerURL absoluteString]];
        }

        [mutableXMLString appendString:@"</D:lockinfo>"];
    }

    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"LOCK" URLString:[[self.baseURL URLByAppendingPathComponent:URLString] absoluteString] parameters:nil error:nil];
    [request setValue:AFWebDAVStringForDepth(depth) forHTTPHeaderField:@"Depth"];
    if (timeoutInterval > 0) {
        [request setValue:[@(timeoutInterval) stringValue] forHTTPHeaderField:@"Timeout"];
    }

    return [self dataTaskWithRequest:request success:success failure:failure];
}

- (NSURLSessionDataTask *)UNLOCK:(NSString *)URLString
                             token:(NSString *)lockToken
                           success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                           failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure
{
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:@"UNLOCK" URLString:[[self.baseURL URLByAppendingPathComponent:URLString] absoluteString] parameters:nil error:nil];
    [request setValue:lockToken forHTTPHeaderField:@"Lock-Token"];

    return [self dataTaskWithRequest:request success:success failure:failure];
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                                      success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                                      failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    __block NSURLSessionDataTask *aTask = nil;
    aTask = [self dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (error) {
            if (failure) {
                failure(aTask, error);
            }
        } else {
            if (success) {
                success(aTask, responseObject);
            }
        }
    }];
    [aTask resume];
    return aTask;
}

@end

#pragma mark -

@implementation AFWebDAVRequestSerializer

@end

@implementation AFWebDAVSharePointRequestSerializer

#pragma mark - AFURLResponseSerializer

- (NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request
                               withParameters:(id)parameters
                                        error:(NSError *__autoreleasing *)error
{
    
    NSMutableURLRequest *mutableRequest = [[super requestBySerializingRequest:request withParameters:parameters error:error] mutableCopy];
    return mutableRequest;
}

@end

#pragma mark -

@implementation AFWebDAVMultiStatusResponseSerializer

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.acceptableContentTypes = [[NSSet alloc] initWithObjects:@"application/xml", @"text/xml", nil];
    self.acceptableStatusCodes = [NSIndexSet indexSetWithIndex:207];

    return self;
}

#pragma mark - AFURLResponseSerializer

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    if (![self validateResponse:(NSHTTPURLResponse *)response data:data error:error]) {
        return nil;
    }

    NSMutableArray *mutableResponses = [NSMutableArray array];

    ONOXMLDocument *XMLDocument = [ONOXMLDocument XMLDocumentWithData:data error:error];
    for (ONOXMLElement *element in [XMLDocument.rootElement childrenWithTag:@"response"]) {
        AFWebDAVMultiStatusResponse *memberResponse = [[AFWebDAVMultiStatusResponse alloc] initWithResponseElement:element];
        if (memberResponse) {
            [mutableResponses addObject:memberResponse];
        }
    }

    return [NSArray arrayWithArray:mutableResponses];
}

@end

#pragma mark -

@interface AFWebDAVMultiStatusResponse ()
@property (readwrite, nonatomic, assign, getter=isCollection) BOOL collection;
@property (readwrite, nonatomic, assign) NSUInteger contentLength;
@property (readwrite, nonatomic, copy) NSDate *creationDate;
@property (readwrite, nonatomic, copy) NSDate *lastModifiedDate;
@end

@implementation AFWebDAVMultiStatusResponse

- (instancetype)initWithResponseElement:(ONOXMLElement *)element {
    NSParameterAssert(element);

    NSString *href = [[element firstChildWithTag:@"href" inNamespace:@"D"] stringValue];
    NSInteger status = [[[element firstChildWithTag:@"status" inNamespace:@"D"] numberValue] integerValue];

    self = [self initWithURL:[NSURL URLWithString:href] statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:nil];
    if (!self) {
        return nil;
    }

    ONOXMLElement *propElement = [[element firstChildWithTag:@"propstat"] firstChildWithTag:@"prop"];
    for (ONOXMLElement *resourcetypeElement in [propElement childrenWithTag:@"resourcetype"]) {
        if ([resourcetypeElement childrenWithTag:@"collection"].count > 0) {
            self.collection = YES;
            break;
        }
    }

    self.contentLength = [[[propElement firstChildWithTag:@"getcontentlength" inNamespace:@"D"] numberValue] unsignedIntegerValue];
    self.creationDate = [[propElement firstChildWithTag:@"creationdate" inNamespace:@"D"] dateValue];
    self.lastModifiedDate = [[propElement firstChildWithTag:@"getlastmodified" inNamespace:@"D"] dateValue];

    return self;
}

@end
