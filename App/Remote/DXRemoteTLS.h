#import <Foundation/Foundation.h>
#import <Security/Security.h>
NS_ASSUME_NONNULL_BEGIN
// Locally generated P-256 identity. No private key leaves Keychain.
@interface DXRemoteTLS : NSObject
@property(nonatomic,readonly) SecIdentityRef _Nullable identity;
@property(nonatomic,readonly) NSData *certificate;
@property(nonatomic,readonly) NSString *fingerprint;
- (instancetype)initWithDirectory:(NSString *)directory keyTag:(NSString *)tag;
- (BOOL)prepareAddress:(NSString *)address error:(NSError **)error;
@end
// Small DER encoder used exclusively for a fixed X.509 v3 server-certificate schema.
NSData * _Nullable DXRemoteCreateCertificate(SecKeyRef key,NSString *address,NSError **error);
BOOL DXRemoteSetSecret(NSString *account,NSString * _Nullable value,NSError **error);
NSString * _Nullable DXRemoteGetSecret(NSString *account);
NS_ASSUME_NONNULL_END
