#import "TFAIRegistry.h"
static NSDictionary *Catalog(NSString *name){NSString *path=[NSBundle.mainBundle pathForResource:name ofType:@"json" inDirectory:@"AIProviders"];NSString *test=NSProcessInfo.processInfo.environment[@"DYLIX_PROVIDER_RESOURCES"];if(test.length)path=[test stringByAppendingPathComponent:[name stringByAppendingString:@".json"]];id j=path?[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]?:NSData.data options:0 error:nil]:nil;return [j isKindOfClass:NSDictionary.class]&&[j[@"schemaVersion"] isEqual:@1]?j:@{};}
NSArray<NSDictionary *> *TFAIProviderRegistry(void){static NSArray *rows;static dispatch_once_t once;dispatch_once(&once,^{NSMutableArray *valid=[NSMutableArray new];NSMutableSet *ids=[NSMutableSet new];for(id row in Catalog(@"Providers")[@"providers"]){if(![row isKindOfClass:NSDictionary.class]||![row[@"id"] isKindOfClass:NSString.class]||[ids containsObject:row[@"id"]]||![@[@"chat",@"responses",@"anthropic",@"gemini"] containsObject:row[@"wireProtocol"]])continue;[valid addObject:row];[ids addObject:row[@"id"]];}rows=valid.copy;});return rows;}
NSDictionary *TFAIProvider(NSString *identifier){for(NSDictionary *p in TFAIProviderRegistry())if([p[@"id"] isEqual:identifier])return p;return @{};}
NSString *TFAIWireProtocol(NSString *identifier){return TFAIProvider(identifier)[@"wireProtocol"]?:identifier;}
NSString *TFAINormalizedModelID(NSString *model){
 if(![model isKindOfClass:NSString.class])return @"";
 NSString *name=[[model lowercaseString].lastPathComponent stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 NSRegularExpression *spaces=[NSRegularExpression regularExpressionWithPattern:@"[ _]+" options:0 error:nil];name=[spaces stringByReplacingMatchesInString:name options:0 range:NSMakeRange(0,name.length) withTemplate:@"-"];
 // Recognize explicit Sol/Astra/Terra aliases only; never rewrite the request model ID.
 NSRegularExpression *alias=[NSRegularExpression regularExpressionWithPattern:@"^(?:gpt-?)?([56](?:\\.[0-9]+)?)-?(sol|astra|terra|luna)(?=$|-)" options:0 error:nil];NSTextCheckingResult *m=[alias firstMatchInString:name options:0 range:NSMakeRange(0,name.length)];
 if(m){NSString *version=[name substringWithRange:[m rangeAtIndex:1]];if([version isEqual:@"6.0"])version=@"6";name=[NSString stringWithFormat:@"gpt-%@-%@%@",version,[name substringWithRange:[m rangeAtIndex:2]],[name substringFromIndex:NSMaxRange(m.range)]];}
 return name;
}
NSString *TFAIModelMetadataScope(NSDictionary *c){
 NSString *base=[c[@"baseURL"] isKindOfClass:NSString.class]?c[@"baseURL"]:@"";NSURLComponents *url=[NSURLComponents componentsWithString:base];url.user=nil;url.password=nil;url.query=nil;url.fragment=nil;url.host=url.host.lowercaseString;
 NSString *path=[url.path stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
 for(NSString *suffix in @[@"/chat/completions",@"/responses",@"/messages",@"/models"])if([path hasSuffix:suffix]){path=[path substringToIndex:path.length-suffix.length];break;}
 url.path=path.length?[@"/" stringByAppendingString:path]:@"";
 NSData *data=[NSJSONSerialization dataWithJSONObject:@[c[@"protocol"]?:@"chat",url.URL.absoluteString?:base] options:0 error:nil];return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]?:@"";
}
NSString *TFAICapabilityScope(NSDictionary *c){return [TFAIModelMetadataScope(c) stringByAppendingFormat:@"|%@",c[@"model"]?:@""];}
static NSDictionary *TFDict(id value){return [value isKindOfClass:NSDictionary.class]?value:@{};}
static NSArray *TFStrings(id value){if(![value isKindOfClass:NSArray.class])return @[];NSMutableArray *out=[NSMutableArray new];for(id item in value)if(out.count<32&&[item isKindOfClass:NSString.class]&&[item length]<=128&&![out containsObject:item])[out addObject:[item lowercaseString]];return out;}
NSDictionary *TFAISanitizeModelMetadata(id row){
 if(![row isKindOfClass:NSDictionary.class])return @{};NSDictionary *raw=row,*caps=TFDict(raw[@"capabilities"]);NSMutableDictionary *combined=[TFDict(caps[@"supports"]) mutableCopy];[combined addEntriesFromDictionary:caps];caps=combined;NSMutableDictionary *declared=[NSMutableDictionary new];
 NSDictionary *aliases=@{@"text":@[@"text"],@"stream":@[@"stream",@"streaming"],@"image":@[@"image",@"vision"],@"tools":@[@"tools",@"tool_calls",@"tool_calling",@"function_calling"],@"thinking":@[@"thinking",@"reasoning",@"supports_reasoning"]};
 for(NSString *key in aliases)for(NSString *alias in aliases[key]){id value=caps[alias]?:raw[alias];if([value isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID()){declared[key]=[value boolValue]?@"supported":@"unsupported";break;}if([@[@"supported",@"unsupported"] containsObject:value?:@""]){declared[key]=value;break;}}
 NSArray *inputs=TFStrings(raw[@"input_modalities"]?:TFDict(raw[@"architecture"])[@"input_modalities"]?:TFDict(raw[@"modalities"])[@"input"]);
 if(inputs.count){for(NSString *key in @[@"text",@"image"])if([inputs containsObject:key])declared[key]=@"supported";}
 NSArray *parameters=TFStrings(raw[@"supported_parameters"]);if([parameters containsObject:@"tools"]||[parameters containsObject:@"tool_choice"])declared[@"tools"]=@"supported";
 id effortRaw=raw[@"efforts"]?:raw[@"supported_reasoning_efforts"]?:raw[@"supported_reasoning_levels"]?:raw[@"reasoning_effort_values"]?:caps[@"reasoning_effort"]?:TFDict(raw[@"reasoning"])[@"levels"];NSMutableArray *effortNames=[NSMutableArray new];if([effortRaw isKindOfClass:NSArray.class])for(id value in effortRaw){id name=[value isKindOfClass:NSDictionary.class]?value[@"effort"]:value;if([name isKindOfClass:NSString.class]&&effortNames.count<32)[effortNames addObject:name];}NSArray *efforts=TFStrings(effortNames);NSMutableArray *valid=[NSMutableArray new];
 for(NSString *level in efforts)if([@[@"none",@"minimal",@"low",@"medium",@"high",@"xhigh",@"ultra",@"max",@"enabled"] containsObject:level])[valid addObject:level];
 NSString *wire=[raw[@"thinkingWire"] isKindOfClass:NSString.class]?raw[@"thinkingWire"]:[raw[@"reasoning_wire"] isKindOfClass:NSString.class]?raw[@"reasoning_wire"]:nil;
 if(!wire)for(NSString *parameter in @[@"reasoning_effort",@"enable_thinking",@"thinking",@"chat_template_kwargs"])if([parameters containsObject:parameter]){wire=parameter;break;}
 if(valid.count||wire)declared[@"thinking"]=@"supported";
 NSMutableDictionary *out=[NSMutableDictionary new];if(declared.count)out[@"capabilities"]=declared;if(valid.count)out[@"efforts"]=valid;
 if(wire&&[TFAIThinkingWires(@"chat") containsObject:wire])out[@"thinkingWire"]=wire;
 return out;
}
NSDictionary *TFAIModelMetadata(NSDictionary *c){
 if(![c[@"modelMetadataScope"] isEqual:TFAIModelMetadataScope(c)])return @{};
 NSDictionary *map=TFDict(c[@"modelMetadata"]);id row=map[c[@"model"]?:@""];
 if(!row&&[TFAIWireProtocol(c[@"protocol"]?:@"chat") isEqual:@"gemini"])row=map[[@"models/" stringByAppendingString:c[@"model"]?:@""]];
 return TFDict(row);
}
NSArray<NSString *> *TFAIThinkingWires(NSString *protocol){
 NSString *wire=TFAIWireProtocol(protocol?:@"chat");
 if([wire isEqual:@"responses"])return @[@"reasoning",@"disabled"];
 if([wire isEqual:@"anthropic"])return @[@"anthropic_budget",@"anthropic_adaptive",@"disabled"];
 if([wire isEqual:@"gemini"])return @[@"gemini_budget",@"gemini_level",@"disabled"];
 return @[@"reasoning_effort",@"reasoning",@"thinking",@"enable_thinking",@"thinking_budget",@"chat_template_kwargs",@"disabled"];
}
NSArray<NSString *> *TFAIThinkingLevelsForWire(NSString *wire){
 if([wire isEqual:@"disabled"])return @[];
 if([@[@"enable_thinking",@"chat_template_kwargs"] containsObject:wire])return @[@"none",@"enabled"];
 if([@[@"thinking_budget",@"anthropic_budget",@"gemini_budget"] containsObject:wire])return @[@"low",@"medium",@"high"];
 if([wire isEqual:@"gemini_level"])return @[@"minimal",@"low",@"medium",@"high"];
 if([wire isEqual:@"anthropic_adaptive"])return @[@"low",@"medium",@"high",@"xhigh",@"max"];
 if([wire isEqual:@"thinking"])return @[@"none",@"low",@"medium",@"high",@"xhigh",@"ultra",@"max",@"enabled"];
 return @[@"none",@"minimal",@"low",@"medium",@"high",@"xhigh",@"ultra",@"max"];
}
NSArray<NSDictionary *> *TFAIFamilyReasoningOptions(NSDictionary *c){
 static NSDictionary *catalog;static dispatch_once_t once;dispatch_once(&once,^{catalog=Catalog(@"Thinking");});NSMutableArray *result=[NSMutableArray arrayWithObject:@{@"id":@"auto",@"name":@"默认"}];NSString *protocol=c[@"protocol"]?:@"chat",*model=TFAINormalizedModelID(c[@"model"]);
 for(NSDictionary *rule in catalog[@"rules"]){if(rule[@"protocols"]&&![rule[@"protocols"] containsObject:protocol]&&![rule[@"protocols"] containsObject:TFAIWireProtocol(protocol)])continue;if([model rangeOfString:rule[@"modelPattern"] options:NSRegularExpressionSearch].location==NSNotFound)continue;if(rule[@"excludePattern"]&&[model rangeOfString:rule[@"excludePattern"] options:NSRegularExpressionSearch].location!=NSNotFound)continue;for(NSString *level in rule[@"levels"])[result addObject:@{@"id":level,@"name":catalog[@"labels"][level]?:level}];break;}
 return result;
}
NSDictionary *TFAIResolvedCapability(NSDictionary *c,NSString *key){
 NSDictionary *manual=TFDict(TFDict(c[@"capabilityOverrides"])[TFAICapabilityScope(c)]);NSString *setting=manual[key];
 if([@[@"supported",@"unsupported"] containsObject:setting?:@""])return @{@"state":setting,@"source":@"当前模型手动配置"};
 if([TFDict(c[@"capabilities"])[key] isEqual:@"supported"])return @{@"state":@"supported",@"source":@"实际响应已验证"};
 NSString *declared=TFDict(TFAIModelMetadata(c)[@"capabilities"])[key];if(declared)return @{@"state":declared,@"source":@"当前服务模型列表声明，未实测"};
 NSString *model=TFAINormalizedModelID(c[@"model"]);BOOL known=NO;
 if([key isEqual:@"image"])known=[model rangeOfString:@"^(gpt-(4o|4\\.1|5|6)|claude-(3|sonnet-4|opus-4|haiku-4|opus-5)|gemini-(2|3))" options:NSRegularExpressionSearch].location!=NSNotFound;
 if([key isEqual:@"tools"])known=[model rangeOfString:@"^(gpt-(4o|4\\.1|5|6)|o[34]|claude-|gemini-(2|3)|deepseek-|qwen3|glm-4|kimi-k2)" options:NSRegularExpressionSearch].location!=NSNotFound;
 if(known)return @{@"state":@"supported",@"source":@"模型族建议，当前服务尚未实测"};
 return @{@"state":@"unknown",@"source":@"尚未证实；历史失败不作为禁用依据"};
}
BOOL TFAIToolsAllowed(NSDictionary *c){return (!c[@"toolsEnabled"]||[c[@"toolsEnabled"] boolValue])&&![TFAIResolvedCapability(c,@"tools")[@"state"] isEqual:@"unsupported"];}
NSDictionary *TFAIObservedCapabilities(NSDictionary *c){NSMutableDictionary *out=[NSMutableDictionary new];for(NSString *k in @[@"text",@"stream",@"image",@"tools",@"thinking"]){NSString *s=c[@"capabilities"][k];out[k]=[s isEqual:@"supported"]?s:@"unknown";}return out;}
NSString *TFAIConnectionCaption(NSDictionary *c){NSDictionary *caps=TFAIObservedCapabilities(c);NSMutableArray *verified=[NSMutableArray new];for(NSString *k in @[@"text",@"stream",@"image",@"tools"]){NSString *state=caps[k];if(![state isEqual:@"unknown"])[verified addObject:[NSString stringWithFormat:@"%@%@",@{@"text":@"文本",@"stream":@"流式",@"image":@"图片",@"tools":@"工具"}[k],[state isEqual:@"supported"]?@"✓":@"×"]];}return [NSString stringWithFormat:@"%@ · %@ · %@",TFAIProvider(c[@"protocol"])[@"name"]?:c[@"name"]?:@"未选服务商",c[@"model"]?:@"未选模型",verified.count?[[@"实测：" stringByAppendingString:[verified componentsJoinedByString:@"/"]] stringByAppendingString:@" · 其余unknown"]:@"能力 unknown"];}
