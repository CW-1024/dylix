#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
NSString * _Nullable DXRemoteRandom(void);
NSString *DXRemoteHash(NSString *text);
@interface DXRemoteAccess : NSObject
@property(nonatomic,readonly) NSString *pairingCode;
@property(nonatomic,readonly) NSTimeInterval codeExpiry;
@property(nonatomic,readonly) BOOL fixedCode;
@property(nonatomic,readonly) NSArray<NSDictionary *> *pending;
@property(nonatomic,readonly) NSArray<NSDictionary *> *devices;
@property(nonatomic,readonly) NSArray<NSDictionary *> *events;
- (instancetype)initWithStore:(NSString *)store;
- (void)rotateCode;
- (BOOL)setFixedCode:(NSString *)code error:(NSError **)error;
- (NSDictionary *)beginPair:(NSDictionary *)body peer:(NSString *)peer;
- (BOOL)approve:(NSString *)identifier accepted:(BOOL)accepted error:(NSError **)error;
- (NSDictionary *)claimPair:(NSString *)identifier secret:(NSString *)secret;
- (nullable NSDictionary *)authenticateCookie:(NSString *)cookie name:(NSString *)name;
- (NSString *)csrfForToken:(NSString *)token;
- (BOOL)revoke:(nullable NSString *)identifier error:(NSError **)error;
- (nullable NSDictionary *)issueDAV:(NSString *)project readOnly:(BOOL)readOnly error:(NSError **)error;
- (void)resetEphemeral;
- (void)record:(NSString *)event;
@end
NS_ASSUME_NONNULL_END
