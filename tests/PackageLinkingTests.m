#import <Foundation/Foundation.h>
#import "../App/PackageLinking.h"

int main(int argc, char **argv) { @autoreleasepool {
    if (argc != 3) return 2;
    NSArray *base = @[@"ld64.lld", @"-install_name", @"@rpath/Fixture.dylib", @"-rpath", @"/var/jb/Library/Frameworks", @"-F", @"/tmp/frameworks", @"-o", @"out.dylib"];
    NSArray *native = TMCPackageLinkArguments(base, @"roothide", @"/tmp/frameworks", @"Fixture");
    NSArray *normal = TMCPackageLinkArguments(native, @"rootless", @"/tmp/frameworks", @"Fixture");
    if (![normal isEqual:base] || ![native containsObject:@"-adhoc_codesign"]) return 3;
    if (![TMCPackageLinkArguments(native, @"roothide", @"/tmp/frameworks", @"Fixture") isEqual:native]) return 4;
    NSData *signedImage = [NSData dataWithContentsOfFile:@(argv[1])];
    NSError *error = nil;
    if (!TMCNativeRootHideImage(signedImage, &error)) { NSLog(@"%@", error); return 5; }
    NSData *old = [NSData dataWithContentsOfFile:@(argv[2])];
    if (!old.length) return 10;
    if (TMCNativeRootHideImage(old, &error)) return 6;
    for (NSUInteger length = 0; length < MIN(signedImage.length, (NSUInteger)128); length++) {
        if (TMCNativeRootHideImage([signedImage subdataWithRange:NSMakeRange(0, length)], &error)) return 7;
    }
    NSMutableData *bad = [signedImage mutableCopy];
    NSRange range = [bad rangeOfData:[@"@loader_path/.jbroot/usr/lib/libsubstrate.dylib" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0, bad.length)];
    if (range.location == NSNotFound) return 8;
    NSMutableData *path = [[@"/var/jb/usr/lib/libsubstrate.dylib" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    [path increaseLengthBy:range.length - path.length];
    [bad replaceBytesInRange:range withBytes:path.bytes length:path.length];
    if (TMCNativeRootHideImage(bad, &error)) return 9;
    puts("PASS native linkage idempotence, scheme isolation, valid output and invalid/truncated/legacy-path rejection");
    return 0;
} }
