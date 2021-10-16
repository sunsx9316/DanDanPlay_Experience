// AFWebDAVManager.h
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

#import <Foundation/Foundation.h>

#import <AFNetworking/AFHTTPSessionManager.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AFWebDAVDepth) {
    AFWebDAVZeroDepth = 0,
    AFWebDAVOneDepth = 1,
    AFWebDAVInfinityDepth = (NSUIntegerMax - 1),
};

typedef NS_OPTIONS(NSUInteger, AFWebDAVLockType) {
    AFWebDAVLockTypeWrite = 0,
};

typedef NS_ENUM(NSUInteger, AFWebDAVLockScope) {
    AFWebDAVLockScopeExclusive = 0,
    AFWebDAVLockScopeShared = 1,
};

/**
 `AFWebDAVManager` encapsulates common patterns for interacting with WebDAV servers.
 
 @discussion In order to prevent possible race conditions caused by simultaneous non-idempotent WebDAV requests, `operationQueue.maxConcurrentOperationCount` is set to `1` by default.
 
 @see http://tools.ietf.org/html/rfc4918
 */

@class AFURLSessionManagerTaskDelegate, AFWebDAVMultiStatusResponse;
@interface AFWebDAVManager : AFHTTPSessionManager

///-------------------------------
/// @name Accessing XML Namespaces
///-------------------------------

/**
 XML namespaces keyed by their abbreviation. By default, this property uses the "D" abbreviation for the "DAV"  
 */
@property (nonatomic, strong) NSDictionary *namespacesKeyedByAbbreviation;

///-------------------------------
/// @name File Manager Interaction
///-------------------------------

/**
 Lists the contents of the directory at path represented by the specified URL string.
 */
- (void)contentsOfDirectoryAtURLString:(NSString *)URLString
                             recursive:(BOOL)recursive
                     completionHandler:(void (^)(NSArray <AFWebDAVMultiStatusResponse *>* _Nullable items, NSError * _Nullable error))completionHandler;

/**
 Creates a directory at the path represented by the specified URL string.
 */
- (void)createDirectoryAtURLString:(NSString *)URLString
       withIntermediateDirectories:(BOOL)createIntermediateDirectories
                 completionHandler:(void (^)(NSURL *directoryURL, NSError *error))completionHandler;

/**
 Creates a file at the path represented by the specified URL string.
 */
- (void)createFileAtURLString:(NSString *)URLString
  withIntermediateDirectories:(BOOL)createIntermediateDirectories
                     contents:(NSData *)contents
            completionHandler:(void (^)(NSURL *fileURL, NSError *error))completionHandler;

/**
 Removes a file at the path represented by the specified URL string.

 */
- (void)removeFileAtURLString:(NSString *)URLString
            completionHandler:(void (^)(NSURL *fileURL, NSError *error))completionHandler;

/**
 Moves a file from path to another path represented by the specified URL strings.

 */
- (void)moveItemAtURLString:(NSString *)originURLString
                toURLString:(NSString *)destinationURLString
                  overwrite:(BOOL)overwrite
          completionHandler:(void (^)(NSURL *fileURL, NSError *error))completionHandler;

/**
 Copies a file from path to another path represented by the specified URL strings.

 */
- (void)copyItemAtURLString:(NSString *)originURLString
                toURLString:(NSString *)destinationURLString
                  overwrite:(BOOL)overwrite
          completionHandler:(void (^)(NSURL *fileURL, NSError *error))completionHandler;

/**
 Retrieves the contents of a file at the path represented by the specified URL string.
 */
- (void)contentsOfFileAtURLString:(NSString *)URLString
                completionHandler:(void (^)(NSData *contents, NSError *error))completionHandler;

///----------------------------------
/// @name WebDAV Protocol Interaction
///----------------------------------

