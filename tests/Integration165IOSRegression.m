// Simulator only. Exercise real receive UI, importer and HTTP transport.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../App/Incoming/TFIncoming.h"
#import "../App/AI/Providers/TFAIProtocol.h"
@interface DXIntegration165 : UIViewController
@property NSMutableArray *checks,*imported;
@property NSString *fixture;
@property UITextView *output;
@property TFAITransport *transport;
@property NSDictionary *saved;
@end
@implementation DXIntegration165
- (void)check:(BOOL)pass name:(NSString *)name{[self.checks addObject:@{@"pass":@(pass),@"name":name}];}
- (void)viewDidLoad{[super viewDidLoad];self.title=@"Integration165";self.output=[[UITextView alloc]initWithFrame:self.view.bounds];self.output.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;self.output.editable=NO;[self.view addSubview:self.output];self.checks=[NSMutableArray new];self.imported=[NSMutableArray new];NSMutableDictionary *saved=[NSMutableDictionary new];for(NSString *k in @[@"ImportedProject",@"ImportedSourceRelativePath"])saved[k]=[NSUserDefaults.standardUserDefaults objectForKey:k]?:NSNull.null;self.saved=saved;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self run];});}
- (void)run{
 [self check:TFIncomingImportAnchor(nil)==nil&&TFIncomingImportPresentation(nil)==nil name:@"nil source handled before association"];
 TFStudioImportReceived(nil,[NSURL fileURLWithPath:@"/fixture.m"],NO);TFStudioImportReceived(self,[NSURL URLWithString:@"https://fixture.invalid/file"],NO);[self check:objc_getAssociatedObject(self.navigationController,NSSelectorFromString(@"TF_receivedImporter"))==nil name:@"nil host and nonfile URL rejected without importer"];
 NSString *dir=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"Integration165-" stringByAppendingString:NSUUID.UUID.UUIDString]];[NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];self.fixture=[dir stringByAppendingPathComponent:@"Fixture.m"];[@"#import <Foundation/Foundation.h>\nint integration165(void){return 165;}\n" writeToFile:self.fixture atomically:YES encoding:NSUTF8StringEncoding error:nil];[self scenario:0];
}
- (void)scenario:(NSInteger)index{
 if(index>=3){[self http];return;}
 UITableViewController *receive=[[NSClassFromString(@"TFReceiveController") alloc]initWithStyle:UITableViewStyleInsetGrouped];NSString *path=index==2?[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"Integration165.zip"]:self.fixture;
 [receive setValue:@{@"kind":index==2?@"archive":@"file",@"path":path,@"name":@"Fixture",@"detail":@"integration165 fixture",@"bytes":@70} forKey:@"record"];
 void(^select)(void)=^{UIViewController *anchor=TFIncomingImportAnchor(receive),*presentation=TFIncomingImportPresentation(receive);[self check:anchor!=nil&&((index==1&&presentation==nil)||(index!=1&&presentation!=nil)) name:[NSString stringWithFormat:@"receive scenario %ld has valid anchor and presentation",(long)index]];[receive.tableView.delegate tableView:receive.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];[self awaitImported:index deadline:NSProcessInfo.processInfo.systemUptime+15];};
 if(index==1){[self.navigationController pushViewController:receive animated:NO];[receive loadViewIfNeeded];select();}else{UINavigationController *modal=[[UINavigationController alloc]initWithRootViewController:receive];[self presentViewController:modal animated:NO completion:select];}
}
- (void)awaitImported:(NSInteger)index deadline:(NSTimeInterval)deadline{
 UIViewController *top=self.navigationController.topViewController;
 if([NSStringFromClass(top.class) isEqual:@"StudioEditor"]){NSString *root=[top valueForKey:@"root"];[self.imported addObject:root];NSString *text=[NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"Fixture.m"] encoding:NSUTF8StringEncoding error:nil];[self check:[text containsString:@"integration165"] name:[NSString stringWithFormat:@"scenario %ld imports real source and opens editor",(long)index]];[self check:objc_getAssociatedObject(self.navigationController,NSSelectorFromString(@"TF_receivedImporter"))==nil name:@"successful import releases retained importer"];[self.navigationController popToViewController:self animated:NO];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self scenario:index+1];});return;}
 if(NSProcessInfo.processInfo.systemUptime>deadline){[self check:NO name:[NSString stringWithFormat:@"scenario %ld timed out",(long)index]];[self dismissViewControllerAnimated:NO completion:^{[self.navigationController popToViewController:self animated:NO];[self http];}];return;}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self awaitImported:index deadline:deadline];});
}
- (void)http{
 NSDictionary *c=@{@"id":@"integration165-http",@"name":@"fixture",@"protocol":@"chat",@"baseURL":@"http://localhost:18995/v1",@"model":@"fixture",@"allowHTTP":@YES,@"userAgent":@"DylixIntegration/165",@"toolsEnabled":@NO};
 self.transport=[TFAITransport new];[self.transport discover:c completion:^(NSDictionary *result,NSError *error){[self check:!error&&[result[@"models"] containsObject:@"DylixIntegration/165"] name:@"actual iOS HTTP discovery sends custom User-Agent through ATS"];self.transport=[TFAITransport new];__block NSMutableString *text=[NSMutableString new];[self.transport send:@[@{@"role":@"user",@"content":@"fixture"}] connection:c tools:@[] event:^(NSDictionary *event){if([event[@"type"] isEqual:@"text"])[text appendString:event[@"text"]];if([event[@"type"] isEqual:@"done"]||[event[@"type"] isEqual:@"error"]){[self check:[text containsString:@"DylixIntegration/165"] name:@"actual iOS model request uses HTTP and custom User-Agent"];[self finish];}}];}];
}
- (void)finish{for(NSString *root in self.imported)[NSFileManager.defaultManager removeItemAtPath:root error:nil];[NSFileManager.defaultManager removeItemAtPath:self.fixture.stringByDeletingLastPathComponent error:nil];for(NSString *key in self.saved){if(self.saved[key]==NSNull.null)[NSUserDefaults.standardUserDefaults removeObjectForKey:key];else[NSUserDefaults.standardUserDefaults setObject:self.saved[key] forKey:key];}NSUInteger failures=0;for(NSDictionary *r in self.checks)if(![r[@"pass"] boolValue])failures++;NSData *json=[NSJSONSerialization dataWithJSONObject:@{@"checks":self.checks,@"failures":@(failures),@"fixtureOnly":@YES} options:NSJSONWritingPrettyPrinted error:nil];[json writeToFile:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"integration165-tests.json"] atomically:YES];self.output.text=[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding];self.title=failures?@"Integration165 FAILED":@"Integration165 passed";}
@end
UIViewController *DXIntegration165Controller(void){return [DXIntegration165 new];}
