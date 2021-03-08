//
//  StringUtil.m
//  Notification
//
//  Created by spr on 2021/3/2.
//


#import <math.h>
#import <Foundation/NSRange.h>
#import "StringUtil.h"

@implementation StringUtil

+(NSString*) humanReadableByteCount:(long) bytes
{
    int unit = 1024;
    if (bytes < unit)
        return [NSString stringWithFormat:@"%lu",bytes];
//        return [bytes + @"B"];
    int exp = (int) (log(bytes) / log(unit));
    NSString* ch = [@"KMGTPE" substringWithRange:NSMakeRange(exp, 1)];
    return [NSString stringWithFormat:@"%.1f %@B/s", bytes / pow(unit, exp), ch];
}

@end

@implementation NSString (Util)
+ (BOOL)isBlankString:(NSString *)str {
    NSString *string = str;
    if (string == nil || string == NULL) {
        return YES;
    }
    if ([string isKindOfClass:[NSNull class]]) {
        return YES;
    }
    if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]==0) {
        return YES;
    }
    
    return NO;
}

@end
