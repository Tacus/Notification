//
//  DownloadTaskManager.h
//  Notification
//
//  Created by spr on 2021/3/5.
//

#ifndef DownloadTaskManager_h
#define DownloadTaskManager_h

#import<Foundation/Foundation.h>


typedef void(^DownloadComplete)(NSString *url);
typedef void(^DownloadFailure)(int errorScope,NSString* errorMsg,int responseCode);
typedef void(^DownloadProgress)(float progress);


typedef void(^UnzipComplete)(NSString *url);
typedef void(^UnzipFailure)(int errorScope,NSString* errorMsg,int responseCode);
typedef void(^UnzipProgress)(float progress);

@interface DownloadTaskManager : NSObject
@property (nonatomic, assign) NSInteger maxConcurrentCount;

+ (instancetype)shareManager;



- (instancetype)initWithBlock:(DownloadFailure)downloadFailure
             downloadProgress:(DownloadProgress)downloadProgress
downloadComplete:(DownloadComplete)downloadcomplete;

/**< 开始下载*/
- (void)downloadWithUrl:(NSString *)urlStr;

/**< 暂停下载*/
- (void)pauseDownloadWithUrl:(NSString *)urlStr;

/**< 继续下载*/
- (void)continueDownloadWithUrl:(NSString *)urlStr;

/**< 取消下载*/
- (void)cancelDownloadWithUrl:(NSString *)urlStr;
@end

#endif /* DownloadTaskManager_h */
