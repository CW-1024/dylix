#import <Foundation/Foundation.h>
#import "../App/DebPackage.h"

int main(int argc, char **argv) { @autoreleasepool {
    if (argc != 3) return 2;
    NSString *project = @(argv[1]), *output = @(argv[2]);
    NSData *image = [NSData dataWithContentsOfFile:[project stringByAppendingPathComponent:@"Fixture.dylib"]];
    NSDictionary *config = @{@"resources": @[@{@"source": @"extra.txt", @"destination": @"Library/Application Support/Fixture.bundle/extra.txt"}]};
    for (NSString *scheme in @[@"rootful", @"rootless", @"roothide"]) {
        NSError *error = nil;
        NSData *deb = TMCDebPackageForProject(image, @"Fixture", @"com.example.fixture", scheme, project, config, &error);
        if (!deb || ![deb writeToFile:[output stringByAppendingPathComponent:[scheme stringByAppendingPathExtension:@"deb"]] options:NSDataWritingAtomic error:&error]) {
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String); return 1;
        }
        // Refuse traversal and symlinks after introducing directory records.
        for (NSDictionary *bad in @[@{@"source": @"extra.txt", @"destination": @"../escape.txt"},
                                   @{@"source": @"outside-link", @"destination": @"Library/escape.txt"},
                                   @{@"source": @"extra.txt", @"destination": @"Library"},
                                   @{@"source": @"extra.txt", @"destination": @"Library/MobileSubstrate/DynamicLibraries/Fixture.dylib/child.txt"},
                                   @{@"source": @"extra.txt", @"destination": @"/escape.txt"}]) {
            if (TMCDebPackageForProject(image, @"Fixture", @"com.example.fixture", scheme, project, @{@"resources": @[bad]}, &error)) return 3;
        }
    }
    puts("PASS package generation and existing resource guards");
    return 0;
} }
