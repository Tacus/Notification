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
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSDictionary* dict = [mainBundle localizedInfoDictionary];
    if([dict.allKeys containsObject:@"CFBundleDisplayName"])
        return [dict objectForKey:@"CFBundleDisplayName"];
    
    dict = [mainBundle infoDictionary];
    if([dict.allKeys containsObject:@"CFBundleDisplayName"])
        return [dict objectForKey:@"CFBundleDisplayName"];
    return @"RO!";
}

+(NSString*) getDownloadTip
{
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSDictionary* dict = [mainBundle localizedInfoDictionary];
    if([dict.allKeys containsObject:@"DownloadTip"])
        return [dict objectForKey:@"DownloadTip"];
    
    dict = [mainBundle infoDictionary];
    if([dict.allKeys containsObject:@"DownloadTip"])
        return [dict objectForKey:@"DownloadTip"];
    return @"Download Complete!";
}

@end
