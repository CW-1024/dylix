#import <Foundation/Foundation.h>
#import "../App/AI/Transport/TFAIStreamActivity.h"
static NSUInteger checks;
static void Check(BOOL ok,NSString *label){checks++;if(!ok){NSLog(@"FAIL %@",label);exit(1);}}
int main(){@autoreleasepool{
 TFAIStreamActivity *activity=[[TFAIStreamActivity alloc]initAt:100];
 NSDictionary *s=[activity statusAt:100];Check([s[@"waiting"] boolValue]&&![s[@"hasPacket"] boolValue],@"new request waits for actual bytes");
 s=[activity statusAt:116];Check([s[@"message"] containsString:@"16 秒无新数据"],@"silent initial response has measured wait");
 [activity packetAt:117 bytes:0];Check(![[activity statusAt:117][@"hasPacket"] boolValue],@"zero bytes never count as liveness");
 [activity packetAt:118 bytes:5];s=[activity statusAt:118];Check([s[@"hasPacket"] boolValue]&&![s[@"hasContent"] boolValue]&&[s[@"waiting"] boolValue],@"heartbeat or partial JSON is not claimed as model content");
 [activity contentAt:119 phase:@"reasoning"];s=[activity statusAt:120];Check(![s[@"waiting"] boolValue]&&[s[@"message"] containsString:@"思考内容"],@"reasoning phase reflects actual content");
 s=[activity statusAt:135];Check([s[@"waiting"] boolValue]&&[s[@"message"] containsString:@"无新数据"],@"stalled reasoning is no longer displayed as active generation");
 [activity packetAt:136 bytes:10];s=[activity statusAt:136];Check([s[@"waiting"] boolValue]&&[s[@"message"] containsString:@"连接有数据"]&&[s[@"contentIdleSeconds"] integerValue]==17,@"heartbeat renews packet time but not model content time");
 [activity contentAt:137 phase:@"reasoning"];Check(![[activity statusAt:138][@"waiting"] boolValue],@"resumed semantic content clears waiting state");
 [activity packetAt:139 bytes:20];[activity contentAt:139 phase:@"replying"];s=[activity statusAt:140];Check([s[@"message"] containsString:@"回复"]&&[s[@"phase"] isEqual:@"replying"],@"reasoning-to-text phase switches correctly");
 [activity contentAt:141 phase:@"tool_request"];Check([[activity statusAt:141][@"phase"] isEqual:@"tool_request"],@"tool request is a separate phase");
 [activity contentAt:142 phase:@"usage"];Check([[activity statusAt:142][@"phase"] isEqual:@"tool_request"],@"usage metadata cannot keep content falsely active");
 s=[activity statusAt:90];Check([s[@"packetIdleSeconds"] doubleValue]>=0&&[s[@"elapsedSeconds"] doubleValue]>=0,@"defensive clock bounds never produce negative wait");
 activity=[[TFAIStreamActivity alloc]initAt:200];s=[activity statusAt:201];Check(![s[@"hasPacket"] boolValue]&&![s[@"hasContent"] boolValue]&&[s[@"elapsedSeconds"] integerValue]==1,@"new tool round never inherits old stream timestamps");
 NSLog(@"PASS %lu stream activity checks",(unsigned long)checks);
}return 0;}
