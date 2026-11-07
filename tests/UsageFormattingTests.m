#import <Foundation/Foundation.h>
#import "../App/AI/Usage/TFAIUsageFormatting.h"
int main(){@autoreleasepool{
 NSArray *cases=@[@[@0,@"0"],@[@999,@"999"],@[@1000,@"1K"],@[@1250,@"1.25K"],@[@1800,@"1.8K"],@[@12345,@"12.35K"],@[@398979,@"398.98K"],@[@999994,@"999.99K"],@[@999995,@"1M"],@[@1000000,@"1M"],@[@1250000,@"1.25M"],@[@999995000,@"1B"],@[@1000000000,@"1B"],@[@18446744073709551615ULL,@"18446744073.71B"],@[@(-1),@"未报告"],@[NSNull.null,@"未报告"],@[@YES,@"未报告"],@[@(NAN),@"未报告"],@[@(INFINITY),@"未报告"]];
 for(NSArray *pair in cases){NSString *actual=TFAITokenCountString(pair[0]);if(![actual isEqual:pair[1]]){NSLog(@"FAIL %@ expected %@ actual %@",pair[0],pair[1],actual);return 1;}}
 if(![TFAITokenCountString(nil) isEqual:@"未报告"])return 2;
 NSLog(@"PASS %lu token formatting checks",(unsigned long)cases.count+1);return 0;
}}
