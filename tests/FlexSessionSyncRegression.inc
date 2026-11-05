#import "../App/AI/Actions/TFAISessionResources.h"
#import "../App/AI/UI/TFAISessionFiles.h"
// Real Studio -> native chat -> session files navigation; no model/network needed.
UIViewController *TMCFlexSessionSyncRegression(void){
 NSString *root=[Docs() stringByAppendingPathComponent:[@"FlexSyncFixture-" stringByAppendingString:NSUUID.UUID.UUIDString]];
 [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
 [@"enum, no\nint fixture;\n" writeToFile:[root stringByAppendingPathComponent:@"Tweak.xm"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
 JSONWrite(@{@"name":@"FLEX session sync fixture",@"sources":@[@"Tweak.xm"],@"package":@NO},[root stringByAppendingPathComponent:@"MobileCompiler.json"],nil);
 StudioEditor *editor=[StudioEditor new];editor.root=root;UINavigationController *nav=[[TMCNavigationController alloc]initWithRootViewController:editor];
 NSMutableArray *checks=[NSMutableArray new];void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[checks addObject:@{@"passed":@(ok),@"name":name}];};
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,1*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  [editor loadViewIfNeeded];editor.editor.selectedRange=NSMakeRange(0,MIN(8,editor.editor.text.length));NSString *scope=TFAIProjectID(root);NSMutableDictionary *session=[TFAISessions create:scope title:@"Sync fixture"];
  [editor openAIRecord:session];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,1*NSEC_PER_SEC),dispatch_get_main_queue(),^{
   TFAIProjectWorkspace *workspace=(id)nav.topViewController;UIViewController *chat=[workspace isKindOfClass:TFAIProjectWorkspace.class]?workspace.chat:nil;
   check(chat!=nil&&[[chat valueForKey:@"attachments"] count]==0,@"opening project chat with a saved 8-byte selection does not auto-attach it");
   NSDictionary *context=[editor aiAttachmentContext:@"selection"];check([context[@"available"] boolValue]&&[context[@"text"] isEqual:@"enum, no"],@"explicit selection attachment reads the exact current selection");
   UIViewController *menu=TFAIAttachmentMenu([editor aiAttachmentContext:@"availability"],^(NSString *key){});[menu loadViewIfNeeded];check(TFHasAttachmentSource(menu.view,@"selection"),@"selection is offered only through the explicit attachment menu");
   NSMutableDictionary *snapshot=[[chat valueForKey:@"session"] mutableCopy];UIViewController *files=TFAISessionFilesController(snapshot,root);[nav pushViewController:files animated:NO];
   NSString *buildID=[@"Build-" stringByAppendingString:NSUUID.UUID.UUIDString],*build=[Docs() stringByAppendingPathComponent:buildID];[NSFileManager.defaultManager createDirectoryAtPath:build withIntermediateDirectories:YES attributes:nil error:nil];[@"fixture artifact" writeToFile:[build stringByAppendingPathComponent:@"Fixture.dylib"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
   NSMutableDictionary *remote=[snapshot mutableCopy];TFAIRecordSessionToolEvent(remote,@{@"type":@"tool_started",@"name":@"build_project",@"id":@"fixture-build",@"arguments":@{}});TFAIRecordSessionToolEvent(remote,@{@"type":@"tool_result",@"name":@"build_project",@"id":@"fixture-build",@"result":@{@"success":@YES,@"buildID":buildID,@"artifacts":@[@{@"name":@"Fixture.dylib"}]}});
   remote[@"remoteRevision"]=@1;remote[@"state"]=@"streaming";TFAISetSessionLiveRun(scope,session[@"id"],YES);[TFAISessions save:remote project:scope error:nil];
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
    BOOL found=NO;for(NSDictionary *item in [files valueForKey:@"items"])if([item[@"name"] isEqual:@"Fixture.dylib"])found=YES;
    check(found,@"already-open session files receives the artifact before remote AI finishes");
    check([[[chat valueForKey:@"session"] objectForKey:@"remoteRevision"] integerValue]==1&&[[chat valueForKey:@"processRecords"] count]==1,@"idle native chat receives remote tool records without reopening");
    [files setValue:snapshot forKey:@"session"];[files performSelector:NSSelectorFromString(@"refresh")];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,.5*NSEC_PER_SEC),dispatch_get_main_queue(),^{
     BOOL refreshed=NO;for(NSDictionary *item in [files valueForKey:@"items"])if([item[@"name"] isEqual:@"Fixture.dylib"])refreshed=YES;check(refreshed,@"manual refresh loads latest persisted remote session instead of captured snapshot");
     check([[chat valueForKey:@"attachments"] count]==0,@"remote tool synchronization does not create input attachments");
     TFAISetSessionLiveRun(scope,session[@"id"],NO);NSUInteger failures=0;for(NSDictionary *c in checks)if(![c[@"passed"] boolValue])failures++;
     JSONWrite(@{@"checks":checks,@"failures":@(failures)},[Docs() stringByAppendingPathComponent:@"FlexSessionSyncResults.json"],nil);
     [TFAISessions remove:session[@"id"] project:scope];[NSFileManager.defaultManager removeItemAtPath:build error:nil];
    });
   });
  });
 });return nav;
}
