#import <Foundation/Foundation.h>
#import "../App/DylibSignature.h"
#import "../App/PackageLinking.h"
static NSUInteger checks;
static void Check(BOOL passed, NSString *label) { checks++; if(!passed){NSLog(@"FAIL %@",label);exit(1);} }
int main(int argc,char **argv) { @autoreleasepool {
    if(argc!=3)return 2;
    NSData *valid=[NSData dataWithContentsOfFile:@(argv[1])], *unsignedImage=[NSData dataWithContentsOfFile:@(argv[2])];
    NSError *error=nil;
    Check(TMCValidateDylibSignature(valid,&error),error.localizedDescription?:@"valid");
    Check(!TMCValidateDylibSignature(unsignedImage,nil),@"unsigned rejected");
    Check(!TMCValidateDylibSignature(nil,nil),@"missing file rejected");
    for(NSUInteger n=0;n<MIN(valid.length,128);n++)Check(!TMCValidateDylibSignature([valid subdataWithRange:NSMakeRange(0,n)],nil),@"truncated header");
    struct mach_header_64 h;[valid getBytes:&h length:sizeof(h)];NSUInteger at=sizeof(h),command=0;struct linkedit_data_command sig={0};
    for(uint32_t i=0;i<h.ncmds;i++){struct load_command c;memcpy(&c,(const char*)valid.bytes+at,sizeof(c));if(c.cmd==LC_CODE_SIGNATURE){command=at;memcpy(&sig,(const char*)valid.bytes+at,sizeof(sig));}at+=c.cmdsize;}
    Check(command>0,@"fixture signature command");
    uint32_t cd=sig.dataoff+TMCSigBE32((const uint8_t*)valid.bytes+sig.dataoff+16);
    uint32_t hash=cd+TMCSigBE32((const uint8_t*)valid.bytes+cd+16);
    NSArray *badOffsets=@[@0,@(sig.dataoff-1),@(sig.dataoff),@(sig.dataoff+4),@(sig.dataoff+8),@(sig.dataoff+16),@(cd),@(cd+4),@(cd+15),@(cd+16),@(cd+28),@(cd+32),@(cd+36),@(cd+37),@(cd+39),@(hash)];
    for(NSNumber *n in badOffsets){NSMutableData *bad=[valid mutableCopy];((uint8_t*)bad.mutableBytes)[n.unsignedIntegerValue]^=0xff;Check(!TMCValidateDylibSignature(bad,nil),[NSString stringWithFormat:@"tamper %@",n]);}
    NSMutableData *bad=[valid mutableCopy];struct linkedit_data_command *lc=(void*)((uint8_t*)bad.mutableBytes+command);lc->dataoff=UINT32_MAX;Check(!TMCValidateDylibSignature(bad,nil),@"out of bounds offset");
    bad=[valid mutableCopy];lc=(void*)((uint8_t*)bad.mutableBytes+command);lc->datasize=UINT32_MAX;Check(!TMCValidateDylibSignature(bad,nil),@"out of bounds size");
    for(NSString *scheme in @[@"rootless",@"rootful",@"roothide"]){
        NSArray *args=TMCPackageLinkArguments(@[@"ld64.lld",@"-no_adhoc_codesign"],scheme,@"/frameworks",@"Fixture");
        Check([args containsObject:@"-adhoc_codesign"]&&![args containsObject:@"-no_adhoc_codesign"],scheme);
        Check([TMCPackageLinkArguments(args,scheme,@"/frameworks",@"Fixture") isEqual:args],@"idempotent");
    }
    printf("PASS %lu dylib signature and scheme checks\n",(unsigned long)checks);
    return 0;
} }
