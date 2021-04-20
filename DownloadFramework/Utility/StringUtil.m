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
        return [NSString stringWithFormat:@"%luB/S",bytes];
//        return [bytes + @"B"];
    int exp = (int) (log(bytes) / log(unit));
    NSString* ch = [@"KMGTPE" substringWithRange:NSMakeRange(exp - 1, 1)];
    return [NSString stringWithFormat:@"%.1f %@B/S", bytes / pow(unit, exp), ch];
}

@end
