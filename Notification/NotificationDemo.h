//
//  NotificationDemo.h
//  Notification
//
//  Created by spr on 2021/3/1.
//

#ifndef NotificationDemo_h
#define NotificationDemo_h
#import "AppDelegate.h"
#import <Foundation/Foundation.h>

@interface NotificationDemo:NSObject


-(void)RegistNtfCenter:(UIApplication*)application;

-(void)pushNotification_IOS_10_Body:(NSString*)body;

@end

#endif /* NotificationDemo_h */
