//
//  StringUtil.h
//  Notification
//
//  Created by spr on 2021/3/2.
//

#ifndef StringUtil_h
#define StringUtil_h

#define IsBlankString(str) [NSString isBlankString:str]
#import <Foundation/Foundation.h>

@interface NSString (Util)
- (BOOL)isBlankString:(NSString *)str;
@end

@interface StringUtil:NSObject

+(NSString*) humanReadableByteCount:(long) bytes;

@end

#endif /* StringUtil_h */
