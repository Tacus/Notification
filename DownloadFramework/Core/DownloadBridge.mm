//
//  DownloadBridge.c
//  Notification
//
//  Created by spr on 2021/3/1.
//

#include "DownloadBridge.h"
#import "DownloadTaskManager.h"
#import "ProcessHandler.h"

@interface DownloadBridge : NSObject<ProcessHandler>
    
@end

DownloadComplete downloadCompleteDelegate = NULL;
DownloadFailure downloadFailureDelegate = NULL;
DownloadProgress downloadProgressDelegate = NULL;
UnzipFailure unzipFailureDelegate = NULL;
UnzipProgress unzipProgressDelegate = NULL;
UnzipComplete unzipCompleteDelegate = NULL;

@implementation DownloadBridge
   
-(void) downloadFailure:(int) errorScope errorMsg:(NSString*) msg responseCode:(int) responseCode
{
    if(NULL != downloadFailureDelegate)
    {
        downloadFailureDelegate(errorScope,[msg UTF8String],responseCode);
    }
}

-(void) downloadProgress:(int)progress
{
    if(NULL != downloadProgressDelegate)
    {
        downloadProgressDelegate(progress);
    }
}

-(void) downloadComplete:(NSString*)downloadedFilePath
{
    if(NULL != downloadCompleteDelegate)
    {
        downloadCompleteDelegate([downloadedFilePath UTF8String]);
    }
}

-(void) unzipFailure:(NSString*) msg responseCode:(int) responseCode
{
    if(NULL != unzipFailureDelegate)
    {
        unzipFailureDelegate([msg UTF8String],responseCode);
    }
}

-(void) unzipProgress:(int)progress
{
    if(NULL != unzipProgressDelegate)
    {
        unzipProgressDelegate(progress);
    }
}

-(void) unzipComplete
{
    if(NULL != unzipCompleteDelegate)
    {
        unzipCompleteDelegate();
    }
}

//-(void) unzipHandleStart:(AsyncTask*) task;

@end

static DownloadBridge *__delegate = nil;

void InitDownload(const char*downloadDirPath,const char*unzipDirPath,int totalDownloadCount)
{
    NSString* downloadPath = [NSString stringWithUTF8String:downloadDirPath];
    NSString* unzipPath = [NSString stringWithUTF8String:unzipDirPath];
    [[DownloadTaskManager shareManager] InitDownload:downloadPath unzipDirPath:unzipPath totalDownloadCount:totalDownloadCount];
    if(!__delegate)
    {
        __delegate = [[DownloadBridge alloc] init];
    }
    
    [[DownloadTaskManager shareManager] SetDownloadDelegate:__delegate];
}

void StartDownloadiOSImp(const char* url,const char*md5,const char* fileName,int currentIndex,int delayInMills)
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

    [[DownloadTaskManager shareManager] StartDownload:downloadUrl md5:downloadFileMd5 fileName:downloadFileName
                                         currentIndex:currentIndex delayInMills:delayInMills];

}

void StartUnzipiOSImp(const char* downLoadedFilePath, int currentIndex)
{
    NSLog(@"StartUnzipiOSImp");
    [[DownloadTaskManager shareManager] StartUnzip:[NSString stringWithUTF8String:downLoadedFilePath] currentIndex:currentIndex];
}

void RegisterDownloadCallback(DownloadFailure func, DownloadProgress func1, DownloadComplete func2)
{
    downloadCompleteDelegate = func2;
    downloadFailureDelegate = func;
    downloadProgressDelegate = func1;
}

void RegisterUnzipCallback(UnzipFailure func, UnzipProgress func1, UnzipComplete func2)
{
    unzipFailureDelegate = func;
    unzipProgressDelegate = func1;
    unzipCompleteDelegate = func2;
}
