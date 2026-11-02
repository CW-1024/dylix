from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'App/Studio.m').read_text()
method=source[source.index('- (NSDictionary *)aiBuildResult {'):source.index('- (void)aiTool:')]
fixture=r'''
#import <Foundation/Foundation.h>
@interface Engine:NSObject
@property NSString *lastBuild;
@end
@implementation Engine
@end
@interface Editor:NSObject
@property Engine *engine;
- (NSArray *)diagnosticItems;
- (NSDictionary *)aiBuildResult;
@end
@implementation Editor
- (NSArray *)diagnosticItems{return @[];}
METHOD
@end
static void Check(BOOL ok,NSString *name){if(!ok){fprintf(stderr,"FAIL %s\n",name.UTF8String);exit(1);}printf("PASS %s\n",name.UTF8String);}
int main(){@autoreleasepool{
NSString *dir=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];Editor *editor=[Editor new];editor.engine=[Engine new];editor.engine.lastBuild=dir;
NSString *path=[dir stringByAppendingPathComponent:@"report.json"];
NSMutableDictionary *report=[@{@"success":@YES,@"padding":[@"x" stringByPaddingToLength:1100000 withString:@"x" startingAtIndex:0],@"sdkSettings":@{@"sdkVersion":@"26.0",@"deploymentTarget":@"15.0"}} mutableCopy];
[[NSJSONSerialization dataWithJSONObject:report options:0 error:nil] writeToFile:path atomically:YES];NSDictionary *result=[editor aiBuildResult];Check([result[@"success"] boolValue],@"large successful report stays successful");Check([result[@"sdkVersion"] isEqual:@"26.0"]&&[result[@"deploymentTarget"] isEqual:@"15.0"],@"nested SDK settings preserved");
report[@"success"]=@NO;[[NSJSONSerialization dataWithJSONObject:report options:0 error:nil] writeToFile:path atomically:YES];Check(![[editor aiBuildResult][@"success"] boolValue],@"real failure remains failure");
[@"invalid" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];Check([editor aiBuildResult][@"error"]!=nil,@"invalid report gives explicit error");
[NSFileManager.defaultManager removeItemAtPath:path error:nil];Check([editor aiBuildResult][@"error"]!=nil,@"missing report gives explicit error");
[NSFileManager.defaultManager removeItemAtPath:dir error:nil];}}
'''.replace('METHOD',method)
with tempfile.TemporaryDirectory(prefix='dylix-build-report-') as tmp:
 p=Path(tmp);(p/'test.m').write_text(fixture)
 subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-Wno-incompatible-pointer-types',str(p/'test.m'),'-framework','Foundation','-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
