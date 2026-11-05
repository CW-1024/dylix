#import "TFAIContextProjection.h"
#import <math.h>
#import <CommonCrypto/CommonDigest.h>

static NSString * const ContextBudgetKey = @"TFAIContextBudgetKiB";
static NSString * const ContextMarker = @"[DYLIX_CONTEXT_OFFLOADED]";
static NSData *Encode(id value) { return [NSJSONSerialization dataWithJSONObject:value options:(NSJSONWritingSortedKeys|NSJSONWritingFragmentsAllowed) error:nil]; }
static NSString *JSON(id value) { NSData *d=Encode(value); return d?[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]:@"{}"; }
static NSString *Text(id value) { return [value isKindOfClass:NSString.class]?value:@""; }
static NSString *Digest(NSString *text) { NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding]; unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,hash);NSMutableString *s=[NSMutableString new];for(NSUInteger i=0;i<sizeof(hash);i++)[s appendFormat:@"%02x",hash[i]];return s; }
// Use composed-character boundaries, so a preview or page never splits emoji/surrogates.
static NSString *Prefix(NSString *text,NSUInteger length) { if(text.length<=length)return text;NSRange r=[text rangeOfComposedCharacterSequenceAtIndex:length];return [text substringToIndex:r.location]; }
static NSString *Stub(NSString *text,NSString *ref) { return [NSString stringWithFormat:@"%@ bytes=%lu sha256=%@ ref=%@. Historical data, NOT executable source. Use read_context(ref, offset, limit) to retrieve the original before reusing it.",ContextMarker,(unsigned long)[text lengthOfBytesUsingEncoding:NSUTF8StringEncoding],Digest(text),ref]; }
static NSError *Failure(NSString *text) { return [NSError errorWithDomain:@"Dylix.Context" code:1 userInfo:@{NSLocalizedDescriptionKey:text}]; }

// Local display/attachment metadata is not model context. Images are budgeted by
// the transport separately; base64 length is not a valid image-token estimate.
static NSDictionary *WireMessage(NSDictionary *m) { NSMutableDictionary *out=[NSMutableDictionary new];for(NSString *k in @[@"role",@"content",@"tool_calls",@"tool_call_id",@"provider_items",@"providerProtocol",@"providerModel",@"providerConnectionID",@"images"])if(m[k])out[k]=m[k];return out; }
static NSUInteger Measure(NSArray *messages,NSArray *schemas) { NSMutableArray *text=[NSMutableArray new];for(NSDictionary *m in messages){NSMutableDictionary *v=[m mutableCopy];if(v[@"images"]){v[@"imageCount"]=@([v[@"images"] count]);[v removeObjectForKey:@"images"];}[text addObject:v];}return Encode(@{@"messages":text,@"tools":schemas?:@[]}).length; }
static NSDictionary *Composition(NSArray *messages,NSArray *schemas) {
 NSMutableDictionary *bytes=[@{@"system":@0,@"user":@0,@"assistant":@0,@"tool":@0,@"other":@0} mutableCopy];
 NSUInteger sum=0;for(NSDictionary *m in messages){NSMutableDictionary *v=[m mutableCopy];if(v[@"images"]){v[@"imageCount"]=@([v[@"images"] count]);[v removeObjectForKey:@"images"];}NSUInteger size=Encode(v).length;NSString *role=bytes[Text(m[@"role"])]?Text(m[@"role"]):@"other";bytes[role]=@([bytes[role] unsignedIntegerValue]+size);sum+=size;}
 NSUInteger schema=Encode(schemas?:@[]).length,total=Measure(messages,schemas);bytes[@"schemas"]=@(schema);bytes[@"framing"]=@(total>=sum+schema?total-sum-schema:0);return bytes;
}

