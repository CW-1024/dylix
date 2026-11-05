#import "../App/AI/Background/TFAIAudioBackground.h"
#import "../App/AI/AIContracts.h"
#import "../App/Remote/DXFlexBridge.h"
// Compiled only in the simulator; no HTTP/debug endpoints in any device build.
static UIViewController *DXRemoteRegressionController(void){
 UIViewController *controller=DXRemoteSettingsController();
 NSString *documents=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
 NSString *stateFile=[documents stringByAppendingPathComponent:@"RemoteTestState.json"],*commandFile=[documents stringByAppendingPathComponent:@"RemoteTestCommand.json"];
 [NSFileManager.defaultManager removeItemAtPath:commandFile error:nil];
 __block BOOL started=NO;[DXRemoteService.shared setPort:18787];[DXRemoteService.shared setWebDAVPort:18788];
 [NSTimer scheduledTimerWithTimeInterval:.2 repeats:YES block:^(NSTimer *timer){
  if(!started&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive){started=YES;[DXRemoteService.shared start];}
  NSMutableDictionary *state=[DXRemoteService.shared.localState mutableCopy];
  if([controller respondsToSelector:NSSelectorFromString(@"codeDetail")])state[@"codeLabel"]=[controller performSelector:NSSelectorFromString(@"codeDetail")]?:@"";
  state[@"audio"]=TFAIAudioBackgroundDiagnostics();
  state[@"screenAwake"]=@(UIApplication.sharedApplication.idleTimerDisabled);
  [[NSJSONSerialization dataWithJSONObject:state options:0 error:nil] writeToFile:stateFile atomically:YES];
  NSDictionary *command=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:commandFile]?:NSData.data options:0 error:nil];
  if(![command isKindOfClass:NSDictionary.class])return;
  [NSFileManager.defaultManager removeItemAtPath:commandFile error:nil];
  NSString *action=command[@"action"];
  if([action isEqual:@"fixture_model"]){[TFAIConnections save:@{@"id":@"remote-ui-fixture",@"name":@"本地回归服务",@"protocol":@"chat",@"baseURL":@"http://localhost:18991/v1",@"model":@"gpt-5-fixture",@"models":@[@"gpt-5-fixture",@"gpt-5-fixture-alt"],@"allowLANHTTP":@YES,@"toolsEnabled":@([command[@"tools"] boolValue])} secret:nil error:nil];}
  if([action isEqual:@"fixture_model_remove"])[TFAIConnections remove:@"remote-ui-fixture"];
  if([action isEqual:@"flex_live_fixture"]){
   NSString *device=command[@"device"],*session=command[@"session"],*output=[documents stringByAppendingPathComponent:@"RemoteFlexResult.json"];
   [NSFileManager.defaultManager removeItemAtPath:output error:nil];
   [DXFlexBridge.shared publish:@{@"report":@"fixture report",@"bundleID":@"fixture.app",@"className":@"UIView"} device:device error:nil];
   [DXFlexBridge.shared bindSession:session device:device];
   [DXFlexBridge.shared enqueueForSession:session operation:@"current" arguments:@{} completion:^(NSDictionary *result,NSError *error){
    NSDictionary *answer=error?@{@"error":error.localizedDescription}:@{@"result":result?:@{}};
    [[NSJSONSerialization dataWithJSONObject:answer options:0 error:nil] writeToFile:output atomically:YES];
   }];
  }
  if([action isEqual:@"awake"]){TFScreenAwakeSet(command[@"reason"],[command[@"active"] boolValue]);}
  if([action isEqual:@"dav_picker"])[controller performSelector:NSSelectorFromString(@"chooseDAV")];
  if([action isEqual:@"approve"])[DXRemoteService.shared approve:command[@"id"] accepted:YES];
  if([action isEqual:@"deny"])[DXRemoteService.shared approve:command[@"id"] accepted:NO];
  if([action isEqual:@"revoke"])[DXRemoteService.shared revoke:command[@"id"]];
  if([action isEqual:@"disconnect"])[DXRemoteService.shared revoke:nil];
  if([action isEqual:@"fixed"])[DXRemoteService.shared setFixedCode:command[@"code"]];
  if([action isEqual:@"dav_start"])[DXRemoteService.shared startWebDAVProject:command[@"projectID"] readOnly:[command[@"readOnly"] boolValue]];
  if([action isEqual:@"dav_stop"])[DXRemoteService.shared stopWebDAV];
  if([action isEqual:@"lock"])[NSNotificationCenter.defaultCenter postNotificationName:UIApplicationProtectedDataWillBecomeUnavailable object:nil];
  if([action isEqual:@"unlock"])[NSNotificationCenter.defaultCenter postNotificationName:UIApplicationProtectedDataDidBecomeAvailable object:nil];
  if([action isEqual:@"audio_ai"]){if([command[@"active"] boolValue])TFAIAudioBackgroundStart();else TFAIAudioBackgroundStop();}
  if([action isEqual:@"audio"])TFAIAudioBackgroundSetEnabled([command[@"enabled"] boolValue]);
  if([action isEqual:@"expire"])[DXRemoteService.shared performSelector:NSSelectorFromString(@"backgroundExpired")];
  if([action isEqual:@"foreground"])[NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
  if([action isEqual:@"rotate"])[DXRemoteService.shared rotateCode];
  if([action isEqual:@"stop"])[DXRemoteService.shared stop];
  if([action isEqual:@"start"])[DXRemoteService.shared start];
  if([action isEqual:@"background"])[NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
 }];
 return controller;
}
