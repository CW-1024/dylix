#import "../App/Incoming/TFIncoming.h"
@interface UIViewController(TFShare144Testing)
- (void)importPickedAttachmentURLs:(NSArray<NSURL *> *)urls;
- (void)presentAttachmentMenu:(NSDictionary *)contexts;
- (void)documentPicker:(UIDocumentPickerViewController *)picker didPickDocumentAtURL:(NSURL *)url;
- (void)documentPicker:(UIDocumentPickerViewController *)picker didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls;
@end
UIViewController *TFAIShare144Regression(void){
 UIViewController *home=[UIViewController new];UINavigationController *nav=[[TMCNavigationController alloc]initWithRootViewController:home];
 NSMutableArray *checks=[NSMutableArray new];void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[checks addObject:@{@"pass":@(ok),@"name":name}];};
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 NSString *root=[Projects() stringByAppendingPathComponent:[@"Share144-" stringByAppendingString:NSUUID.UUID.UUIDString]];
 [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
 JSONWrite(@{@"name":@"Share144",@"sources":@[],@"sdkVersion":@"16.4",@"deploymentTarget":@"15.0"},[root stringByAppendingPathComponent:@"MobileCompiler.json"],nil);
 NSString *scope=TFAIProjectID(root);NSMutableDictionary *record=[TFAISessions create:scope title:@"Existing shared conversation"];
 record[@"projectRoot"]=root;record[@"projectName"]=@"Share144";record[@"messages"]=@[@{@"role":@"user",@"content":@"original question"},@{@"role":@"assistant",@"content":@"original answer"}];[TFAISessions save:record project:scope error:nil];
 NSNumber *activity=[TFAISessions loadSession:record[@"id"] project:scope][@"updatedAt"];
 NSDictionary *one=@{@"kind":@"text",@"path":@"First.h",@"content":@"first"};
 TFStudioReceiveAttachments(home,@[one],record);
 TFShare114Wait(^BOOL{UIViewController *v=nav.topViewController;return [v isKindOfClass:TFAIProjectWorkspace.class]&&((TFAIProjectWorkspace *)v).chat.isViewLoaded&&![[((TFAIProjectWorkspace *)v).chat valueForKey:@"loading"] boolValue];},^(BOOL ready){
 check(ready,@"external share opens existing project conversation");if(!ready)return;
 TFAIProjectWorkspace *workspace=(id)nav.topViewController;UIViewController *chat=workspace.chat;
 check([[[chat valueForKey:@"session"] objectForKey:@"id"] isEqual:record[@"id"]],@"project share keeps exact UUID");
 TFStudioReceiveAttachments(home,@[@{@"kind":@"text",@"path":@"Second.h",@"content":@"second"}],record);
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 TFAIFlushOpenSession(scope,record[@"id"]);NSDictionary *disk=[TFAISessions loadSession:record[@"id"] project:scope];
 check([TFAISessions summaries:scope].count==1,@"repeated external shares create no extra session");
 check([disk[@"messages"] count]==2&&[disk[@"pendingAttachments"] count]==2,@"repeated shares retain messages and both attachments");
 check([disk[@"updatedAt"] isEqual:activity],@"repeated share and opening do not update activity time");
 check(((TFAIProjectWorkspace *)nav.topViewController).chat==chat,@"repeated project share reuses controller");
 // Exercise the actual import delegate with a text URL; no model/network request.
 NSString *file=[NSTemporaryDirectory() stringByAppendingPathComponent:@"Share144.txt"];[@"file picker fixture" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
 UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
 [chat presentViewController:picker animated:NO completion:^{[(id)chat documentPicker:picker didPickDocumentAtURL:[NSURL fileURLWithPath:file]];}];
 TFShare114Wait(^BOOL{return [[chat valueForKey:@"attachments"] count]==3&&!chat.presentedViewController;},^(BOOL imported){
 check(imported,@"file confirmation dismisses picker and persists imported text");
 NSString *archive=[Docs() stringByAppendingPathComponent:@"Share144-large.zip"];
 [(id)chat importPickedAttachmentURLs:@[[NSURL fileURLWithPath:archive]]];
 TFShare114Wait(^BOOL{return ![[chat valueForKey:@"loading"] boolValue];},^(BOOL finished){
 NSArray *attachments=[chat valueForKey:@"attachments"];NSDictionary *last=attachments.lastObject;
 check(finished&&attachments.count==4&&[last[@"kind"] isEqual:@"directory"]&&[last[@"access"] isEqual:@"readOnly"],@"48 MB ZIP imports as persistent read-only directory without text size rejection");
 NSError *readError=nil;NSDictionary *listed=TFAIReadDirectoryReference(last,@{@"action":@"list"},&readError);
 check(listed&&!readError,@"extracted archive grant can be browsed by AI tools");
 BOOL pass=YES;for(NSDictionary *row in checks)pass&=[row[@"pass"] boolValue];JSONWrite(@{@"pass":@(pass),@"checks":checks},[Docs() stringByAppendingPathComponent:@"ai-share144.json"],nil);
 if([NSProcessInfo.processInfo.arguments containsObject:@"--manual-files144"]){[(id)chat presentAttachmentMenu:@{}];return;}
 [nav popToRootViewControllerAnimated:NO];[TFAISessions remove:record[@"id"] project:scope];[NSFileManager.defaultManager removeItemAtPath:root error:nil];
 });
 });
 });
 });
 });return nav;
}
