#import <Foundation/Foundation.h>
// Foundation-only harness: image decoding is not exercised in these tests.
@interface UIImage : NSObject
+ (instancetype)imageWithData:(NSData *)data;
@end
@implementation UIImage
+ (instancetype)imageWithData:(NSData *)data {return nil;}
@end
NSString *UIApplicationDidEnterBackgroundNotification=@"FixtureBackground";
#import "../App/AI/AIContracts.h"
#import "../App/AI/AIV2Contracts.h"
#import "../App/AI/Tools/TFAIWebTools.h"
#import "../App/AI/Core/AIPolicy.h"
static NSMutableArray *personaCaptured;
static void(^FixtureTransport)(NSArray *,NSArray *,TFAIEvent);
static NSDictionary *FixtureContextOverrides;
static NSArray *FixtureToolSchemas;
static NSArray *FixtureIsolationSchemas;
static NSUInteger FixtureIsolationReads;
static NSString *FixtureSkillMetadata;
static NSUInteger requests,executions;static NSString *mode;static NSMutableArray *events;static NSDictionary *terminal;
static void Check(BOOL yes,NSString *name){if(!yes){NSLog(@"FAIL %@",name);exit(1);}NSLog(@"PASS %@",name);}
@implementation TFAITransport
- (void)cancel{}
- (void)send:(NSArray *)messages connection:(NSDictionary *)connection tools:(NSArray *)tools event:(TFAIEvent)event{requests++;if(FixtureTransport){FixtureTransport(messages,tools,event);return;}if([mode isEqual:@"persona"]){[personaCaptured addObject:@{@"messages":[messages copy],@"tools":[tools copy]}];event(@{@"type":@"text",@"text":@"fixture reply"});event(@{@"type":@"done"});return;}if([mode isEqual:@"empty"]){event(@{@"type":@"done"});return;}if([mode isEqual:@"wait"])return;Check(tools.count>0,@"tools remain available beyond old count limits");
 if(requests>40){for(NSDictionary *m in messages)for(NSDictionary *c in m[@"tool_calls"]){NSUInteger matched=0;for(NSDictionary *r in messages)if([r[@"tool_call_id"] isEqual:c[@"id"]])matched++;Check(matched==1,@"each tool has exactly one result");}event(@{@"type":@"text",@"text":@"分析完成。"});event(@{@"type":@"done"});return;}
 NSUInteger count=[mode isEqual:@"batch"]?30:1;for(NSUInteger i=0;i<count;i++)event(@{@"type":@"tool_call",@"id":[NSString stringWithFormat:@"call-%lu-%lu",requests,i],@"name":@"read_file",@"arguments":@{@"path":@"Fixture.m"}});event(@{@"type":@"done"});}
