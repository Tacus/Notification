//
//  NSObject+NotificationDemo.m
//  Notification
//
//  Created by spr on 2021/3/1.
//

#import "NotificationDemo.h"
#import <UserNotifications/UNUserNotificationCenter.h>
#import <UserNotifications/UNNotificationContent.h>
#import <UserNotifications/UNNotificationSound.h>
#import <UserNotifications/UNNotificationAttachment.h>
#import <UserNotifications/UNNotificationAction.h>
#import <UserNotifications/UNNotificationCategory.h>
#import <UserNotifications/UNNotificationRequest.h>
#import <UserNotifications/UNNotificationTrigger.h>



@implementation NotificationDemo

-(void) RegistNtfCenter
{
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    
//    [center requestAuthorizationWithOptions:(UNAuthorizationOptions) completionHandler:NtfAuthoriza];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound +UNAuthorizationOptionBadge)
                              completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                  // Enable or disable features based on authorization.

        if(NULL == error)
        {
            NSLog(@"注册通知成功");
        }
        else
        {
            NSLog(@"注册通知失败，errormsg:%@",error.domain);
        }
   
    }];
    
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                    
        
                }];
//    center.delegate = self;

}

-(void)pushNotification_IOS_10_Body:(NSString *)body
{
    //获取通知中心用来激活新建的通知
    UNUserNotificationCenter * center  = [UNUserNotificationCenter currentNotificationCenter];

    UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc]init];

    content.body = body;
    content.sound = [UNNotificationSound defaultSound];
    content.title = @"仙境传说";

    UNTimeIntervalNotificationTrigger * tirgger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:.5f repeats:NO];

    //建立通知请求
    NSString*identifier = @"com.xd.ro";
    UNNotificationRequest * request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:tirgger];

    //将建立的通知请求添加到通知中心
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {

        NSLog(@"%@本地推送 :( 报错 %@",identifier,error);

    }];
}

-(void)addNotificationAttachmentContent:(UNMutableNotificationContent *)content attachmentName:(NSString *)attachmentName  options:(NSDictionary *)options withCompletion:(void(^)(NSError * error , UNNotificationAttachment * notificationAtt))completion{
    
    
    NSArray * arr = [attachmentName componentsSeparatedByString:@"."];
       
       NSError * error;
       
       NSString * path = [[NSBundle mainBundle]pathForResource:arr[0] ofType:arr[1]];
       
       UNNotificationAttachment * attachment = [UNNotificationAttachment attachmentWithIdentifier:[NSString stringWithFormat:@"notificationAtt_%@",arr[1]] URL:[NSURL fileURLWithPath:path] options:options error:&error];
       
       if (error) {
           
           NSLog(@"attachment error %@", error);
           
       }
       
       completion(error,attachment);
       //获取通知下拉放大图片

}

@end
