#undef main
#define main LegacyBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
@interface Replay251 : TFProjectAIRuntime
@end
@implementation Replay251
- (void)runCall:(NSUInteger)index{}
@end
static TFProjectAIRuntime *Runtime251(void){TFProjectAIRuntime *r=(id)TFAICreateRuntime(@"/tmp/fixture",@"fixture",nil);[r activateSession:@"fixture"];return r;}
static BOOL Contains251(NSArray *messages,NSString *text){for(NSDictionary *m in messages)if([m[@"content"] containsString:text])return YES;return NO;}
int BudgetFixtureMain(){@autoreleasepool{
 mode=@"wait";events=[NSMutableArray new];
 // Actual runtime: queue while receiving, don't execute old planned writes.
 __block TFAIEvent stream;__block NSArray *second;__block NSUInteger count=0;
 FixtureTransport=^(NSArray *m,NSArray *schemas,TFAIEvent e){count++;if(count==1)stream=e;else{second=m;e(@{@"type":@"text",@"text":@"按修正要求完成"});e(@{@"type":@"done"});}};
 TFProjectAIRuntime *r=Runtime251();__block NSDictionary *end;__block NSDictionary *checkpoint;
 r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;if([e[@"type"] isEqual:@"checkpoint"])checkpoint=e[@"checkpoint"];};
 [r send:@[@{@"role":@"user",@"content":@"original"}] session:@"fixture"];
 Check([r enqueueUserMessage:@{@"role":@"user",@"content":@"修正：只读取，不要修改"}],@"running stream accepts correction");
 Check(Contains251(checkpoint[@"messages"],@"修正：只读取"),@"queued correction is checkpointed before model finishes");NSError *gate=nil;Check(![r preflightCall:@{} error:&gate]&&gate!=nil,@"correction revokes pending old-plan execution before approval completes");
 stream(@{@"type":@"text",@"text":@"旧计划"});stream(@{@"type":@"tool_call",@"id":@"old-call",@"name":@"read_file",@"arguments":@{@"path":@"Fixture.m"}});stream(@{@"type":@"done"});
 Check([end[@"state"] isEqual:@"completed"]&&count==2,@"correction starts exactly one next request");
 Check(Contains251(second,@"修正：只读取")&&Contains251(second,@"notExecuted"),@"next request contains correction and skipped old plan result");
 Check(r.queuedUsers.count==0,@"queue drains once");
 // Late supplement after text-only response cannot be stranded.
 count=0;end=nil;second=nil;r=Runtime251();r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;};[r send:@[@{@"role":@"user",@"content":@"original"}] session:@"fixture"];[r enqueueUserMessage:@{@"role":@"user",@"content":@"还有一点"}];stream(@{@"type":@"text",@"text":@"first answer"});stream(@{@"type":@"done"});Check(count==2&&Contains251(second,@"还有一点"),@"text-only completion drains pending user before finishing");
 // Stop retains queue but never starts another request.
 FixtureTransport=^(NSArray *m,NSArray *s,TFAIEvent e){stream=e;};r=Runtime251();end=nil;r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;};[r send:@[@{@"role":@"user",@"content":@"original"}] session:@"fixture"];[r enqueueUserMessage:@{@"role":@"user",@"content":@"retain me"}];[r stop];Check([end[@"state"] isEqual:@"stopped"]&&Contains251(end[@"messages"],@"retain me")&&![end[@"backgroundResumable"] boolValue],@"explicit stop preserves supplement and disables automatic recovery");
 stream(@{@"type":@"text",@"text":@"stale callback"});Check(!Contains251(end[@"messages"],@"stale callback"),@"stale stream ignored after stop");
 // Expiration retains partial reply and identifies recoverable system interruption.
 r=Runtime251();end=nil;r.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;};[r send:@[@{@"role":@"user",@"content":@"original"}] session:@"fixture"];stream(@{@"type":@"text",@"text":@"partial reply"});void(^expired)(NSString *)=[backgroundExpired copy];expired(@"system expiration");Check([end[@"backgroundResumable"] boolValue]&&Contains251(end[@"messages"],@"partial reply"),@"background expiration preserves partial and offers continuation");
 // Exact duplicate and alternating A/B/C receipts both trigger bounded no-progress pause.
 for(NSNumber *alternating in @[@NO,@YES]){Replay251 *p=[Replay251 new];p.running=YES;p.messages=[NSMutableArray new];p.observations=[NSMutableDictionary new];p.observationOrder=[NSMutableArray new];p.progressEvidence=[NSMutableArray new];p.activeToolRecords=[NSMutableDictionary new];p.queuedUsers=[NSMutableArray new];p.toolStarts=[NSMutableDictionary new];__block BOOL warned=NO;end=nil;p.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"status"]&&[e[@"message"] containsString:@"重复检查"])warned=YES;if([e[@"type"] isEqual:@"done"])end=e;};
 for(NSUInteger i=0;i<25&&p.running;i++){NSDictionary *c=@{@"id":[NSString stringWithFormat:@"c%lu",i],@"name":@"sandbox_files",@"arguments":@{@"path":[NSString stringWithFormat:@"/workspace/%lu",alternating.boolValue?i%3:0],@"operation":@"read"}};[p recordCall:c result:@{@"content":@"unchanged",@"duration":@(i)} error:nil index:0];}
 Check(warned&&[end[@"state"] isEqual:@"paused"],alternating.boolValue?@"alternating repeated reads warn then pause":@"same reads with changing duration warn then pause");}
 // Novel output and live polling remain usable beyond the guard thresholds.
 Replay251 *p=[Replay251 new];p.running=YES;p.messages=[NSMutableArray new];p.observations=[NSMutableDictionary new];p.observationOrder=[NSMutableArray new];p.progressEvidence=[NSMutableArray new];p.toolStarts=[NSMutableDictionary new];p.activeToolRecords=[NSMutableDictionary new];
 for(NSUInteger i=0;i<45;i++){NSDictionary *c=@{@"id":[NSString stringWithFormat:@"n%lu",i],@"name":@"read_file",@"arguments":@{@"path":@"changing"}};[p recordCall:c result:@{@"text":@(i)} error:nil index:0];}Check(p.running&&p.stagnantCalls==0,@"45 changing observations do not impose a round cap");
 for(NSUInteger i=0;i<45;i++){NSDictionary *c=@{@"id":[NSString stringWithFormat:@"p%lu",i],@"name":@"sandbox_process_read",@"arguments":@{@"process_id":@"p"}};[p recordCall:c result:@{@"running":@YES} error:nil index:0];}Check(p.running,@"unchanged live process polling is exempt");
 // Resume seeds artifact handles without replaying export.
 __block NSArray *sent;FixtureTransport=^(NSArray *m,NSArray *s,TFAIEvent e){sent=m;e(@{@"type":@"text",@"text":@"交付"});e(@{@"type":@"done"});};r=Runtime251();[r send:@[@{@"role":@"user",@"content":@"task"},@{@"role":@"assistant",@"content":@"",@"tool_calls":@[@{@"id":@"exported",@"name":@"sandbox_export_file",@"arguments":@{@"path":@"/workspace/result.zip"}}]},@{@"role":@"tool",@"tool_call_id":@"exported",@"content":@"{\"export_id\":\"kept-artifact\",\"bytes\":123}"},@{@"role":@"user",@"content":@"继续"}] session:@"fixture"];
 Check(Contains251(sent,@"kept-artifact")&&r.progressEvidence.count==1,@"resume preserves protected artifact handle from original result");
 NSString *replayPath=NSProcessInfo.processInfo.environment[@"DYLIX_LOOP_REPLAY_SESSION"];
 if(replayPath.length){NSDictionary *session=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:replayPath] options:0 error:nil];NSArray *history=session[@"messages"];Check(history.count>500,@"real exported session loaded for replay");Replay251 *p=[Replay251 new];p.running=YES;p.messages=[NSMutableArray new];p.observations=[NSMutableDictionary new];p.observationOrder=[NSMutableArray new];p.progressEvidence=[NSMutableArray new];p.toolStarts=[NSMutableDictionary new];p.activeToolRecords=[NSMutableDictionary new];p.queuedUsers=[NSMutableArray new];end=nil;p.event=^(NSDictionary *e){if([e[@"type"] isEqual:@"done"])end=e;};NSMutableDictionary *calls=[NSMutableDictionary new];for(NSUInteger i=429;i<554&&p.running;i++){NSDictionary *m=history[i];for(NSDictionary *c in m[@"tool_calls"])calls[c[@"id"]]=c;if([m[@"role"] isEqual:@"tool"]){NSDictionary *c=calls[m[@"tool_call_id"]];id v=[NSJSONSerialization JSONObjectWithData:[m[@"content"] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];if(c&&[v isKindOfClass:NSDictionary.class])[p recordCall:c result:v error:nil index:0];}}Check([end[@"state"] isEqual:@"paused"],@"real exported repeated-read segment pauses before original user intervention");}
 FixtureTransport=nil;NSLog(@"PASS RunContinuity251 runtime scenarios");}return 0;}