/**
 Creates and runs an `AFHTTPRequestOperation` with a `PUT` request with the specified data.

 @param URLString The URL string used to create the request URL.
 @param data The data to be sent.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes two arguments: the request operation, and the response object created by the client response serializer.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes a two arguments: the request operation and the error describing the network or parsing error that occurred.

 @see -HTTPRequestOperationWithRequest:success:failure:
 */
- (NSURLSessionDataTask *)PUT:(NSString *)URLString
                           data:(NSData *)data
                        success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                        failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

/**
 Creates and runs an `AFHTTPRequestOperation` with a `PUT` request with contents of the specified file.

 @param URLString The URL string used to create the request URL.
 @param fileURL The file whose contents will be sent.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes two arguments: the request operation, and the response object created by the client response serializer.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes a two arguments: the request operation and the error describing the network or parsing error that occurred.

 @see -HTTPRequestOperationWithRequest:success:failure:
 */
- (NSURLSessionDataTask *)PUT:(NSString *)URLString
                           file:(NSURL *)fileURL
                        success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                        failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

/**
 Creates and runs an `AFHTTPRequestOperation` with a `PROPFIND` request with the specified properties.

 @param URLString The URL string used to create the request URL.
 @param propertyNames The property names to include in the request. If `nil`, all properties will be requested.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes two arguments: the request operation, and the response object created by the client response serializer.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes a two arguments: the request operation and the error describing the network or parsing error that occurred.

 @see -HTTPRequestOperationWithRequest:success:failure:
 */
- (NSURLSessionDataTask *)PROPFIND:(NSString *)URLString
                       propertyNames:(NSArray *)propertyNames
                               depth:(AFWebDAVDepth)depth
                             success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                             failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

/**
 Creates and runs an `AFHTTPRequestOperation` with a `PROPPATCH` request with the specified properties to set and remove.

 @param URLString The URL string used to create the request URL.
 @param propertiesToSet The properties to set and their associated values.
 @param propertiesToRemove The properties to remove.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes two arguments: the request operation, and the response object created by the client response serializer.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes a two arguments: the request operation and the error describing the network or parsing error that occurred.

 @see -HTTPRequestOperationWithRequest:success:failure:
 */
- (NSURLSessionDataTask *)PROPPATCH:(NSString *)URLString
                                  set:(NSDictionary *)propertiesToSet
                               remove:(NSArray *)propertiesToRemove
                              success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                              failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

/**
 Creates and runs an `AFHTTPRequestOperation` with a `MKCOL` request with the specified URL string.

 @param URLString The URL string used to create the request URL.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes two arguments: the request operation, and the response.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes a two arguments: the request operation and the error describing the network or parsing error that occurred.

 @see -HTTPRequestOperationWithRequest:success:failure:
 */
- (NSURLSessionDataTask *)MKCOL:(NSString *)URLString
                          success:(void (^)(NSURLSessionDataTask *operation, NSURLResponse *response))success
                          failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

/**
 Creates and runs an `AFHTTPRequestOperation` with a `COPY` request with the specified source and destination URL strings.

 @param sourceURLString The URL string for the source path.
 @param destinationURLString The URL string for the destination path.
 @param overwrite Whether to overwrite any existing contents at the destination path.
 @param IfHeaderFieldValue The value of the `If` HTTP header field, if any.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes two arguments: the request operation, and the response object created by the client response serializer.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes a two arguments: the request operation and the error describing the network or parsing error that occurred.

 @see -HTTPRequestOperationWithRequest:success:failure:
 */
- (NSURLSessionDataTask *)COPY:(NSString *)sourceURLString
                     destination:(NSString *)destinationURLString
                       overwrite:(BOOL)overwrite
                      conditions:(NSString *)IfHeaderFieldValue
                         success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

/**
 Creates and runs an `AFHTTPRequestOperation` with a `MOVE` request with the specified source and destination URL strings.

 @param sourceURLString The URL string for the source path.
 @param destinationURLString The URL string for the destination path.
 @param overwrite Whether to overwrite any existing contents at the destination path.
 @param IfHeaderFieldValue The value of the `If` HTTP header field, if any.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes two arguments: the request operation, and the response object created by the client response serializer.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes a two arguments: the request operation and the error describing the network or parsing error that occurred.

 @see -HTTPRequestOperationWithRequest:success:failure:
 */
