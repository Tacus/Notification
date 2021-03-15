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
@property (nonatomic, assign) NSInteger maxConcurrentCount;

+ (instancetype)shareManager;


- (void)initSession;
- (instancetype)init;

/**< 开始下载*/
- (void)downloadWithUrl:(NSString *)urlStr;

/**< 暂停下载*/
- (void)pauseDownloadWithUrl:(NSString *)urlStr;

/**< 继续下载*/
- (void)continueDownloadWithUrl:(NSString *)urlStr;

/**< 取消下载*/
- (void)cancelDownloadWithUrl:(NSString *)urlStr;

- (void)StartDownload:(NSString*)downloadUrl md5:(NSString*)md5  fileName:(NSString*)downloadFileName
                                     currentIndex:(int)currentIndex delayInMills:(int)delayInMills;

- (void)StartUnzip:(NSString*)zipFilePath currentIndex:(int)currentIndex;

- (void) InitDownload:(NSString*)downloadDirPath unzipDirPath:(NSString*)unzipDirPath totalDownloadCount:(int) totalDownloadCount;
- (void) SetDownloadDelegate:(id<ProcessHandler>)delegate;
-(void) setCompleteHandler:(CompleteHandler)completeHandler;
@end

#endif /* DownloadTaskManager_h */