@end
@implementation TFAIToolbox
+ (NSArray *)schemas{return FixtureToolSchemas?:@[@{@"name":@"read_file",@"parameters":@{}}];}
- (instancetype)initWithRoot:(NSString *)r projectID:(NSString *)p sessionID:(NSString *)s{return [super init];}
- (void)cancel{}
- (void)setBridge:(void(^)(NSString *,NSDictionary *,TFAIResult))b{}
- (void)prepare:(NSDictionary *)request completion:(TFAIResult)done{done(@{@"request":request,@"readOnly":@YES},nil);}
- (void)setApprovalContext:(NSString *)context{}
- (void)execute:(NSDictionary *)plan approved:(BOOL)approved completion:(TFAIResult)done{executions++;done(@{@"text":@"fixture"},nil);}
- (void)selectEdits:(NSArray *)a plan:(NSDictionary *)p completion:(TFAIResult)c{c(p,nil);}
- (void)undo:(TFAIResult)c{c(@{},nil);}
@end
@implementation TFAIConnections
+ (NSDictionary *)effectiveForProject:(NSString *)p{return @{@"model":@"fixture"};}
@end
@implementation TFAIWebTools
+ (BOOL)enabled{return NO;}
+ (NSArray *)schemas{return @[];}
- (void)cancel{}
@end
@implementation TFAIRuntimePolicy
- (instancetype)initWithRoot:(NSString *)r projectID:(NSString *)p sessionID:(NSString *)s{return [super init];}
- (NSTimeInterval)expiresAt{return NSDate.date.timeIntervalSince1970+1800;}
- (NSString *)preset{return @"assisted";}
- (void)revoke{}
- (NSDictionary *)decisionForPlan:(NSDictionary *)p{return @{@"decision":@"allowed",@"readOnly":@YES};}
@end
NSArray *TFAIMessageMetadata(NSArray *a,NSDictionary *b){return a;}
BOOL TFAIContainsSecret(NSString *s){return NO;}
NSSet *TFAIBinarySelectedIDs(NSDictionary *r){return [NSSet set];}
NSArray *TFAIBinarySchemas(void){return @[];}
NSDictionary *TFAIBinaryExecute(NSString *a,NSDictionary *b,NSError **e){return @{};}
NSDictionary *TFAIClassDumpExecute(NSString *a,NSProgress *b,void(^p)(double,NSString *),NSError **e){return @{};}
NSDictionary *TFAIClassDumpRead(NSString *a,NSDictionary *b,NSError **e){return @{};}
NSDictionary *TFAIReadDirectoryReference(NSDictionary *a,NSDictionary *b,NSError **e){return @{@"valid":@YES};}
NSDictionary *TFAIReadAttachmentReferences(NSDictionary *a,NSDictionary *b,NSError **e){return @{};}
#import "../App/GitPreferences.h"
@implementation TMCGitLease
+ (instancetype)tryWrite{return [self new];}
@end
static void (^backgroundExpired)(NSString *);
void TFAIBackgroundRegister(void){}
NSString *TFAIBackgroundBegin(void (^expired)(NSString *)){backgroundExpired=[expired copy];return @"lease";}
void TFAIBackgroundUpdate(NSString *token,NSDictionary *event){}
void TFAIBackgroundEnd(NSString *token,BOOL success){backgroundExpired=nil;}
NSString *TFAIBackgroundStatus(void){return @"系统持续后台任务已启用";}
// Test-only App action/control fixtures. Persona tests leave these tools uninvoked.
NSArray *TFAIActionSchemas(BOOL readOnly){return @[];}
BOOL TFAIActionValidate(NSDictionary *args,BOOL *write,NSError **error){return NO;}
void TFAIActionExecute(NSDictionary *args,NSString *root,NSString *project,NSString *session,TFAIResult completion){completion(@{},nil);}
NSDictionary *TFAIActionCatalog(BOOL readOnly){return @{};}
NSArray<NSDictionary *> *TFAIAppControlSchemas(BOOL readOnly){return @[];}
NSDictionary *TFAIAppState(void){return @{};}
BOOL TFAIValidateAppSettings(NSDictionary *changes,NSError **error){return NO;}
NSDictionary *TFAIApplyAppSettings(NSDictionary *changes,NSError **error){return @{};}
#import "../App/AI/Agent/TFAIAgentContext.h"
#import "../App/AI/Agent/TFAIMCP.h"
#import "../App/AI/Agent/TFAIReadOnlyBrowser.h"
static NSArray *FixtureCompactedMessages;
@implementation TFAIAgentContext
+ (NSArray *)skills:(NSString *)root{return FixtureSkillMetadata.length?@[@{@"id":@"skill-1"}]:@[];}
+ (NSString *)metadata:(NSString *)root{return FixtureSkillMetadata?:@"";}
+ (NSString *)memory:(NSString *)root error:(NSError **)error{return @"fixture memory";}
+ (NSString *)fingerprint:(NSString *)text{return @"fixture-hash";}
+ (NSArray *)compact:(NSArray *)messages root:(NSString *)root session:(NSString *)session error:(NSError **)error{return FixtureCompactedMessages?:messages;}
@end
@implementation TFAIMCP
+ (instancetype)shared{static id m;static dispatch_once_t once;dispatch_once(&once,^{m=[self new];});return m;}
- (NSArray *)schemas:(NSString *)session{return @[];}
@end
@implementation TFAIReadOnlyBrowser
- (void)cancel{}
@end
#import "../App/AI/Registry/TFAIToolRegistry.h"
#import "../App/AI/Registry/TFAIToolIsolation.h"
#import "../App/AI/Agent/TFAIBuildQueue.h"
NSDictionary *TFAIToolContext(NSString *root,NSString *session,NSDictionary *references,BOOL bridge,BOOL approval,BOOL readOnly){NSMutableDictionary *c=[@{@"hasProject":@(root.length>0),@"hasSession":@(session.length>0),@"hasBridge":@(bridge),@"hasApproval":@(approval),@"readOnly":@(readOnly),@"foreground":@YES,@"compilerAvailable":@YES,@"webEnabled":@NO,@"browserAvailable":@YES,@"attachmentIDs":@[],@"binaryIDs":@[],@"ipaIDs":@[],@"headerIDs":@[],@"skillIDs":@[],@"mcpNames":@[],@"remoteAvailable":@NO,@"isolationEnabled":@NO,@"targetAppIDs":@[],@"pluginLogIDs":@[]} mutableCopy];[c addEntriesFromDictionary:FixtureContextOverrides?:@{}];return c;}
NSDictionary *TFAIToolValidReferences(NSDictionary *references){return references;}
NSDictionary *TFAIToolRemoteStatus(void){return @{};}
@implementation TFAIToolIsolation
+ (instancetype)shared{static id m;static dispatch_once_t once;dispatch_once(&once,^{m=[self new];});return m;}
- (NSArray *)schemas{return FixtureIsolationSchemas?:@[];}
- (NSDictionary *)prepare:(NSDictionary *)call error:(NSError **)error{return @{@"request":call};}
- (NSDictionary *)execute:(NSDictionary *)plan approved:(BOOL)approved error:(NSError **)error{if(approved)FixtureIsolationReads++;return approved?@{@"readOnly":@YES}:nil;}
@end
@implementation TFAIBuildQueue
+ (instancetype)shared{static id m;static dispatch_once_t once;dispatch_once(&once,^{m=[self new];});return m;}
- (NSArray *)tasks{return @[];}
@end
#import "../App/AI/Core/AIRuntime.m"
@interface PatchFeedbackRuntime : TFProjectAIRuntime @end
@implementation PatchFeedbackRuntime
- (void)runCall:(NSUInteger)index {} // Isolate result serialization; never request a model.
@end
__attribute__((constructor)) static void PatchFeedbackTransportTest(void) {@autoreleasepool{
 PatchFeedbackRuntime *runtime=[PatchFeedbackRuntime new];runtime.running=YES;runtime.messages=[NSMutableArray new];runtime.toolStarts=[NSMutableDictionary new];__block NSDictionary *published=nil;
 runtime.event=^(NSDictionary *event){if([event[@"type"] isEqual:@"tool_result"])published=event;};
 NSDictionary *recovery=@{@"code":@"patch_ambiguous",@"path":@"Tweak.xm",@"match_count":@2,@"candidate_lines":@[@835,@910],@"file_changed":@NO,@"next_tool":@"read_file"};
 NSError *failure=[NSError errorWithDomain:@"Dylix.Patch" code:1 userInfo:@{NSLocalizedDescriptionKey:@"旧代码匹配两处",@"TFAIPatchRecovery":recovery}];
 [runtime recordCall:@{@"id":@"diagnostic-fixture",@"name":@"propose_patch",@"arguments":@{}} result:nil error:failure index:0];
 Check([published[@"result"][@"recovery"] isEqual:recovery],@"patch recovery survives runtime tool event for native and Remote UI");
 NSDictionary *modelResult=[NSJSONSerialization JSONObjectWithData:[runtime.messages.lastObject[@"content"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
 Check([modelResult[@"recovery"] isEqual:recovery]&&modelResult[@"error"],@"next model round receives actionable patch recovery rather than generic error");
 Check(!modelResult[@"proposal_id"]&&!runtime.calls.count,@"diagnostic serialization does not generate proposal or schedule an apply");
 runtime.running=NO;
}}
int main(){@autoreleasepool{for(NSString *m in @[@"rounds",@"batch"]){mode=m;requests=executions=0;terminal=nil;events=[NSMutableArray new];id<TFAIRuntime> r=TFAICreateRuntime(@"/tmp/fixture",@"fixture",nil);r.event=^(NSDictionary *e){[events addObject:e];if([e[@"type"] isEqual:@"done"])terminal=e;};[r activateSession:@"fixture"];[r send:@[@{@"role":@"user",@"content":@"inspect"}] session:@"fixture"];Check([terminal[@"state"] isEqual:@"completed"],@"task completes naturally");Check(requests==41&&executions==([m isEqual:@"batch"]?1200:40),@"all 40 rounds and tools executed");Check([terminal[@"messages"] lastObject]&&[[terminal[@"messages"] lastObject][@"content"] isEqual:@"分析完成。"],@"natural final answer retained");}for(NSString *end in @[@"empty",@"stop",@"background"]){mode=[end isEqual:@"empty"]?@"empty":@"wait";terminal=nil;id<TFAIRuntime> r=TFAICreateRuntime(@"/tmp/fixture",@"fixture",^(NSString *n,NSDictionary *a,TFAIResult c){});r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])terminal=e;};[r activateSession:@"fixture"];[r send:@[@{@"role":@"user",@"content":@"inspect"}] session:@"fixture"];if([end isEqual:@"stop"])[r stop];else if([end isEqual:@"background"]){[NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];Check(!terminal,@"entering background does not stop task");void (^expire)(NSString *)=[backgroundExpired copy];expire(@"系统后台执行结束");}Check([terminal[@"state"] isEqual:[end isEqual:@"stop"]?@"stopped":@"interrupted"],[@"terminal state: " stringByAppendingString:end]);Check([terminal[@"message"] length]>0,[@"terminal reason: " stringByAppendingString:end]);}NSLog(@"Runtime unlimited-loop tests passed");}return 0;}
