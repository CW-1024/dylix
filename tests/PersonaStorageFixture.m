#import <Foundation/Foundation.h>
#import "../App/AI/Persona/TFAIPersona.h"

// Storage-only fixture: no prompt composition, model matching or network calls.
int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc < 3) return 2;
        TFAIPersonaStore *store = [[TFAIPersonaStore alloc]
            initWithURL:[NSURL fileURLWithPath:@(argv[1])]
            builtinsURL:[NSURL fileURLWithPath:@(argv[2])]];
        NSDictionary *snapshot = store.snapshot;
        NSMutableDictionary *rows = [NSMutableDictionary new];
        for (TFAIPersona *persona in store.personas) rows[persona.identifier] = persona.JSON;
        NSDictionary *result = @{
            @"error": store.loadError.localizedDescription ?: @"",
            @"enabled": @(store.enabled),
            @"activeID": store.activeID ?: NSNull.null,
            @"rows": rows,
            @"schemaVersion": snapshot[@"schemaVersion"],
            @"tailEnabled": snapshot[@"tailEnabled"] ?: @NO,
            @"hiddenBuiltins": snapshot[@"hiddenBuiltins"] ?: @[]
        };
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
        fwrite(data.bytes, 1, data.length, stdout);
    }
    return 0;
}
