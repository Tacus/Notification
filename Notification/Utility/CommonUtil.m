//
//  CommonUtil.m
//  Notification
//
//  Created by spr on 2021/3/5.
//
#import "CommonUtil.h"

@implementation CommonUtil

+(NSString*) getLocalAppVersion
{
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

// 获取BundleID
+(NSString*) getBundleID
{
    return [[NSBundle mainBundle] bundleIdentifier];
}

// 获取app的名字
+(NSString*) getAppName
{
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    return appName;
}

@end
