#import <Foundation/Foundation.h>
// Native enrollment only. No model operation registers paths or enables this tier.
@interface TFAIToolIsolation : NSObject
+ (instancetype)shared;
- (NSArray<NSDictionary *> *)targets;
- (BOOL)enroll:(NSString *)path kind:(NSString *)kind pluginID:(NSString *)pluginID error:(NSError **)error;
- (void)remove:(NSString *)identifier;
- (NSArray<NSDictionary *> *)availableTargets:(NSString *)kind;
- (NSArray *)schemas;
- (NSDictionary *)prepare:(NSDictionary *)call error:(NSError **)error;
- (NSDictionary *)execute:(NSDictionary *)plan approved:(BOOL)approved error:(NSError **)error;
- (NSArray *)audit;
@end