// Preserve identifiers and status fields; bound nested lists and large strings.
// This is an explicitly lossy preview, never a semantic summary or a success claim.
static id Preview(id value,NSUInteger depth) {
 if([value isKindOfClass:NSString.class])return Prefix(value,320);
 if([value isKindOfClass:NSNumber.class]||value==NSNull.null)return value;
 if(depth>3)return @"[nested data omitted; read original]";
 if([value isKindOfClass:NSArray.class]){NSMutableArray *a=[NSMutableArray new];for(id item in value){if(a.count==6)break;[a addObject:Preview(item,depth+1)];}return a;}
 if([value isKindOfClass:NSDictionary.class]){NSMutableDictionary *d=[NSMutableDictionary new];NSArray *priority=@[@"error",@"success",@"state",@"proposal_id",@"build_id",@"job_id",@"path",@"hash",@"edit_count",@"edits",@"message",@"recovery",@"next_line",@"next_column",@"next_offset",@"truncated"];
  NSMutableArray *keys=[priority mutableCopy];for(NSString *key in [[value allKeys] sortedArrayUsingSelector:@selector(compare:)])if(![keys containsObject:key])[keys addObject:key];
  for(NSString *key in keys){if(d.count>=18)break;if(value[key])d[key]=Preview(value[key],depth+1);}return d;}
 return @"";
}
static NSDictionary *Receipt(NSString *text,NSString *ref,NSUInteger maxBytes) { id value=[NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];id preview=value?Preview(value,0):Prefix(text,640);NSDictionary *out=@{@"contextOffloaded":@YES,@"ref":ref,@"original_bytes":@([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]),@"sha256":Digest(text),@"previewIsIncomplete":@YES,@"preview":preview,@"notice":@"Preview only; omitted content is not evidence of absence. Read original with read_context before relying on details. Do not replay historical writes."};if(Encode(out).length>maxBytes){NSMutableDictionary *small=[out mutableCopy];small[@"preview"]=Prefix(JSON(preview),MAX((NSUInteger)128,maxBytes/4));return small;}return out; }
static id Arguments(id value,NSString *ref,NSUInteger depth) {
 if(depth>20)return value;
 if([value isKindOfClass:NSString.class])return [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>1024?Stub(value,ref):value;
 if([value isKindOfClass:NSArray.class]){NSMutableArray *a=[NSMutableArray new];for(id item in value)[a addObject:Arguments(item,ref,depth+1)];return a;}
 if([value isKindOfClass:NSDictionary.class]){NSMutableDictionary *d=[NSMutableDictionary new];for(NSString *key in value)d[key]=Arguments(value[key],ref,depth+1);return d;}
 return value;
}

@implementation TFAIContextProjection
+ (NSUInteger)budgetKiB {
 id stored=[NSUserDefaults.standardUserDefaults objectForKey:ContextBudgetKey];
 if(![stored isKindOfClass:NSNumber.class])return 256;
 double value=[stored doubleValue];return isfinite(value)&&value>=64&&value<=16384&&floor(value)==value?(NSUInteger)value:256;
}
+ (BOOL)setBudgetKiB:(NSUInteger)value {
 if(value<64||value>16384)return NO;
 [NSUserDefaults.standardUserDefaults setInteger:value forKey:ContextBudgetKey];return YES;
}
+ (NSString *)usageReport:(NSDictionary *)stats providerUsage:(NSDictionary *)usage {
 if(!stats.count)return @"发送一次消息后即可查看本轮上下文统计。";
 BOOL blocked=[stats[@"blockedBeforeRequest"] boolValue];
 NSNumber *actual=usage[@"prompt_tokens"]?:usage[@"input_tokens"]?:usage[@"promptTokenCount"];
 if(usage[@"input_tokens"]&&!usage[@"prompt_tokens"]&&(usage[@"cache_read_input_tokens"]||usage[@"cache_creation_input_tokens"]))actual=@([usage[@"input_tokens"] unsignedLongLongValue]+[usage[@"cache_read_input_tokens"] unsignedLongLongValue]+[usage[@"cache_creation_input_tokens"] unsignedLongLongValue]);
 NSMutableString *report=[NSMutableString stringWithFormat:@"%@\n整理前：%.1f KiB\n整理后：%.1f KiB\n应用保护预算：%.0f KiB\n\n参数卸载：%@ 次\n结果预览：%@ 次\n历史工具批次折叠：%@ 次\n历史 AI 回复卸载：%@ 次",blocked?@"本次被本机保护拦截，未向模型发送":@"最近请求文本 JSON（含工具定义）",[stats[@"beforeTextJSONBytes"] doubleValue]/1024.0,[stats[@"afterTextJSONBytes"] doubleValue]/1024.0,stats[@"budgetBytes"]?[stats[@"budgetBytes"] doubleValue]/1024.0:256,stats[@"argumentCallsOffloaded"]?:@0,stats[@"resultsOffloaded"]?:@0,stats[@"toolBatchesCollapsed"]?:@0,stats[@"assistantMessagesOffloaded"]?:@0];
 NSDictionary *composition=stats[@"afterCompositionBytes"];
 if(composition.count){[report appendString:@"\n\n整理后构成（JSON 字节）："];for(NSString *key in @[@"system",@"user",@"assistant",@"tool",@"schemas",@"other",@"framing"]){if([composition[key] unsignedIntegerValue]==0)continue;[report appendFormat:@"\n%@：%.1f KiB",@{@"system":@"系统 / 人设",@"user":@"用户消息",@"assistant":@"AI 回复 / 工具参数 / 历史回执",@"tool":@"工具结果",@"schemas":@"工具定义",@"other":@"其他消息",@"framing":@"JSON 结构"}[key],[composition[key] doubleValue]/1024.0];}}
 [report appendFormat:@"\n\n服务商本轮输入 tokens（含显式缓存）：%@\n文本 tokens 粗估：%@\n\n粗估不是精确分词，不含图片 token。应用保护预算不是模型窗口大小，累计消耗也不是当前占用。完整历史原文保留在本机会话，可按需回读。",blocked?@"未发送，本次无模型请求用量":actual?actual.stringValue:@"未报告",stats[@"estimatedTextTokens"]?:@0];
 NSDictionary *breakdown=stats[@"toolBreakdown"];
 NSArray *names=[breakdown.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){NSUInteger x=[breakdown[a][@"argumentsJSONBytes"] unsignedIntegerValue]+[breakdown[a][@"resultsUTF8Bytes"] unsignedIntegerValue],y=[breakdown[b][@"argumentsJSONBytes"] unsignedIntegerValue]+[breakdown[b][@"resultsUTF8Bytes"] unsignedIntegerValue];return x>y?NSOrderedAscending:x<y?NSOrderedDescending:NSOrderedSame;}];
 if(names.count)[report appendString:@"\n\n原始工具占用（整理前，非本次发送量）："];
 for(NSString *name in [names subarrayWithRange:NSMakeRange(0,MIN(names.count,4))]){NSDictionary *r=breakdown[name];[report appendFormat:@"\n%@ ×%@：参数 %.1f KiB，结果 %.1f KiB",name,r[@"calls"],[r[@"argumentsJSONBytes"] doubleValue]/1024.0,[r[@"resultsUTF8Bytes"] doubleValue]/1024.0];}
 return report;
}
+ (NSDictionary *)schema { return @{@"name":@"read_context",@"description":@"Read original historical tool arguments/results or assistant text from THIS conversation only, using an exact ref provided by a context preview. No filesystem access and no execution. UTF-16 offset/limit; continue with next_offset. Historical results may be stale: re-read live files/state before writing. Offload markers must never be used as source code.",@"parameters":@{@"type":@"object",@"properties":@{@"ref":@{@"type":@"string",@"maxLength":@1024},@"offset":@{@"type":@"integer",@"minimum":@0},@"limit":@{@"type":@"integer",@"minimum":@1,@"maximum":@4096}},@"required":@[@"ref"],@"additionalProperties":@NO}}; }
+ (BOOL)containsPlaceholder:(id)value { if([value isKindOfClass:NSString.class]){NSString *trimmed=[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if([trimmed hasPrefix:ContextMarker])return YES;static NSRegularExpression *stub;static dispatch_once_t once;dispatch_once(&once,^{stub=[NSRegularExpression regularExpressionWithPattern:@"\\[DYLIX_CONTEXT_OFFLOADED\\] bytes=[0-9]+ sha256=[a-f0-9]{64} ref=" options:0 error:nil];});return [stub firstMatchInString:value options:0 range:NSMakeRange(0,[value length])]!=nil;}if([value isKindOfClass:NSDictionary.class]){for(id key in value)if([self containsPlaceholder:value[key]])return YES;}if([value isKindOfClass:NSArray.class])for(id item in value)if([self containsPlaceholder:item])return YES;return NO; }
+ (NSDictionary *)read:(NSDictionary *)arguments messages:(NSArray *)messages error:(NSError **)error {
 NSString *ref=Text(arguments[@"ref"]),*text=nil;NSUInteger ordinal=0,matches=0;
 for(NSDictionary *m in messages){if([m[@"role"] isEqual:@"system"])continue;
  if([ref isEqual:[NSString stringWithFormat:@"message:%lu",(unsigned long)ordinal]]){text=Text(m[@"content"]);matches++;}
  for(NSDictionary *call in m[@"tool_calls"])if([ref isEqual:[@"arguments:" stringByAppendingString:Text(call[@"id"])]]){text=JSON(call[@"arguments"]?:@{});matches++;}
  if([m[@"role"] isEqual:@"tool"]&&[ref isEqual:[@"result:" stringByAppendingString:Text(m[@"tool_call_id"])]]){text=Text(m[@"content"]);matches++;}
  ordinal++;
 }
 if(!text||matches!=1){if(error)*error=Failure(@"原文引用不属于当前会话或已不存在，请重新查询。 ");return nil;}
 NSUInteger offset=[arguments[@"offset"] unsignedIntegerValue],limit=arguments[@"limit"]?[arguments[@"limit"] unsignedIntegerValue]:4096;
 if(!limit||limit>4096||offset>text.length){if(error)*error=Failure(@"原文分页范围无效。 ");return nil;}
 NSUInteger end=MIN(text.length,offset+limit);if(offset<text.length&&[text rangeOfComposedCharacterSequenceAtIndex:offset].location!=offset){if(error)*error=Failure(@"offset 位于组合字符内，请使用返回的 next_offset。 ");return nil;}
 if(end<text.length)end=[text rangeOfComposedCharacterSequenceAtIndex:end].location;
 // A single composed cluster can exceed a page; fail rather than return a stuck cursor.
 if(end==offset&&offset<text.length){if(error)*error=Failure(@"单个组合字符超过分页上限，无法安全分页。 ");return nil;}
 return @{@"ref":ref,@"text":[text substringWithRange:NSMakeRange(offset,end-offset)],@"offset":@(offset),@"next_offset":end<text.length?@(end):NSNull.null,@"total_utf16":@(text.length),@"original_bytes":@([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]),@"sha256":Digest(text),@"historical":@YES};
}
+ (NSArray *)project:(NSArray *)messages schemas:(NSArray *)schemas statistics:(NSDictionary **)statistics error:(NSError **)error {
 NSUInteger ContextBudget=[self budgetKiB]*1024;
 NSMutableArray *out=[NSMutableArray new];NSUInteger ordinal=0,argumentsOffloaded=0,resultsOffloaded=0,collapsed=0,assistantOffloaded=0;NSMutableDictionary *refs=[NSMutableDictionary new];NSMutableIndexSet *plainAssistants=[NSMutableIndexSet new];
 for(NSDictionary *m in messages){if(![m isKindOfClass:NSDictionary.class])continue;[out addObject:[WireMessage(m) mutableCopy]];if([m[@"role"] isEqual:@"assistant"]&&![m[@"tool_calls"] count])[plainAssistants addIndex:out.count-1];if(![m[@"role"] isEqual:@"system"]){refs[@(out.count-1)]=[NSString stringWithFormat:@"message:%lu",(unsigned long)ordinal];ordinal++;}}
 NSMutableDictionary *breakdown=[NSMutableDictionary new],*names=[NSMutableDictionary new];
 for(NSDictionary *m in out)for(NSDictionary *call in m[@"tool_calls"]){NSString *name=Text(call[@"name"]);names[Text(call[@"id"])]=name;NSMutableDictionary *row=breakdown[name];if(!row){row=[@{@"calls":@0,@"argumentsJSONBytes":@0,@"resultsUTF8Bytes":@0} mutableCopy];breakdown[name]=row;}row[@"calls"]=@([row[@"calls"] unsignedIntegerValue]+1);row[@"argumentsJSONBytes"]=@([row[@"argumentsJSONBytes"] unsignedIntegerValue]+Encode(call[@"arguments"]?:@{}).length);}
 for(NSDictionary *m in out)if([m[@"role"] isEqual:@"tool"]){NSMutableDictionary *row=breakdown[names[Text(m[@"tool_call_id"])]?:@""];if(row)row[@"resultsUTF8Bytes"]=@([row[@"resultsUTF8Bytes"] unsignedIntegerValue]+[Text(m[@"content"]) lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);}
 NSUInteger before=Measure(out,schemas);BOOL canRead=NO;for(NSDictionary *schema in schemas)if([schema[@"name"] isEqual:@"read_context"])canRead=YES;
 if(!canRead){if(statistics)*statistics=@{@"beforeTextJSONBytes":@(before),@"afterTextJSONBytes":@(before),@"budgetBytes":@(ContextBudget),@"estimatedTextTokens":@((before+1)/2),@"estimateOnly":@YES,@"imageTokensIncluded":@NO,@"toolBreakdown":breakdown,@"afterCompositionBytes":Composition(out,schemas),@"blockedBeforeRequest":@(before>ContextBudget)};if(before>ContextBudget){if(error)*error=Failure(@"当前连接未开放原文回读工具，上下文超出文本保护预算；请开启工具或新建会话。完整记录未删除。");return nil;}return out;}
 NSMutableArray *groups=[NSMutableArray new];
 // Only completed, adjacent call/result batches can be rewritten. Never touch pending calls.
 for(NSUInteger i=0;i<out.count;i++){NSDictionary *m=out[i];NSArray *calls=m[@"tool_calls"];if(!calls.count)continue;NSUInteger end=i+1;NSMutableDictionary *results=[NSMutableDictionary new];while(end<out.count&&[out[end][@"role"] isEqual:@"tool"]){NSString *identifier=Text(out[end][@"tool_call_id"]);if(results[identifier])break;results[identifier]=@(end++);}
  BOOL complete=results.count==calls.count;NSMutableSet *seen=[NSMutableSet new];for(NSDictionary *call in calls){NSString *identifier=Text(call[@"id"]);if(!identifier.length||!results[identifier]||[seen containsObject:identifier])complete=NO;[seen addObject:identifier];}if(!complete)continue;
  [groups addObject:@{@"start":@(i),@"end":@(end)}];NSMutableDictionary *assistant=out[i];NSMutableArray *projected=[NSMutableArray new];BOOL changed=NO;
  for(NSDictionary *call in calls){NSMutableDictionary *c=[call mutableCopy];NSString *ref=[@"arguments:" stringByAppendingString:Text(call[@"id"])];
   if(![call[@"name"] isEqual:@"read_context"]){id args=Arguments(call[@"arguments"],ref,0);if(![args isEqual:call[@"arguments"]]){c[@"arguments"]=args;argumentsOffloaded++;changed=YES;}}[projected addObject:c];}
  assistant[@"tool_calls"]=projected;
  // Gemini native replay carries another copy of functionCall.args. Update BOTH
  // copies, keeping thought signatures and native IDs paired with the same call.
  if(changed&&[assistant[@"providerProtocol"] isEqual:@"gemini"]){NSMutableArray *items=[NSMutableArray new];NSUInteger callIndex=0;for(NSDictionary *item in assistant[@"provider_items"]){NSMutableDictionary *v=[item mutableCopy];NSMutableArray *parts=[NSMutableArray new];for(NSDictionary *part in item[@"parts"]){NSMutableDictionary *p=[part mutableCopy];if(p[@"functionCall"]&&callIndex<projected.count){NSMutableDictionary *f=[p[@"functionCall"] mutableCopy];f[@"args"]=projected[callIndex++][@"arguments"];p[@"functionCall"]=f;}[parts addObject:p];}if(item[@"parts"])v[@"parts"]=parts;[items addObject:v];}assistant[@"provider_items"]=items;}
  for(NSDictionary *call in calls){NSUInteger index=[results[call[@"id"]] unsignedIntegerValue];NSMutableDictionary *r=out[index];NSString *text=Text(r[@"content"]);if(![call[@"name"] isEqual:@"read_context"]&&[text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>16*1024){r[@"content"]=JSON(Receipt(text,[@"result:" stringByAppendingString:call[@"id"]],12*1024));resultsOffloaded++;}}
  i=end-1;
 }
 // A large single-user agent loop cannot be trimmed at user-turn boundaries.
 // Replace oldest WHOLE tool batches with explicit historical receipts, retaining
 // the last two batches and every user instruction/system message verbatim.
 NSMutableIndexSet *removed=[NSMutableIndexSet new];
 for(NSUInteger g=0;Measure(out,schemas)>ContextBudget&&g+2<groups.count;g++){NSDictionary *group=groups[g];NSUInteger start=[group[@"start"] unsignedIntegerValue],end=[group[@"end"] unsignedIntegerValue];NSDictionary *m=out[start];NSMutableArray *receipts=[NSMutableArray new];for(NSDictionary *call in m[@"tool_calls"]){NSString *identifier=Text(call[@"id"]);NSMutableDictionary *r=[@{@"call_id":identifier,@"tool":Text(call[@"name"]),@"arguments_ref":[@"arguments:" stringByAppendingString:identifier],@"result_ref":[@"result:" stringByAppendingString:identifier]} mutableCopy];for(NSUInteger j=start+1;j<end;j++)if([out[j][@"tool_call_id"] isEqual:identifier]){NSString *result=Text(out[j][@"content"]);r[@"result_preview"]=Receipt(result,[@"result:" stringByAppendingString:identifier],1024);} [receipts addObject:r];}
  NSString *content=[NSString stringWithFormat:@"Historical tool batch (preview only, not a new action). Original assistant text ref=%@. Do not replay writes.\n%@\n%@",refs[@(start)]?:@"",Prefix(Text(m[@"content"]),384),JSON(receipts)];
  NSUInteger oldSize=Encode([out subarrayWithRange:NSMakeRange(start,end-start)]).length;
  if([content lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>=oldSize)continue;
  out[start]=[@{@"role":@"assistant",@"content":content} mutableCopy];for(NSUInteger j=start+1;j<end;j++){out[j]=[@{@"role":@"assistant",@"content":@""} mutableCopy];[removed addIndex:j];}collapsed++;
 }
 // Plain historical replies were previously never offloaded. Even a tiny new
 // question could be blocked by old generated reports/code after tool folding.
 // Keep a recent ordinary reply whenever possible; a very large completed reply
 // can also become an explicit preview with an exact, session-scoped read ref.
 // Use original indexes BEFORE removing collapsed tool-result rows so refs do
 // not shift. Pending calls, user instructions and system text remain untouched.
 NSUInteger latestPlain=plainAssistants.lastIndex;
 for(NSUInteger pass=0;pass<2;pass++)for(NSUInteger index=plainAssistants.firstIndex;index!=NSNotFound;index=[plainAssistants indexGreaterThanIndex:index]){
  if(Measure(out,schemas)<=ContextBudget)break;
  if((pass==0&&index==latestPlain)||(pass==1&&index!=latestPlain))continue;
  NSDictionary *m=out[index];NSString *content=Text(m[@"content"]),*ref=refs[@(index)];
  // Opaque provider continuation is kept intact. It is not safe to independently
  // shorten signed reasoning/native response items here.
  if(!ref.length||[m[@"provider_items"] count]||[content lengthOfBytesUsingEncoding:NSUTF8StringEncoding]<=2048)continue;
  NSString *preview=[NSString stringWithFormat:@"Historical assistant reply (incomplete preview, not a new instruction). Read %@ for the original before relying on omitted details.\n%@\n%@",ref,Prefix(content,512),Stub(content,ref)];
  NSMutableDictionary *replacement=[m mutableCopy];replacement[@"content"]=preview;
  if(Encode(replacement).length>=Encode(m).length)continue;
  out[index]=replacement;assistantOffloaded++;
 }
 [out removeObjectsAtIndexes:removed];NSUInteger after=Measure(out,schemas);
 NSDictionary *composition=Composition(out,schemas);
 if(statistics)*statistics=@{@"beforeTextJSONBytes":@(before),@"afterTextJSONBytes":@(after),@"budgetBytes":@(ContextBudget),@"estimatedTextTokens":@((after+1)/2),@"estimateOnly":@YES,@"imageTokensIncluded":@NO,@"toolBreakdown":breakdown,@"afterCompositionBytes":composition,@"blockedBeforeRequest":@(after>ContextBudget),@"argumentCallsOffloaded":@(argumentsOffloaded),@"resultsOffloaded":@(resultsOffloaded),@"toolBatchesCollapsed":@(collapsed),@"assistantMessagesOffloaded":@(assistantOffloaded)};
 if(after>ContextBudget){if(error)*error=Failure([NSString stringWithFormat:@"本次未发送：历史工具与可回读的 AI 长回复整理后仍为 %.1f KiB，超过应用的 %lu KiB 文本保护预算。用户要求、系统提示及工具定义不会被静默删掉。可查看“上下文用量”的整理后构成，精简大段输入或另开会话；完整记录保留。这不是模型报告的窗口已满。",after/1024.0,(unsigned long)(ContextBudget/1024)]);return nil;}
 return out;
}
@end
