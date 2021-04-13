//
//  DownloadBridge.c
//  Notification
//
//  Created by spr on 2021/3/1.
//

#include "DownloadBridge.h"
#import "DownloadTaskManager.h"
#import "ProcessHandler.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIApplication.h>
#import "CommonUtil.h"
#import <Foundation/NSNotification.h>
#import <NotificationCenter/NotificationCenter.h>
#import <UserNotifications/UserNotifications.h>
#import <UserNotifications/UNNotification.h>
@interface DownloadBridge : NSObject<ProcessHandler>
    
@end

DownloadComplete downloadCompleteDelegate = NULL;
DownloadFailure downloadFailureDelegate = NULL;
DownloadProgress downloadProgressDelegate = NULL;
DownloadDone downloadDoneDelegate = NULL;
UnzipFailure unzipFailureDelegate = NULL;
UnzipProgress unzipProgressDelegate = NULL;
UnzipComplete unzipCompleteDelegate = NULL;
UnzipDone unzipDoneDelegate = NULL;
IsNtfAuthDisable ntfAuthDisableDelegate = NULL;

@implementation DownloadBridge
   
-(void) downloadFailure:(NSString*)downloadUrl errorScope:(int) errorScope errorMsg:(NSString*) msg responseCode:(int) responseCode
{
    if(NULL != downloadFailureDelegate)
    {
        downloadFailureDelegate([downloadUrl UTF8String], errorScope,[msg UTF8String],responseCode);
    }
}

-(void) downloadProgress:(NSString*)downloadUrl progress:(int)progress
{
    if(NULL != downloadProgressDelegate)
    {
        downloadProgressDelegate([downloadUrl UTF8String],progress);
    }
}

-(void) downloadComplete:(NSString*)downloadUrl downloadedFilePath:(NSString*)downloadedFilePath
{
    if(NULL != downloadCompleteDelegate)
    {
        downloadCompleteDelegate([downloadUrl UTF8String], [downloadedFilePath UTF8String]);
    }
}

-(void) downloadDone:(NSString*)errorMsg
{
    if(NULL != downloadDoneDelegate)
    {
        downloadDoneDelegate([errorMsg UTF8String]);
    }
}

-(void) unzipFailure:(NSString*)zipFilePath errorMsg:(NSString*) errorMsg errorScope:(int) errorScope
{
    if(NULL != unzipFailureDelegate)
    {
        unzipFailureDelegate([zipFilePath UTF8String], [errorMsg UTF8String],errorScope);
    }
}

-(void) unzipProgress:(NSString*)zipFilePath progress:(int)progress
{
    if(NULL != unzipProgressDelegate)
    {
        unzipProgressDelegate([zipFilePath UTF8String], progress);
    }
}

-(void) unzipComplete:(NSString*)zipFilePath
{
    if(NULL != unzipCompleteDelegate)
    {
        unzipCompleteDelegate([zipFilePath UTF8String]);
    }
}

-(void) unzipDone
{
    if(NULL != unzipDoneDelegate)
    {
        unzipDoneDelegate();
    }
}

//-(void) unzipHandleStart:(AsyncTask*) task;

@end

static DownloadBridge *__delegate = nil;

void InitDownload(const char*downloadDirPath,const char*unzipDirPath,int totalDownloadCount)
{
    if(!__delegate)
    {
        NSString* downloadPath = [NSString stringWithUTF8String:downloadDirPath];
        NSString* unzipPath = [NSString stringWithUTF8String:unzipDirPath];
        __delegate = [[DownloadBridge alloc] init];
        [[DownloadTaskManager shareManager] SetDownloadDelegate:__delegate];
        [[DownloadTaskManager shareManager] InitDownload:downloadPath unzipDirPath:unzipPath totalDownloadCount:totalDownloadCount];
    }
}

void StartDownloadiOSImp(const char* url,const char*md5,const char* fileName,int64_t fileSize, int delayInMills,int priority)
{
    AddDownload(url,md5,fileName,fileSize,delayInMills,priority);
}

void AddDownload(const char* url,const char*md5,const char* fileName,int64_t fileSize,int delayInMills,int priority)
{
    NSString* downloadUrl = [NSString stringWithUTF8String:url];
    NSString* downloadFileMd5 = NULL;
    NSString* downloadFileName = NULL;
    if(fileName != NULL)
    {
        downloadFileName = [NSString stringWithUTF8String:fileName];
    }
    
    if(md5 != NULL)
    {
        downloadFileMd5 = [NSString stringWithUTF8String:md5];
    }
    //downloadUrl = [NSString stringWithFormat:@"%@111",downloadUrl];
    [[DownloadTaskManager shareManager] AddDownload:downloadUrl md5:downloadFileMd5 fileName:downloadFileName
                                           fileSize:fileSize delayInMills:delayInMills priority:priority];
}

void StartiOSImp()
{
    NSLog(@"StartiOSImp");
    [[DownloadTaskManager shareManager] Start];
}

void StartUnzipiOSImp(const char* downLoadedFilePath,int priority)
{
    NSLog(@"StartUnzipiOSImp");
    [[DownloadTaskManager shareManager] StartUnzip:[NSString stringWithUTF8String:downLoadedFilePath]  priority:priority];
}

void RegisterDownloadCallback(DownloadFailure func, DownloadProgress func1, DownloadComplete func2,DownloadDone func3)
{
    downloadCompleteDelegate = func2;
    downloadFailureDelegate = func;
    downloadProgressDelegate = func1;
    downloadDoneDelegate = func3;
}

void RegisterUnzipCallback(UnzipFailure func, UnzipProgress func1, UnzipComplete func2,UnzipDone func3)
{
    unzipFailureDelegate = func;
    unzipProgressDelegate = func1;
    unzipCompleteDelegate = func2;
    unzipDoneDelegate = func3;
}

void ReDownloadiOSImp(void)
{
    NSLog(@"ReDownloadiOSImp");
    [[DownloadTaskManager shareManager] RetryDownload];
}

void isNtfEnableIOSImp(IsNtfAuthDisable func)
{
    NSLog(@"isNtfEnableIOSImp%@",[NSThread currentThread]);
    ntfAuthDisableDelegate = func;
//    NSNotificationCenter* center = [NSNotificationCenter curren]
    UNUserNotificationCenter * center  = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings)
     {
        ntfAuthDisableDelegate(settings.authorizationStatus == UNAuthorizationStatusAuthorized);
    }];
}

void goToNtfSettingViewIOSImp(void)
{
    NSLog(@"goToNtfSettingViewIOSImp");
    NSString* urlStr = [UIApplicationOpenSettingsURLString stringByAppendingString:[CommonUtil getBundleID]];
    NSURL* url = [NSURL URLWithString:urlStr];
    if([[UIApplication sharedApplication]canOpenURL:url])
    {
        UIApplication *application = [UIApplication sharedApplication];
        [application openURL:url options:@{} completionHandler:nil];
    }
}


void CleariOSImp(void)
{
    [[DownloadTaskManager shareManager] CancelAllDownload];
    [[DownloadTaskManager shareManager] Clear];
}
