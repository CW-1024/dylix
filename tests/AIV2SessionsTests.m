#import "../App/AI/AIV2Contracts.h"
static int checks=0,failures=0;
static void Check(BOOL pass,NSString *name){checks++;if(!pass)failures++;printf("%s %s\n",pass?"PASS":"FAIL",name.UTF8String);}
int main(){@autoreleasepool{
 NSString *scope=[@"v2-fixture-" stringByAppendingString:NSUUID.UUID.UUIDString];NSString *root=[[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"TweakForgeAI/Sessions"] stringByAppendingPathComponent:scope];NSFileManager *fm=NSFileManager.defaultManager;
 NSMutableDictionary *a=[TFAISessions create:scope title:@"Alpha"],*b=[TFAISessions create:scope title:@"Beta"];
 Check([TFAISessions summaries:scope].count==2,@"two explicit sessions");
 a[@"messages"]=@[@{@"role":@"user",@"content":@"Explain message dispatch"},@{@"role":@"assistant",@"content":@"A lightweight searchable answer"}];a[@"draftText"]=@"unfinished";a[@"pendingAttachments"]=@[@{@"id":@"fixture",@"kind":@"reference",@"path":@"Other Project/Main.m"}];a[@"scrollOffset"]=@144;a[@"folds"]=@{@"tool-one":@YES};a[@"mode"]=@"ask";a[@"state"]=@"waitingApproval";a[@"grants"]=@[@"write"];[TFAISessions save:a project:scope error:nil];
 TFAISetSessionLiveRun(scope,a[@"id"],YES);
 Check([[TFAISessions loadSession:a[@"id"] project:scope][@"state"] isEqual:@"waitingApproval"],@"live run is not restored as interrupted");
 BOOL liveSummary=NO;for(NSDictionary *row in [TFAISessions summaries:scope])if([row[@"id"] isEqual:a[@"id"]])liveSummary=[row[@"state"] isEqual:@"waitingApproval"];Check(liveSummary,@"list retains live state");
 Check(!TFAISessionHasLiveRun(@"other-project",a[@"id"]),@"live run isolated by project");
 TFAISetSessionLiveRun(scope,a[@"id"],NO);
 NSDictionary *loaded=[TFAISessions loadSession:a[@"id"] project:scope];Check([loaded[@"schemaVersion"] isEqual:@2],@"schema version two");Check([loaded[@"draftText"] isEqual:@"unfinished"]&&[loaded[@"pendingAttachments"] count]==1,@"draft and staged attachment survive");Check([loaded[@"scrollOffset"] isEqual:@144]&&[loaded[@"folds"][@"tool-one"] boolValue],@"scroll and folding persisted");Check([loaded[@"state"] isEqual:@"interrupted"]&&!loaded[@"grants"],@"interruption restores no grants");
 NSDictionary *summary=[TFAISessions summaries:scope].firstObject;Check(!summary[@"messages"]&&!summary[@"pendingAttachments"],@"index excludes transcript and attachment bodies");Check([summary[@"summary"] containsString:@"searchable answer"],@"summary uses latest readable message");Check([summary[@"storageProjectID"] isEqual:scope],@"scope identity explicit");
 NSNumber *activity=loaded[@"updatedAt"];
 NSMutableDictionary *opened=[loaded mutableCopy];opened[@"scrollY"]=@999;opened[@"draft"]=@"draft only";
 NSMutableArray *normalized=[NSMutableArray new];for(NSDictionary *raw in opened[@"messages"]){NSMutableDictionary *m=[raw mutableCopy];m[@"messageID"]=NSUUID.UUID.UUIDString;m[@"timestamp"]=@123;[normalized addObject:m];}opened[@"messages"]=normalized;
 [TFAISessions save:opened project:scope error:nil];
 Check([[TFAISessions loadSession:a[@"id"] project:scope][@"updatedAt"] isEqual:activity],@"opening and UI message normalization preserve activity time");
 [TFAISessions saveMetadata:@{@"pendingAttachments":@[@{@"kind":@"text",@"content":@"external share",@"path":@"Header.h"}],@"draft":@"shared draft"} identifier:a[@"id"] project:scope error:nil];
 Check([[TFAISessions loadSession:a[@"id"] project:scope][@"updatedAt"] isEqual:activity],@"external attachment draft does not reorder conversation");
 NSError *scopeError=nil;Check(![TFAISessions save:opened project:@"general" error:&scopeError]&&scopeError,@"existing UUID cannot silently duplicate into another scope");
 Check(![TFAISessions loadSession:a[@"id"] project:@"general"],@"scope mismatch leaves no duplicate payload");
 b[@"messages"]=@[@{@"role":@"user",@"content":@"latest real activity"}];[TFAISessions save:b project:scope error:nil];
 Check([[[TFAISessions summaries:scope].firstObject objectForKey:@"id"] isEqual:b[@"id"]],@"real sent message sorts first");
 [TFAISessions saveMetadata:@{@"scrollOffset":@80} identifier:a[@"id"] project:scope error:nil];
 Check([[[TFAISessions summaries:scope].firstObject objectForKey:@"id"] isEqual:b[@"id"]],@"opening older conversation leaves latest conversation first");
 NSError *error=nil;Check([TFAISessions saveMetadata:@{@"pinned":@YES,@"title":@"Pinned Alpha",@"projectName":@"Project A",@"associatedProjectID":@"project-a"} identifier:a[@"id"] project:scope error:&error],@"pin rename association metadata saved");
 b[@"messages"]=@[@{@"role":@"user",@"content":@"newer"}];[TFAISessions save:b project:scope error:nil];Check([[[TFAISessions summaries:scope].firstObject objectForKey:@"id"] isEqual:a[@"id"]],@"pin sorts ahead of later session");
 a[@"messages"]=@[@{@"role":@"user",@"content":@"stale live chat"}];[TFAISessions save:a project:scope error:nil];loaded=[TFAISessions loadSession:a[@"id"] project:scope];Check([loaded[@"title"] isEqual:@"Pinned Alpha"]&&[loaded[@"pinned"] boolValue],@"stale chat save preserves explicit rename pin");Check([loaded[@"projectName"] isEqual:@"Project A"],@"stale save preserves project association");
 error=nil;Check(![TFAISessions saveMetadata:@{@"grants":@[@"write"]} identifier:a[@"id"] project:scope error:&error]&&error,@"metadata cannot create grants");
 NSString *index=[[root stringByAppendingPathComponent:@"index"] stringByAppendingPathComponent:[b[@"id"] stringByAppendingPathExtension:@"json"]];[fm removeItemAtPath:index error:nil];Check([TFAISessions summaries:scope].count==2&&[fm fileExistsAtPath:index],@"missing index self-repairs from payload");
 NSString *payload=[root stringByAppendingPathComponent:[b[@"id"] stringByAppendingPathExtension:@"json"]];NSDictionary *legacy=@{@"id":b[@"id"],@"schemaVersion":@1,@"title":@"Legacy",@"messages":@[],@"updatedAt":@1};[[NSJSONSerialization dataWithJSONObject:legacy options:0 error:nil] writeToFile:payload atomically:YES];loaded=[TFAISessions loadSession:b[@"id"] project:scope];Check([loaded[@"schemaVersion"] isEqual:@2]&&[loaded[@"title"] isEqual:@"Legacy"],@"version one migration without losing identity");
 NSArray *all=[TFAISessions summaries:nil];BOOL found=NO;for(NSDictionary *item in all)if([item[@"storageProjectID"] isEqual:scope])found=YES;Check(found,@"global list discovers project scopes");
 [TFAISessions remove:a[@"id"] project:scope];Check(![TFAISessions loadSession:a[@"id"] project:scope],@"delete removes payload");error=nil;Check(![TFAISessions save:a project:scope error:&error]&&error,@"late queued save cannot resurrect deleted session");Check([TFAISessions summaries:scope].count==1,@"deleted absent from index");
 Check(![TFAISessions loadSession:@"../bad" project:scope]&&[TFAISessions summaries:@"../bad"].count==0,@"invalid IDs and scopes rejected");
 NSMutableDictionary *recover=[TFAISessions create:scope title:@"Interrupted fixture"];recover[@"state"]=@"running";recover[@"messages"]=@[@{@"role":@"assistant",@"content":@"pending",@"tool_calls":@[@{@"id":@"pending-call",@"type":@"function",@"function":@{@"name":@"read_file",@"arguments":@"{}"}}]}];[TFAISessions save:recover project:scope error:nil];
 NSMutableDictionary *reopened=[TFAISessions loadSession:recover[@"id"] project:scope];NSNumber *beforeRecovery=reopened[@"updatedAt"];[TFAISessions save:reopened project:scope error:nil];
 Check([[TFAISessions loadSession:recover[@"id"] project:scope][@"updatedAt"] isEqual:beforeRecovery],@"opening interrupted task with repaired tool history preserves activity");[TFAISessions remove:recover[@"id"] project:scope];
 NSString *generalID=NSUUID.UUID.UUIDString;NSMutableDictionary *general=[@{@"id":generalID,@"title":@"Independent",@"messages":@[]} mutableCopy];Check([TFAISessions save:general project:@"general" error:nil],@"ordinary session needs no project");Check([[TFAISessions loadSession:generalID project:@"general"][@"storageProjectID"] isEqual:@"general"],@"ordinary session isolated scope");[TFAISessions remove:generalID project:@"general"];
 [fm removeItemAtPath:root error:nil];printf("%d checks, %d failures\n",checks,failures);return failures?1:0;
}}