- (NSURLSessionDataTask *)MOVE:(NSString *)sourceURLString
                     destination:(NSString *)destinationURLString
                       overwrite:(BOOL)overwrite
                      conditions:(NSString *)IfHeaderFieldValue
                         success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

/**
 Creates and runs an `AFHTTPRequestOperation` with a `LOCK` request with the specified URL string and lock attributes.

 @param URLString The URL string for the lock path.
 @param timeoutInterval The timeout interval for the lock.
 @param depth The depth of the lock.
 @param scope The scope of the lock.
 @param type The type of the lock.
 @param ownerURL The owner of the lock.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes two arguments: the request operation, and the resulting lock token.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes a two arguments: the request operation and the error describing the network or parsing error that occurred.

 @see -HTTPRequestOperationWithRequest:success:failure:
 */
- (NSURLSessionDataTask *)LOCK:(NSString *)URLString
                         timeout:(NSTimeInterval)timeoutInterval
                           depth:(AFWebDAVDepth)depth
                           scope:(AFWebDAVLockScope)scope
                            type:(AFWebDAVLockType)type
                           owner:(NSURL *)ownerURL
                         success:(void (^)(NSURLSessionDataTask *operation, NSString *lockToken))success
                         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

/**
 Creates and runs an `AFHTTPRequestOperation` with a `UNLOCK` request with the specified URL string and lock attributes.

 @param URLString The URL string for the lock path.
 @param lockToken The lock token.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes two arguments: the request operation, and the response object created by the client response serializer.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes a two arguments: the request operation and the error describing the network or parsing error that occurred.

 @see -HTTPRequestOperationWithRequest:success:failure:
 */
- (NSURLSessionDataTask *)UNLOCK:(NSString *)URLString
                             token:(NSString *)lockToken
                           success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                           failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;
@end

#pragma mark -

/**
 `AFWebDAVRequestSerializer` is the default request serializer of `AFWebDAVManager`.
 */
@interface AFWebDAVRequestSerializer : AFHTTPRequestSerializer

@end

/**
 `AFWebDAVSharePointRequestSerializer` is a request serializer for `AFWebDAVManager` to be used to accomodate differences in how WebDAV is implemented on SharePoint servers.
 */
@interface AFWebDAVSharePointRequestSerializer : AFWebDAVRequestSerializer

@end

#pragma mark -

/**
 `AFWebDAVMultiStatusResponseSerializer` is the default response serializer of `AFWebDAVManager`, which automatically handles any multi-status responses from a WebDAV server.
 
 @discussion The response object of `AFWebDAVMultiStatusResponseSerializer` is an array of `AFWebDAVMultiStatusResponse` objects.
 */
@interface AFWebDAVMultiStatusResponseSerializer : AFHTTPResponseSerializer

@end

/**
 `AFWebDavMultiStatusResponse` is a subclass of `NSHTTPURLResponse` that is returned from multi-status responses sent by WebDAV servers.
 */
@interface AFWebDAVMultiStatusResponse : NSHTTPURLResponse

///-------------------------------------------
/// @name Getting Response Property Attributes
///-------------------------------------------

/**
 Whether the resource at the response URL is a collection.
 */
@property (readonly, nonatomic, assign, getter=isCollection) BOOL collection;

/**
 The content length of the resource at the response URL.
 */
@property (readonly, nonatomic, assign) NSUInteger contentLength;

/**
 The creation date of the resource at the response URL.
 */
@property (readonly, nonatomic, copy) NSDate *creationDate;

/**
 The last modified date of the resource at the response URL.
 */
@property (readonly, nonatomic, copy) NSDate *lastModifiedDate;

@end

NS_ASSUME_NONNULL_END
