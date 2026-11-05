#import "../App/AI/Persona/TFAIPersona.h"
static NSUInteger checks;
static void Check(BOOL ok,NSString *label){if(!ok){NSLog(@"FAIL %@",label);exit(1);}checks++;NSLog(@"PASS %@",label);}
static NSDictionary *Connection(NSString *model,NSString *protocol){return @{ @"model":model, @"protocol":protocol?:@"chat" };}
static NSDictionary *FindKey(TFAIPersonaStore *store,NSString *key){for(NSDictionary *row in store.snapshot[@"personas"])if([row[@"builtinKey"] isEqual:key])return row;return nil;}
int main(int argc,const char **argv){@autoreleasepool{
 NSURL *url=[NSURL fileURLWithPath:@(argv[1])],*catalog=[NSURL fileURLWithPath:@(argv[2])];NSString *phase=argc>3?@(argv[3]):@"core";TFAIPersonaStore *store=[[TFAIPersonaStore alloc]initWithURL:url builtinsURL:catalog];NSError *e=nil;NSUInteger expectedCount=[[[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:catalog] options:0 error:nil] objectForKey:@"personas"] count];
 if([phase isEqual:@"relaunch"]){Check(store.enabled&&store.builtins.count==expectedCount&&[store.snapshot[@"tailEnabled"] boolValue],@"fresh process restores options and the current public builtins");Check([store.snapshot[@"matchingMode"] isEqual:@"manual"]&&[store.activeID isEqual:store.builtins.lastObject.identifier],@"fresh process restores manual selected builtin");return 0;}
 Check(!store.loadError&&!store.enabled&&!store.activeID&&store.personas.count==expectedCount&&store.builtins.count==expectedCount,@"fresh store seeds exactly the current public builtins without enabling or selecting");
 Check([store.snapshot[@"matchingMode"] isEqual:@"auto"]&&![store.snapshot[@"tailEnabled"] boolValue],@"fresh store defaults to automatic matching and tail off");
 for(TFAIPersona *p in store.builtins)Check(p.isBuiltin&&[p.mode isEqual:@"prepend"]&&[p.generation isEqual:@"2026-11"]&&p.builtinKey.length&&p.modelPatterns.count&&p.matchPriority>0&&!p.replyPrefix.length&&p.selfCheckCommand.length,@"current builtin metadata is complete");

 NSArray *fixtures=@[
  @[@"openai/gpt-6.1-sol",@"responses",@"builtin.current.openai"],
  @[@"openai/gpt-5.6-sol",@"chat",@"builtin.current.openai.gpt56"],
  @[@"openai/gpt-6-astra",@"responses",@"builtin.current.openai.astra"],
  @[@"anthropic/claude-4.7-opus",@"chat",@"builtin.current.claude.opus"],
  @[@"claude-4.7-sonnet",@"anthropic",@"builtin.current.claude.sonnet"],
  @[@"google/gemini-4-pro",@"chat",@"builtin.current.gemini"],
  @[@"google/gemini-3.1-pro",@"chat",@"builtin.current.gemini31"],
  @[@"deepseek/deepseek-v4",@"deepseek",@"builtin.current.deepseek4"],
  @[@"deepseek/deepseek-v4.1",@"deepseek",@"builtin.current.deepseek"],
  @[@"qwen/qwen-3.7-coder",@"qwen",@"builtin.current.qwen37"],
  @[@"qwen/qwen-3.8-coder",@"qwen",@"builtin.current.qwen"],
  @[@"zhipu/glm-zcode-5.2",@"siliconflow",@"builtin.current.glm52"],
  @[@"zhipu/glm-zcode-5.3",@"siliconflow",@"builtin.current.glm"],
  @[@"moonshot/kimi-k3.1",@"kimi",@"builtin.current.kimi"],
  @[@"x-ai/grok-4.7",@"xai",@"builtin.current.grok"],
  @[@"mistralai/mistral-large-4",@"openrouter",@"builtin.current.mistral"],
  @[@"openai/gpt-oss-20b",@"chat",@"builtin.current.gptoss20b"]
 ];
 for(NSArray *fixture in fixtures){if(!FindKey(store,fixture[2]))continue;NSDictionary *recommended=[TFAIPersonaEngine recommended:store.snapshot connection:Connection(fixture[0],fixture[1])];Check([recommended[@"builtinKey"] isEqual:fixture[2]],[NSString stringWithFormat:@"model fixture matches %@",fixture[2]]);}
 Check(![TFAIPersonaEngine recommended:store.snapshot connection:Connection(@"vendor/new-model-2027",@"chat")],@"public unknown model does not select unlicensed fallback");

 NSString *base=@"fixture developer";[store setEnabled:YES error:&e];NSDictionary *openAI=Connection(@"openai/gpt-6.1-sol",@"responses"),*openAIRow=FindKey(store,@"builtin.current.openai");NSString *automatic=[TFAIPersonaEngine build:base snapshot:store.snapshot connection:openAI];Check([automatic containsString:openAIRow[@"body"]]&&[automatic hasSuffix:base],@"automatic mode injects model-matched current profile");
 TFAIPersona *manual=store.builtins.lastObject;[store activateOnly:manual.identifier error:&e];Check([[TFAIPersonaEngine effective:store.snapshot connection:openAI][@"builtinKey"] isEqual:@"builtin.current.openai"],@"automatic mode overrides stale manual selection");[store setMatchingMode:@"manual" error:&e];Check([[TFAIPersonaEngine effective:store.snapshot connection:openAI][@"id"] isEqual:manual.identifier],@"manual mode preserves explicit selection");

 for(TFAIPersona *p in store.builtins){[store activateOnly:p.identifier error:&e];NSString *system=[TFAIPersonaEngine build:base snapshot:store.snapshot];Check([system hasPrefix:TFAIPersonaBeginMarker]&&[system hasSuffix:base]&&[system containsString:p.body],@"each current builtin injects its body in manual mode");Check([[TFAIPersonaEngine selfCheckResponse:@[@{@"role":@"user",@"content":p.selfCheckCommand}] snapshot:store.snapshot] isEqual:p.selfCheckReply],@"each current builtin local self-check matches exactly");}
 TFAIPersona *p=store.builtins.lastObject;[store setTailEnabled:YES error:&e];NSString *system=[TFAIPersonaEngine build:base snapshot:store.snapshot];for(NSUInteger i=0;i<3;i++)system=[TFAIPersonaEngine build:system snapshot:store.snapshot];Check([system componentsSeparatedByString:TFAIPersonaBeginMarker].count==2&&![system containsString:@"<!-- dylix-persona-tail:begin -->"],@"recomposition keeps one exact upstream persona without an added tail");Check([[TFAIPersonaEngine strip:system] isEqual:base],@"strip restores the original developer prompt");
 [store saveName:p.name body:@"edited current body" mode:@"append" identifier:p.identifier error:&e];[store resetBuiltin:p.identifier error:&e];Check([store.builtins.lastObject.mode isEqual:@"prepend"]&&[store.builtins.lastObject.body isEqual:p.body],@"reset restores current builtin metadata and body");
 [store remove:p.identifier error:&e];TFAIPersonaStore *reloaded=[[TFAIPersonaStore alloc]initWithURL:url builtinsURL:catalog];Check(reloaded.builtins.count==expectedCount-1,@"deleted current builtin stays deleted after restart");[reloaded restoreBuiltins:&e];Check(reloaded.builtins.count==expectedCount,@"restore adds only missing current builtins");

 NSURL *legacyURL=[[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"legacy.json"];NSString *custom=NSUUID.UUID.UUIDString;NSDictionary *legacy=@{@"schemaVersion":@1,@"enabled":@YES,@"activeID":custom,@"personas":@[@{@"id":custom,@"name":@"Legacy",@"body":@"fixture legacy body",@"mode":@"append",@"isBuiltin":@NO,@"updatedAt":@42}]};[[NSJSONSerialization dataWithJSONObject:legacy options:0 error:nil] writeToURL:legacyURL atomically:YES];TFAIPersonaStore *migrated=[[TFAIPersonaStore alloc]initWithURL:legacyURL builtinsURL:catalog];Check(migrated.personas.count==expectedCount+1&&migrated.builtins.count==expectedCount&&[migrated.activeID isEqual:custom]&&[migrated.snapshot[@"matchingMode"] isEqual:@"manual"],@"schema-1 active selection migrates to manual mode with current catalog");

 NSURL *upgradeURL=[[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"catalog-upgrade.json"];NSDictionary *catalogUntouched=FindKey(store,@"builtin.current.openai.astra"),*catalogEdited=FindKey(store,@"builtin.current.openai");NSMutableDictionary *oldUntouched=[catalogUntouched mutableCopy],*oldEdited=[catalogEdited mutableCopy];oldUntouched[@"body"]=@"stale bundled body";oldUntouched[@"generation"]=@"old";oldEdited[@"body"]=@"user edited body";oldEdited[@"updatedAt"]=@42;NSDictionary *upgrade=@{@"schemaVersion":@2,@"catalogVersion":@2,@"enabled":@YES,@"activeID":oldUntouched[@"id"],@"hiddenBuiltins":@[],@"tailEnabled":@NO,@"matchingMode":@"manual",@"personas":@[oldUntouched,oldEdited]};[[NSJSONSerialization dataWithJSONObject:upgrade options:0 error:nil] writeToURL:upgradeURL atomically:YES];TFAIPersonaStore *upgraded=[[TFAIPersonaStore alloc]initWithURL:upgradeURL builtinsURL:catalog];NSDictionary *refreshed=FindKey(upgraded,@"builtin.current.openai.astra"),*preserved=FindKey(upgraded,@"builtin.current.openai");Check([refreshed[@"body"] isEqual:catalogUntouched[@"body"]]&&[upgraded.activeID isEqual:oldUntouched[@"id"]],@"catalog upgrade refreshes untouched builtin and preserves selection");Check([preserved[@"body"] isEqual:@"user edited body"],@"catalog upgrade preserves user-edited builtin body");

 NSURL *retiredURL=[[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"retired.json"];NSString *untouched=NSUUID.UUID.UUIDString,*edited=NSUUID.UUID.UUIDString;NSDictionary *retired=@{@"schemaVersion":@2,@"enabled":@YES,@"activeID":untouched,@"hiddenBuiltins":@[],@"tailEnabled":@NO,@"personas":@[
  @{@"id":untouched,@"name":@"Old untouched",@"body":@"old",@"mode":@"prepend",@"isBuiltin":@YES,@"updatedAt":@0,@"builtinKey":@"builtin.general"},
  @{@"id":edited,@"name":@"Old edited",@"body":@"user changed old body",@"mode":@"append",@"isBuiltin":@YES,@"updatedAt":@42,@"builtinKey":@"builtin.reversing"}
 ]};[[NSJSONSerialization dataWithJSONObject:retired options:0 error:nil] writeToURL:retiredURL atomically:YES];TFAIPersonaStore *retiredStore=[[TFAIPersonaStore alloc]initWithURL:retiredURL builtinsURL:catalog];BOOL hasUntouched=NO,hasEdited=NO;for(TFAIPersona *item in retiredStore.personas){if([item.identifier isEqual:untouched])hasUntouched=YES;if([item.identifier isEqual:edited]&&[item.body isEqual:@"user changed old body"])hasEdited=YES;}Check(hasUntouched&&[retiredStore.activeID isEqual:untouched],@"catalog migration preserves existing legacy records and selection");Check(hasEdited,@"user-edited legacy builtin survives catalog migration");

 [store restoreBuiltins:&e];[store setMatchingMode:@"manual" error:&e];[store activateOnly:store.builtins.lastObject.identifier error:&e];NSLog(@"TOTAL %lu builtin checks passed",(unsigned long)checks);
}return 0;}
