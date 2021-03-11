//
//  CommonUtil.h
//  Notification
//
//  Created by spr on 2021/3/5.
//

#ifndef CommonUtil_h
#define CommonUtil_h
#import <Foundation/Foundation.h>
@interface CommonUtil:NSObject

+(NSString*) getLocalAppVersion;

// 获取BundleID

+(NSString*) getBundleID;

// 获取app的名字

+(NSString*) getAppName;

+(NSString*) getDownloadTip;

@end
#endif /* CommonUtil_h */
