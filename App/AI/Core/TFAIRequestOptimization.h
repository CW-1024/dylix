#pragma once
#import <Foundation/Foundation.h>

// Opt-in: existing conversations keep full tools until the user enables discovery.
static inline BOOL TFAILazyToolsEnabled(void) { return [NSUserDefaults.standardUserDefaults boolForKey:@"Dylix.AI.LazyTools"]; }
static inline NSString *TFAIAnswerStyle(void) {
 NSString *v=[NSUserDefaults.standardUserDefaults stringForKey:@"Dylix.AI.AnswerStyle"];
 return [@[@"concise",@"standard",@"detailed"] containsObject:v]?v:@"standard";
}
static inline NSString *TFAIAnswerGuidance(void) {
 NSString *style=TFAIAnswerStyle();
 NSString *length=[style isEqual:@"concise"]?@"简洁回答，先给结论，只保留必要依据和下一步。":([style isEqual:@"detailed"]?@"按需详细解释实现、依据和限制。":@"回答长度与任务复杂度匹配，先给结果，避免重复叙述。");
 return [length stringByAppendingString:@"执行中只播报有新信息的进展，不逐条复述工具参数或重复宣布即将操作；结果已经明确就交付。完整保留用户需要的代码、验证证据与重要限制，不为简短省略必要工作。用户明确指定的回答格式和详细程度优先。"];
}
static inline NSDictionary *TFAIToolSearchSchema(NSArray *available) {
 NSMutableArray *names=[NSMutableArray new];for(NSDictionary *s in available)[names addObject:s[@"name"]];
 return @{@"name":@"search_tools",@"description":[@"Discover and load tools for the NEXT request. Use names for exact loading (up to 12), query for keyword lookup in names/descriptions, or empty arguments to list the catalog. Loading never grants permissions. Keep working in this conversation. Available names: " stringByAppendingString:[names componentsJoinedByString:@", "]],@"parameters":@{@"type":@"object",@"properties":@{@"query":@{@"type":@"string",@"maxLength":@256},@"names":@{@"type":@"array",@"items":@{@"type":@"string"},@"maxItems":@12}},@"additionalProperties":@NO}};
}
static inline NSArray *TFAISelectRequestTools(NSArray *available, NSSet *loaded) {
 NSSet *base=[NSSet setWithArray:@[@"read_context",@"read_development_guide",@"read_app_state",@"read_file",@"list_files",@"read_attachment",@"agent_skill_read",@"list_projects",@"select_project"]];
 NSMutableArray *out=[NSMutableArray arrayWithObject:TFAIToolSearchSchema(available)];
 for(NSDictionary *s in available)if([base containsObject:s[@"name"]]||([loaded containsObject:s[@"name"]]||([s[@"name"] isEqual:@"binary_inspect"]&&[loaded containsObject:@"binary_obfuscation_scan"])))[out addObject:s];return out;
}
static inline NSDictionary *TFAILoadTools(NSDictionary *args,NSArray *available,NSMutableSet *loaded,NSError **error) {
 if(![args isKindOfClass:NSDictionary.class]){if(error)*error=[NSError errorWithDomain:@"Dylix.ToolDiscovery" code:1 userInfo:@{NSLocalizedDescriptionKey:@"工具查询参数必须为对象。"}];return nil;}
 id query=args[@"query"],names=args[@"names"];
 BOOL valid=[args isKindOfClass:NSDictionary.class]&&args.count<=2&&(!query||([query isKindOfClass:NSString.class]&&[query length]<=256))&&(!names||([names isKindOfClass:NSArray.class]&&[names count]<=12));
 for(id key in args)if(![@[@"query",@"names"] containsObject:key])valid=NO;
 for(id n in ([names isKindOfClass:NSArray.class]?names:@[]))if(![n isKindOfClass:NSString.class])valid=NO;
 if(!valid){if(error)*error=[NSError errorWithDomain:@"Dylix.ToolDiscovery" code:1 userInfo:@{NSLocalizedDescriptionKey:@"使用 query 或最多 12 个 names 查询工具。"}];return nil;}
 NSMutableArray *catalog=[NSMutableArray new],*selected=[NSMutableArray new],*missing=[NSMutableArray new];NSMutableSet *found=[NSMutableSet new];
 BOOL listing=![query length]&&![names count];
 for(NSDictionary *s in available){NSString *name=s[@"name"],*desc=s[@"description"]?:@"";BOOL exact=[names containsObject:name];BOOL match=[query length]&&([[name stringByAppendingFormat:@" %@",desc] rangeOfString:query options:NSCaseInsensitiveSearch].location!=NSNotFound);
 if(listing||exact||match){[catalog addObject:@{@"name":name,@"description":desc.length>180?[desc substringToIndex:180]:desc}];if((exact||match)&&selected.count<12){[selected addObject:name];[loaded addObject:name];}[found addObject:name];}}
 for(NSString *n in names)if(![found containsObject:n])[missing addObject:n];
 return @{@"catalog":catalog,@"loaded":selected,@"unavailable":missing,@"effective":@"next_request",@"permissionsUnchanged":@YES};
}
