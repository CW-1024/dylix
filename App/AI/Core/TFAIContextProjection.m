#import "TFAIContextProjection.h"
#import <CommonCrypto/CommonDigest.h>

static const NSUInteger ContextBudget = 256 * 1024;
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
 NSMutableArray *out=[NSMutableArray new];NSUInteger ordinal=0,argumentsOffloaded=0,resultsOffloaded=0,collapsed=0;NSMutableDictionary *refs=[NSMutableDictionary new];
 for(NSDictionary *m in messages){if(![m isKindOfClass:NSDictionary.class])continue;[out addObject:[WireMessage(m) mutableCopy]];if(![m[@"role"] isEqual:@"system"]){refs[@(out.count-1)]=[NSString stringWithFormat:@"message:%lu",(unsigned long)ordinal];ordinal++;}}
 NSMutableDictionary *breakdown=[NSMutableDictionary new],*names=[NSMutableDictionary new];
 for(NSDictionary *m in out)for(NSDictionary *call in m[@"tool_calls"]){NSString *name=Text(call[@"name"]);names[Text(call[@"id"])]=name;NSMutableDictionary *row=breakdown[name];if(!row){row=[@{@"calls":@0,@"argumentsJSONBytes":@0,@"resultsUTF8Bytes":@0} mutableCopy];breakdown[name]=row;}row[@"calls"]=@([row[@"calls"] unsignedIntegerValue]+1);row[@"argumentsJSONBytes"]=@([row[@"argumentsJSONBytes"] unsignedIntegerValue]+Encode(call[@"arguments"]?:@{}).length);}
 for(NSDictionary *m in out)if([m[@"role"] isEqual:@"tool"]){NSMutableDictionary *row=breakdown[names[Text(m[@"tool_call_id"])]?:@""];if(row)row[@"resultsUTF8Bytes"]=@([row[@"resultsUTF8Bytes"] unsignedIntegerValue]+[Text(m[@"content"]) lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);}
 NSUInteger before=Measure(out,schemas);BOOL canRead=NO;for(NSDictionary *schema in schemas)if([schema[@"name"] isEqual:@"read_context"])canRead=YES;
 if(!canRead){if(statistics)*statistics=@{@"beforeTextJSONBytes":@(before),@"afterTextJSONBytes":@(before),@"budgetBytes":@(ContextBudget),@"estimatedTextTokens":@((before+1)/2),@"estimateOnly":@YES,@"imageTokensIncluded":@NO,@"toolBreakdown":breakdown};if(before>ContextBudget){if(error)*error=Failure(@"当前连接未开放原文回读工具，上下文超出文本保护预算；请开启工具或新建会话。完整记录未删除。");return nil;}return out;}
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
 [out removeObjectsAtIndexes:removed];NSUInteger after=Measure(out,schemas);
 if(statistics)*statistics=@{@"beforeTextJSONBytes":@(before),@"afterTextJSONBytes":@(after),@"budgetBytes":@(ContextBudget),@"estimatedTextTokens":@((after+1)/2),@"estimateOnly":@YES,@"imageTokensIncluded":@NO,@"toolBreakdown":breakdown,@"argumentCallsOffloaded":@(argumentsOffloaded),@"resultsOffloaded":@(resultsOffloaded),@"toolBatchesCollapsed":@(collapsed)};
 if(after>ContextBudget){if(error)*error=Failure(@"上下文保护已暂停请求：保留用户要求、系统提示和最近工具轮次后仍超出 256 KiB 文本预算。请精简大段粘贴内容或新建会话；完整记录未删除。该预算不是模型官方窗口大小。");return nil;}
 return out;
}
@end
