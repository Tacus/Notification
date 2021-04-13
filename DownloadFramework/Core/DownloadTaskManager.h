//
//  DownloadTaskManager.h
//  Notification
//
//  Created by spr on 2021/3/5.
//

#ifndef DownloadTaskManager_h
#define DownloadTaskManager_h

#import <Foundation/Foundation.h>
#import "DownloadBridge.h"
#import "ProcessHandler.h"

typedef  void (^CompleteHandler)(void);
@interface DownloadTaskManager : NSObject
@property CompleteHandler completeHandler;
@property (nonatomic, assign) NSInteger maxConcurrentCount;

+ (instancetype)shareManager;


- (void)resumeDownload;
- (instancetype)init;

/**< 开始下载*/
- (void)downloadWithUrl:(NSString *)urlStr;

/**< 暂停下载*/
- (void)pauseDownloadWithUrl:(NSString *)urlStr;

/**< 继续下载*/
- (void)continueDownloadWithUrl:(NSString *)urlStr;

/**< 取消下载*/
- (void)cancelDownloadWithUrl:(NSString *)urlStr;

//- (void)StartDownload:(NSString*)downloadUrl md5:(NSString*)md5  fileName:(NSString*)downloadFileName fileSize:(int64_t)fileSize
//         delayInMills:(int)delayInMills priority:(int)priority;
- (void)AddDownload:(NSString*)downloadUrl md5:(NSString*)md5  fileName:(NSString*)fileName fileSize:(int64_t)fileSize
       delayInMills:(int)delayInMills priority:(int)priority;

- (void)StartUnzip:(NSString*)zipFilePath priority:(int)priority;
-(void)Start;
- (void) InitDownload:(NSString*)downloadDirPath unzipDirPath:(NSString*)unzipDirPath totalDownloadCount:(int) totalDownloadCount;
- (void) SetDownloadDelegate:(id<ProcessHandler>)delegate;
-(void) setCompleteHandler:(CompleteHandler)completeHandler;
-(void)RetryDownload;
-(void)CancelAllDownload;
-(void)Clear;
@end

#endif /* DownloadTaskManager_h */
