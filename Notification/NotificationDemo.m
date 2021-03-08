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
                         promptTone:(NSString *)promptTone
                          soundName:(NSString *)soundName
                          imageName:(NSString *)imageName
                          movieName:(NSString *)movieName
                         Identifier:(NSString *)identifier {
//    //获取通知中心用来激活新建的通知
       UNUserNotificationCenter * center  = [UNUserNotificationCenter currentNotificationCenter];

       UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc]init];

       content.body = body;
       //通知的提示音
       if ([promptTone containsString:@"."]) {

           UNNotificationSound *sound = [UNNotificationSound soundNamed:promptTone];
           content.sound = sound;

       }
    
    content.sound = [UNNotificationSound defaultSound];
    content.badge = @1;
    content.userInfo = @{
        @"detail":@"detail"
    };
    content.title = @"下载完成";
//    content.subtitle = @"开始下载";


       __block UNNotificationAttachment *imageAtt;
       __block UNNotificationAttachment *movieAtt;
       __block UNNotificationAttachment *soundAtt;

       if ([imageName containsString:@"."]) {

           [self addNotificationAttachmentContent:content attachmentName:imageName options:nil withCompletion:^(NSError *error, UNNotificationAttachment *notificationAtt) {

               imageAtt = [notificationAtt copy];
           }];
       }

       if ([soundName containsString:@"."]) {


           [self addNotificationAttachmentContent:content attachmentName:soundName options:nil withCompletion:^(NSError *error, UNNotificationAttachment *notificationAtt) {

               soundAtt = [notificationAtt copy];

           }];

       }

       if ([movieName containsString:@"."]) {
           // 在这里截取视频的第10s为视频的缩略图 ：UNNotificationAttachmentOptionsThumbnailTimeKey
           [self addNotificationAttachmentContent:content attachmentName:movieName options:@{@"UNNotificationAttachmentOptionsThumbnailTimeKey":@10} withCompletion:^(NSError *error, UNNotificationAttachment *notificationAtt) {

               movieAtt = [notificationAtt copy];

           }];

       }

       NSMutableArray * array = [NSMutableArray array];
   //    [array addObject:soundAtt];
   //    [array addObject:imageAtt];
//       [array addObject:movieAtt];

       content.attachments = array;

       //添加通知下拉动作按钮
       NSMutableArray * actionMutableArray = [NSMutableArray array];
       UNNotificationAction * actionA = [UNNotificationAction actionWithIdentifier:@"identifierNeedUnlock" title:@"进入应用" options:UNNotificationActionOptionAuthenticationRequired];
       UNNotificationAction * actionB = [UNNotificationAction actionWithIdentifier:@"identifierRed" title:@"忽略" options:UNNotificationActionOptionDestructive];
       [actionMutableArray addObjectsFromArray:@[actionA,actionB]];

//       if (actionMutableArray.count > 1) {

           UNNotificationCategory * category = [UNNotificationCategory categoryWithIdentifier:@"categoryNoOperationAction" actions:actionMutableArray intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
           [center setNotificationCategories:[NSSet setWithObjects:category, nil]];
           content.categoryIdentifier = @"categoryNoOperationAction";
//       }

       //UNTimeIntervalNotificationTrigger   延时推送
       //UNCalendarNotificationTrigger       定时推送
       //UNLocationNotificationTrigger       位置变化推送

       UNTimeIntervalNotificationTrigger * tirgger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:.1f repeats:NO];

      //建立通知请求
       UNNotificationRequest * request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:tirgger];

       //将建立的通知请求添加到通知中心
       [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {

           NSLog(@"%@本地推送 :( 报错 %@",identifier,error);

       }];

//    //获取通知中心用来激活新建的通知
//   UNUserNotificationCenter * center  = [UNUserNotificationCenter currentNotificationCenter];
//
//   UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc]init];
//
//   content.body = body;
//
//
//   //UNTimeIntervalNotificationTrigger   延时推送
//   //UNCalendarNotificationTrigger       定时推送
//   //UNLocationNotificationTrigger       位置变化推送
//
//   UNTimeIntervalNotificationTrigger * tirgger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:.5f repeats:NO];
//
//  //建立通知请求
//   UNNotificationRequest * request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:tirgger];
//
//   //将建立的通知请求添加到通知中心
//   [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
//
//       NSLog(@"%@本地推送 :( 报错 %@",identifier,error);
//
//   }];

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
