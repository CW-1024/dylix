#import "../AIContracts.h"
@interface TFAIMCP : NSObject
+ (instancetype)shared;
- (NSArray<NSDictionary *> *)servers;
- (BOOL)importJSON:(NSString *)text error:(NSError **)error;
- (void)remove:(NSString *)identifier;
- (void)setEnabled:(BOOL)enabled server:(NSString *)identifier session:(NSString *)session;
- (BOOL)enabled:(NSString *)identifier session:(NSString *)session;
- (BOOL)setAllowed:(BOOL)allowed tool:(NSString *)name server:(NSString *)identifier error:(NSError **)error;
- (void)discover:(NSString *)identifier completion:(TFAIResult)completion;
- (NSArray *)schemas:(NSString *)session;
- (void)call:(NSString *)name arguments:(NSDictionary *)arguments session:(NSString *)session completion:(TFAIResult)completion;
+ (BOOL)readOnlyTool:(NSDictionary *)tool;
@end
