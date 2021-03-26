//
//  DownloadTaskManager.m
//  Notification
//
//  Created by spr on 2021/3/5.
//

#include "DownloadTaskManager.h"
#import "CommonUtil.h"
#import "FileUtil.h"
#import "SSZipArchive.h"
#import <UserNotifications/UNUserNotificationCenter.h>
#import <UserNotifications/UNNotificationContent.h>
#import <UserNotifications/UNNotificationSound.h>
#import <UserNotifications/UNNotificationAttachment.h>
#import <UserNotifications/UNNotificationAction.h>
#import <UserNotifications/UNNotificationCategory.h>
#import <UserNotifications/UNNotificationRequest.h>
#import <UserNotifications/UNNotificationTrigger.h>
#import <UIKit/UIApplication.h>


@interface DownloadTaskInfo : NSObject
@property NSString* downloadUrl;
@property NSString* md5;
@property NSString* fileName;
@property NSString* downloadFilePath;
@property int64_t totalBytesWritten;
@property int64_t totalBytesExpectedToWrite;
@property NSURLSessionDownloadTask* downloadTask;
@property NSString* errorMsg;
@property NSUInteger errorScope;
@property NSUInteger responseCode;
@property NSUInteger tryCount;
@end

@interface UnzipInfo : NSObject
@property NSString* unzipFilePath;
@property NSUInteger unzipedCount;
@property NSUInteger unzipTotalCount;
@end

static NSUInteger lastWriteDeltaData = 0;
static NSUInteger lastWriteDeltaTime = 0;
static NSUInteger lastUnzipDeltaTime = 0;
static NSUInteger maxUnzipSameTime = 1;
static int64_t totalSize = 0;
static int64_t totalWritedSize = 0;
@implementation DownloadTaskInfo

@end

@implementation UnzipInfo

@end

@interface DownloadTaskManager () <NSURLSessionDelegate, NSURLSessionDownloadDelegate,SSZipArchiveDelegate>


//@property (nonatomic, copy) DownloadFailure downloadFailureBlock;

@property NSString* downloadTargetPath;
@property NSString* unzipTargetPath;
@property int totalUpdateNum;
@property id<ProcessHandler>processHandler;
@property BOOL started;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary *downloadTaskDict;
@property (nonatomic, strong) NSMutableDictionary *resumeDataDict;
@property (nonatomic, strong) NSMutableDictionary *downloadFailedDict;
@property (nonatomic, strong) NSMutableDictionary *unzipDict;
@property (nonatomic, strong) NSMutableDictionary *unzipingDict;
@property BOOL resumeDataClean;
//@property CompleteHandler completeHandler;

@end

@implementation DownloadTaskManager

+ (instancetype)shareManager {
    static DownloadTaskManager *downloadManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloadManager = [[self alloc] init];
    });
    
    return downloadManager;
}

-(NSURLSession*)session
{
    if(NULL == _session)
    {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:[CommonUtil getBundleID]];
        
        configuration.allowsCellularAccess = YES;
        configuration.discretionary = false;
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:queue];
    }
    return _session;
}

- (void)resumeDownload
{
    if(NULL == _session)
    {
        NSLog(@"initSession invalid!");
        return;
    }
   
    for (NSString* key in  self.downloadTaskDict) {
        DownloadTaskInfo* info = [self.downloadTaskDict objectForKey:key];
        if(NULL != info.downloadTask)
        {
            [info.downloadTask resume];
            break;
        }
    }
    NSLog(@"initSession valid!");
}

- (instancetype)init
{
    if (self = [super init]) {
        _downloadTaskDict = [NSMutableDictionary dictionary];
        _resumeDataDict = [NSMutableDictionary dictionary];
        _downloadFailedDict = [NSMutableDictionary dictionary];
        _unzipingDict = [NSMutableDictionary dictionary];
        _unzipDict = [NSMutableDictionary dictionary];
    }
    return self;
}


- (void) InitDownload:(NSString*)downloadDir unzipDirPath:(NSString*)unzipDirPath totalDownloadCount:(int) totalDownloadCount
{
    NSString *homePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    self.downloadTargetPath = [homePath stringByAppendingPathComponent:downloadDir];
    [FileUtil createDirRecurse: self.downloadTargetPath];
    self.unzipTargetPath = homePath;
    [FileUtil createDirRecurse: self.unzipTargetPath];
    self.totalUpdateNum = totalDownloadCount;
    [_downloadTaskDict removeAllObjects];
    [_resumeDataDict removeAllObjects];
    [_downloadFailedDict removeAllObjects];
    [_unzipingDict removeAllObjects];
    [_unzipDict removeAllObjects];
    if(self.session)
    {
        NSLog(@"init session");
    }
    self.started = false;
    
    totalSize = 0;
    totalWritedSize = 0;
}

- (void)StartDownload:(NSString*)downloadUrl md5:(NSString*)md5  fileName:(NSString*)fileName fileSize:(int64_t)fileSize
         delayInMills:(int)delayInMills
{
    NSLog(@"StartDownload url:%@ md5 %@:fileName %@:filesize:%lld delayInMills:%d",downloadUrl,md5,fileName,fileSize,delayInMills);
    self.started = true;
    if (![self checkIsUrlAtString:downloadUrl]) {
        NSLog(@"无效的下载地址===%@", downloadUrl);
        return;
    }
    
    NSString* localFilePath = [FileUtil getDownloadFilePathByUrl:downloadUrl fileName:fileName downloadDirPath:self.downloadTargetPath];
    BOOL ret = [self hasDownloaded:downloadUrl md5:md5 fileName:fileName];
    if(ret)
    {
        [self.processHandler downloadComplete:downloadUrl downloadedFilePath:localFilePath];
        [self StartUnzip:localFilePath];
        return;
    }
    
    if([self.downloadTaskDict.allKeys containsObject:downloadUrl])
    {
        DownloadTaskInfo* info = [self.downloadTaskDict objectForKey:downloadUrl];
        info.md5 = md5;
//        info.totalBytesExpectedToWrite = fileSize;
//        self.resumeDataClean = FALSE;
//        [self intResumeDataDict];
        NSLog(@"already exsit downloadUrl:%@-%@",downloadUrl,self.downloadTaskDict.allKeys);
        return;
    }
    
    DownloadTaskInfo* info = [self getTaskInfoWithUrl:downloadUrl fileName:fileName md5:md5 fileSize:fileSize];
    self.downloadTaskDict[downloadUrl] = info;
    
    if(0 == delayInMills)
    {
        [self activeDownloadSessionTaskWithUrl:downloadUrl];
    }
    else
    {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInMills * NSEC_PER_MSEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self activeDownloadSessionTaskWithUrl:downloadUrl];
        });
    }
}

- (void)AddDownload:(NSString*)downloadUrl md5:(NSString*)md5  fileName:(NSString*)fileName fileSize:(int64_t)fileSize
       delayInMills:(int)delayInMills
{
    NSLog(@"AddDownload url:%@ md5 %@:fileName %@:filesize:%lld delayInMills:%d",downloadUrl,md5,fileName,fileSize,delayInMills);
    if (![self checkIsUrlAtString:downloadUrl]) {
        NSLog(@"无效的下载地址===%@", downloadUrl);
        return;
    }
    
    NSString* localFilePath = [FileUtil getDownloadFilePathByUrl:downloadUrl fileName:fileName downloadDirPath:self.downloadTargetPath];
    BOOL ret = [self hasDownloaded:downloadUrl md5:md5 fileName:fileName];
    if(ret)
    {
        [self.processHandler downloadComplete:downloadUrl downloadedFilePath:localFilePath];
        [self StartUnzip:localFilePath];
        NSLog(@"已经下载完成:%@", localFilePath);
        return;
    }
    
    totalSize += fileSize;
    if([self.downloadTaskDict.allKeys containsObject:downloadUrl])
    {
        DownloadTaskInfo* info = [self.downloadTaskDict objectForKey:downloadUrl];
        info.md5 = md5;
        info.totalBytesExpectedToWrite = fileSize;
//        self.resumeDataClean = FALSE;
//        [self intResumeDataDict];
        NSLog(@"already exsit downloadUrl:%@-%@",downloadUrl,self.downloadTaskDict.allKeys);
        return;
    }
    
    DownloadTaskInfo* info = [self getTaskInfoWithUrl:downloadUrl fileName:fileName md5:md5 fileSize:fileSize];
    self.resumeDataClean = FALSE;
    [self intResumeDataDict];
    self.downloadTaskDict[downloadUrl] = info;
}

-(void)AddReDownloadInfo:(DownloadTaskInfo*)info delayInMills:(int)delayInMills
{
    NSLog(@"AddDownload:delayInMills url:%@",info.downloadUrl);
    info.tryCount++;
    if([self.downloadTaskDict.allKeys containsObject:info.downloadUrl])
    {
        NSLog(@"already exsit downloadUrl:%@-%@",info.downloadUrl,self.downloadTaskDict.allKeys);
        return;
    }

    self.downloadTaskDict[info.downloadUrl] = info;
}

-(void)Start
{
    self.started = true;
    for (NSString* key in self.downloadTaskDict)
    {
        DownloadTaskInfo* info = [self.downloadTaskDict objectForKey:key];
        if(NULL == info.downloadTask)
        {
            [self activeDownloadSessionTaskWithUrl:info.downloadUrl];
        }
    }
}

-(void)RetryDownload
{
    if(0 < self.downloadFailedDict.count)
    {
        for (NSString* key in self.downloadFailedDict) {
            DownloadTaskInfo* info = self.downloadFailedDict[key];
            info.tryCount = 0;
            [self AddReDownloadInfo:info delayInMills:0];
        }
        [self Start];
    }
}

#pragma mark - Public

- (void)pauseDownloadWithUrl:(NSString *)urlStr {
    [self cancelDownloadWithUrl:urlStr andRemoveOrNot:NO];
}

- (void)continueDownloadWithUrl:(NSString *)urlStr {
    [self activeDownloadSessionTaskWithUrl:urlStr];
}

- (void)cancelDownloadWithUrl:(NSString *)urlStr {
    [self cancelDownloadWithUrl:urlStr andRemoveOrNot:YES];
}


#pragma mark - unzip

-(float)CalUnzipProgress:(NSString*) zipFilePath
         totalFileWriten:(long)totalFileWriten
         totalFileExpectedWriten:(long)totalFileExpectedWriten
{
    if([self.unzipingDict.allKeys containsObject:zipFilePath])
    {
        UnzipInfo* info = [self.unzipingDict objectForKey:zipFilePath];
        info.unzipedCount = totalFileWriten;
        info.unzipTotalCount = totalFileExpectedWriten;
    }
    long writed = 0;
    long total = 0;
    
    for (NSString* key in self.unzipingDict)
    {
        UnzipInfo* info = [self.unzipingDict objectForKey:key];
        writed += info.unzipedCount;
        total += info.unzipTotalCount;
    }
    
    return 1.0*writed/total;
}

-(void)unzipProgress:(NSString *)zipFilePath entryNumber:(long) entryNumber total:(long) total
{
    NSUInteger currentTime = [self getCurrentSysTime];
    if(currentTime - lastUnzipDeltaTime > 0)
    {
        double progress = [self CalUnzipProgress:zipFilePath totalFileWriten:entryNumber totalFileExpectedWriten:total];
        [self.processHandler unzipProgress:zipFilePath progress:progress*100];
        lastUnzipDeltaTime = currentTime;
        NSLog(@"unzip path:%@,progress:%f",zipFilePath,progress);
    }
}

-(void)unzipComplete:(NSString *)path succeeded:(BOOL) succeeded error:(NSError*) error
{
    NSLog(@"unzipComplete path:%@,progress:%@",path,error);
    [self.unzipingDict removeObjectForKey:path];
    if(NULL!= error)
    {
        [self.processHandler unzipFailure:path errorMsg:error.localizedDescription errorScope:(int)error.code];
    }
    else
    {
        [self.processHandler unzipProgress:path progress:100];
        [self.processHandler unzipComplete:path];
    }
    [self NextUnzipStart];
    
    if(0 == self.unzipingDict.count && 0 == self.downloadTaskDict.count)
    {
        [self.processHandler unzipDone];
        NSLog(@"下载列表，解压列表为空！且终失败列表大小：%lu",((unsigned long)self.downloadFailedDict.count));
    }
}

- (void)NextUnzipStart
{
    NSArray* keys = self.unzipDict.allKeys;
    int index = 0;
    while(maxUnzipSameTime > self.unzipingDict.count && 0 < self.unzipDict.count)
    {
        NSString* key = keys[index++];
        UnzipInfo* unzipInfo = self.unzipDict[key];
        [self.unzipDict removeObjectForKey:key];
        self.unzipingDict[unzipInfo.unzipFilePath] = unzipInfo;
        NSLog(@"NextUnzipStart：%@",unzipInfo.unzipFilePath);
        [self StartUnzipProcess:unzipInfo.unzipFilePath];
    }
}

-(void)StartUnzip:(NSString*) zipFilePath
{
    NSLog(@"StartUnzip：%@",zipFilePath);
    if([self.unzipDict.allKeys containsObject:zipFilePath] || [self.unzipingDict.allKeys containsObject:zipFilePath])
    {
        NSLog(@"StartUnzip is unziping：%@",zipFilePath);
        return;
    }
    self.unzipDict[zipFilePath] = [self GetUnzipInfo:zipFilePath];
    [self NextUnzipStart];
}

- (void)StartUnzipProcess:(NSString*)zipFilePath
{
    NSLog(@"StartUnzipProcess：%@",zipFilePath);
    __weak typeof(self) weakSelf = self;
    dispatch_queue_t groupQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(groupQueue,^{
        [SSZipArchive unzipFileAtPath:zipFilePath toDestination:self.unzipTargetPath
                      progressHandler:^(NSString *entry, unz_file_info zipInfo, long entryNumber, long total){
            [weakSelf unzipProgress:zipFilePath entryNumber:entryNumber total:total];
        }
                    completionHandler:^(NSString *path, BOOL succeeded, NSError * _Nullable error){
            [weakSelf unzipComplete:path succeeded:succeeded error:error];
            
        }];
    });
}

-(UnzipInfo*)GetUnzipInfo:(NSString*)unzipFilePath
{
    UnzipInfo* info = [[UnzipInfo alloc] init];
    info.unzipFilePath = unzipFilePath;
    return info;
}

#pragma mark - Private

-(void)intResumeDataDict
{
    if(!self.resumeDataClean)
    {
        __weak typeof(self) weakSelf = self;
        for (NSString *filePath in [self getResumeDataFilePathArray]) {
            //判断如果沙盒中有文件的resumeData数据,则把它存储到resumeDataDic中,用resumeData开启downloadTask
            NSString *fileName = [[filePath lastPathComponent] stringByDeletingPathExtension];
            dispatch_queue_t groupQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_async(groupQueue,  ^{
                if(NULL == weakSelf)
                {
                    return;
                }
                NSData *resumeData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:nil];
                [weakSelf.resumeDataDict setValue:resumeData forKey:fileName];
                
            });
        }
        self.resumeDataClean = TRUE;
    }
}

- (void)activeDownloadSessionTaskWithUrl:(NSString *)urlStr {
    NSString* fileName = [FileUtil getFileNameByUrl:urlStr];

    NSURLSessionDownloadTask *downloadTask = nil;

    if ([self.resumeDataDict.allKeys containsObject:fileName]) {
        downloadTask = [self.session downloadTaskWithResumeData:self.resumeDataDict[fileName]];
        NSLog(@"continue download:%@",urlStr);
    } else {
        downloadTask = [self.session downloadTaskWithURL:[NSURL URLWithString:urlStr]];
        NSLog(@"new download:%@",urlStr);
    }
    
    downloadTask.taskDescription = urlStr;
    if([self.downloadTaskDict.allKeys containsObject:urlStr])
    {
        DownloadTaskInfo* info = [self.downloadTaskDict objectForKey:urlStr];
        info.downloadTask = downloadTask;
    }
    else
    {
        DownloadTaskInfo* info = [self getTaskInfoWithUrl:urlStr fileName:NULL  md5:NULL fileSize:0];
        info.downloadTask = downloadTask;
        self.downloadTaskDict[urlStr] = info ;
    }
    
    [downloadTask resume];
    NSLog(@"downloadTask = %@", downloadTask);
}

- (void)cancelDownloadWithUrl:(NSString *)urlStr andRemoveOrNot:(BOOL)isRemove {
 
    if (![self.downloadTaskDict.allKeys containsObject:urlStr]) {
        return;
    }
    
    NSString* fileName = [FileUtil getFileNameByUrl:urlStr];
    DownloadTaskInfo* info =[self.downloadTaskDict objectForKey:urlStr];
    if(NULL == info.downloadTask)
    {
        return;
    }
    
    NSURLSessionDownloadTask *downloadTask = info.downloadTask;
    
    [downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        self.resumeDataDict[fileName] = resumeData;
        if (!isRemove) {
            [self saveDownloadTmpFileWithResumeData:resumeData url:urlStr];
        } else {
            [self removeDownloadTmpFileWithUrl:urlStr];
        }
//#warning 开启等待下载的任务
    }];
}

//保存下载过程中的resumeData
- (void)saveDownloadTmpFileWithResumeData:(NSData *)resumeData url:(NSString *)urlStr {
    NSLog(@"保存resume data");
//    NSString *base64Url = [self encode:urlStr];
    [resumeData writeToFile:[self getTmpPathWithUrl:urlStr] atomically:YES];
    self.resumeDataClean = FALSE;
//    [self.downloadTaskDic removeObjectForKey:urlStr];
}

//删除之前保存的文件的resumeData
- (void)removeDownloadTmpFileWithUrl:(NSString *)downloadUrl {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* tempFilePath = [self getTmpPathWithUrl:downloadUrl];
    NSLog(@"removeDownloadTmpFileWithUrl");
    if([fileManager fileExistsAtPath:tempFilePath])
    {
        NSError* error = NULL;
        BOOL success = [fileManager removeItemAtPath:tempFilePath error:&error];
        if (!success) {
            NSLog(@"resumeData删除失败:%@",error);
        }
    }
    NSString* fileName = [FileUtil getFileNameByUrl:downloadUrl];
    [self.resumeDataDict removeObjectForKey:fileName];
}

-(void)tryAddLoadingTask:(NSURLSessionDownloadTask*) downloadTask totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NSString* downloadUrl = downloadTask.taskDescription;
    if(![self.downloadTaskDict.allKeys containsObject:downloadUrl])
    {
        DownloadTaskInfo* info = [self getTaskInfoWithUrl:downloadUrl fileName:NULL md5:NULL fileSize:0];
        self.downloadTaskDict[downloadUrl] = info;
        info.downloadTask = downloadTask;
        info.totalBytesWritten = totalBytesWritten;
        info.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
        NSLog(@"add exsit download task %@:",downloadUrl);
    }
}

-(void)pushNotification_IOS_10_Body:(NSString *)body
{
    UNUserNotificationCenter * center  = [UNUserNotificationCenter currentNotificationCenter];
    UNMutableNotificationContent * content = [[UNMutableNotificationContent alloc]init];
    content.body = body;
    content.sound = [UNNotificationSound defaultSound];
    content.title = [CommonUtil getAppName];

    UNTimeIntervalNotificationTrigger * tirgger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:.5f repeats:NO];


    NSString*identifier = [CommonUtil getBundleID];
    UNNotificationRequest * request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:tirgger];


    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {

        NSLog(@"%@本地推送 :( 报错 %@",identifier,error);

    }];
}

-(void)allProcessDone
{
    [self.session invalidateAndCancel];
    self.session = NULL;
}

-(float)CalProgress:(NSString*) downloadUrl
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if([self.downloadTaskDict.allKeys containsObject:downloadUrl])
    {
        DownloadTaskInfo* info = [self.downloadTaskDict objectForKey:downloadUrl];
        info.totalBytesWritten = totalBytesWritten;
        info.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    }
    int64_t writed = 0;
    int64_t total = 0;
    
    for (NSString* key in self.downloadTaskDict)
    {
        DownloadTaskInfo* info = [self.downloadTaskDict objectForKey:key];
        writed += info.totalBytesWritten;
        total += info.totalBytesExpectedToWrite;
//        NSLog(@"writed:%lld,CalProgress:%lld",writed,total);
    }
//    NSLog(@"writed:%lld,CalProgress:%lld",writed,total);
    return 1.0*writed/total;
}

-(void)AddFailureDownload:(DownloadTaskInfo*)info
{
    NSLog(@"AddFailureDownload:%@",info.downloadUrl);
    if(![self.downloadFailedDict.allKeys containsObject:info.downloadUrl])
    {
        self.downloadFailedDict[info.downloadUrl] = info;
    }
    else
    {
        NSLog(@"AddFailureDownload exsit!");
    }
}

-(BOOL)appISBackground
{
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    return state == UIApplicationStateBackground;
}

- (void) SetDownloadDelegate:(id<ProcessHandler>)delegate
{
    self.processHandler = delegate;
}

- (void)downloadWithUrl:(NSString *)urlStr {

    if (![self checkIsUrlAtString:urlStr]) {
        NSLog(@"无效的下载地址===%@", urlStr);
        return;
    }
    
    [self activeDownloadSessionTaskWithUrl:urlStr];
}

-(void)Notify
{
    dispatch_async(dispatch_get_main_queue(), ^{  //需要执行的方法
       if([self appISBackground])
       {
           [self pushNotification_IOS_10_Body:[CommonUtil getDownloadTip]];
       }
        if(NULL != self.completeHandler)
        {
            self.completeHandler();
        }
    });
}

-(void)AllDownloadDone
{
    NSLog(@"AllDownloadDone");
    [self Notify];
    if(0 < self.downloadFailedDict.count)
    {
        NSString* errorTip = NULL;
        for (NSString* key in self.downloadFailedDict) {
            DownloadTaskInfo* info = self.downloadFailedDict[key];
            errorTip = [NSString stringWithFormat:@"errorMsg:%@|&$|errorScope:%lu|&$|responseCode:%lu",info.errorMsg,(unsigned long)info.errorScope,(unsigned long)info.responseCode];
            break;
        }
        [self.processHandler downloadDone:errorTip];
    }
    else
    {
        [self.processHandler downloadProgress:@"" progress:100];
        [self.processHandler downloadDone:@""];
    }
}

/*
 * Messages related to the operation of a task that writes data to a
 * file and notifies the delegate upon completion.
 */
#pragma mark - NSURLSessionDownloadDelegate

/* Sent periodically to notify the delegate of download progress. */
- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    //进度
    if(!self.started) {
        NSLog(@"download task description%@,%@",downloadTask.taskDescription,downloadTask);
        [self tryAddLoadingTask:downloadTask totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
        return;
    };
    NSInteger currentTime = [self getCurrentSysTime];
    NSInteger deltaTime = currentTime - lastWriteDeltaTime;
    lastWriteDeltaData += bytesWritten;
    if( deltaTime > 300)
    {
        float progress = [self CalProgress:downloadTask.taskDescription totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
        
        NSInteger speed = lastWriteDeltaData * 1000.0 /deltaTime;
        NSString* speedStr = [StringUtil humanReadableByteCount:speed];
        
        NSLog(@"download task descriptio %@,totalBytesWritten:%lld,totalBytesExpectedToWrite:%lld,progress:%f,speed:%@",downloadTask.taskDescription,totalBytesWritten,totalBytesExpectedToWrite,progress,speedStr);
        [self.processHandler downloadProgress:downloadTask.taskDescription progress:progress*100];
        lastWriteDeltaTime = currentTime;
        lastWriteDeltaData = 0;
//        NSLog(@"download task description%@,%@,%f",downloadTask.taskDescription,downloadTask,progress);
    }
}

/**
 error：client-side error occurs
 */
/* Sent when a download task that has completed a download.  The delegate should
 * copy or move the file at the given location to a new location as it will be
 * removed when the delegate message returns. URLSession:task:didCompleteWithError: will
 * still be called.
 */
- (void)URLSession:(NSURLSession *)session
      downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(nonnull NSURL *)location {
    
    //移动文件到自己想要保存的路径下,location下的文件会被系统自动删除
    NSString* downloadUrl = downloadTask.taskDescription;
    NSLog(@"didFinishDownloadingToURL URL:%@",downloadUrl);
    if([self.downloadTaskDict.allKeys containsObject:downloadUrl])
    {
        DownloadTaskInfo* info = [self.downloadTaskDict objectForKey:downloadUrl];
        [self.downloadTaskDict removeObjectForKey:downloadUrl];
         
        NSString* errorMsg = NULL;
        int errorScope = -1;
        int responseCode = -1;
        NSString* downloadFilePath = info.downloadFilePath;
        NSString* moveError = [self renameTempFile:location.path destPath:downloadFilePath];
        
        if(NULL == moveError)
        {
            [self removeDownloadTmpFileWithUrl:downloadUrl];
            if(![self hasDownloaded:downloadUrl md5:info.md5 fileName:info.fileName])
            {
                NSLog(@"verify md5 failure!!url:%@,md5:%@ localmd5:%@",downloadUrl,info.md5,[FileUtil fileMD5:downloadFilePath]);
                [FileUtil deleteFile:downloadFilePath];
                errorMsg = @"md5 verify failure!!!";
                errorScope = 7;
            }
            else
            {
                NSLog(@"校验 %@ 的md5成功",downloadUrl);
            }
        }
        else
        {
            errorMsg = moveError;
            errorScope = 8;
        }
        if(!self.started)
        {
            return;
        }
        
        if(NULL == errorMsg)
        {
            [self.processHandler downloadComplete:info.downloadUrl downloadedFilePath:downloadFilePath];
            [self StartUnzip:downloadFilePath];
        }
        else
        {
            if ([downloadTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
                responseCode =(int)[(NSHTTPURLResponse *)downloadTask.response statusCode];
            }
            info.errorMsg = errorMsg;
            info.errorScope = errorScope;
            info.responseCode = responseCode;
            [self AddFailureDownload:info];
//            [self.processHandler downloadFailure:errorScope errorMsg:errorMsg responseCode:responseCode];
        }
    }
    else
    {
        NSString* downloadFilePath = [FileUtil getDownloadFilePathByUrl:downloadUrl fileName:NULL downloadDirPath:self.downloadTargetPath];
        NSString* moveError = [self renameTempFile:location.path destPath:downloadFilePath];
        NSLog(@"收到下载成功，但是未找到该下载任务: %@",moveError);
    }
}

/*
 * Messages related to the operation of a specific task.
 */
#pragma mark - NSURLSessionTaskDelegate

/**
 error：server-side error occurs
 */

/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
-(void)URLSession:(nonnull NSURLSession *)session
             task:(nonnull NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    NSLog(@"didCompleteWithError");
    NSString* downloadUrl = task.taskDescription;
    
    if (NULL != error && [self.downloadTaskDict.allKeys containsObject:downloadUrl]) {
        DownloadTaskInfo* info = self.downloadTaskDict[downloadUrl];
        [self.downloadTaskDict removeObjectForKey:downloadUrl];
        int errorScope = 0;
        if ([error.localizedDescription isEqualToString:@"cancelled"]) {
            errorScope = 4;
        }
        else if ([error.userInfo objectForKey:NSURLErrorBackgroundTaskCancelledReasonKey]) {
            errorScope = 8;
        }
        else
        {
            errorScope = (int)error.code;
        }
        if(NULL != [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData])
        {
            [self saveDownloadTmpFileWithResumeData:[error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData] url:downloadUrl];
        }
        
        NSLog(@"error = %@", error);
        
        if(self.started)
        {
            int responseCode = 0;
            if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
                responseCode =(int)[(NSHTTPURLResponse *)task.response statusCode];
            }
           
           
            info.errorMsg = error.localizedDescription;
            info.errorScope = errorScope;
            info.responseCode = responseCode;
            [self AddFailureDownload:info];
            [self.processHandler downloadFailure:info.downloadUrl errorScope:errorScope errorMsg:error.localizedDescription responseCode:responseCode];
        }
        else
        {
            NSLog(@"收到下载完成，但是游戏逻辑未开始");
        }
    }
    else if (NULL != error)
    {
        if(NULL != [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData])
        {
            [self saveDownloadTmpFileWithResumeData:[error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData] url:downloadUrl];
        }
        NSLog(@"收到下载完成，但是游戏逻辑未开始，或未找到下载信息:%@",error);
    }
}

/*
 * NSURLSessionDelegate specifies the methods that a session delegate
 * may respond to.  There are both session specific messages (for
 * example, connection based auth) as well as task based messages.
 */

/*
 * Messages related to the URL session as a whole
 */
#pragma mark - NSURLSessionDelegate

/* If an application has received an
 * -application:handleEventsForBackgroundURLSession:completionHandler:
 * message, the session delegate will receive this message to indicate
 * that all messages previously enqueued for this session have been
 * delivered.  At this time it is safe to invoke the previously stored
 * completion handler, or to begin any internal updates that will
 * result in invoking the completion handler.
 */
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSLog(@"所有任务下载完成，URLSessionDidFinishEventsForBackgroundURLSession");
    ///TODO invovl complete handler;
//    dispatch_async(dispatch_get_main_queue(), ^(){
//        if(NULL != self.completeHandler)
//        {
//            self.completeHandler();
//        }
//    });
    NSUInteger count = self.downloadFailedDict.count;
    if( count > 0)
    {
        for (NSString*key in [self.downloadFailedDict allKeys])
        {
            DownloadTaskInfo* info = self.downloadFailedDict[key];
            if(info.tryCount < 3)
            {
                NSLog(@"reDownload addDownloadInfo");
                [self AddReDownloadInfo:info delayInMills:300];
                [self.downloadFailedDict removeObjectForKey:key];
            }
            else
            {
                NSLog(@"%@ exceed max limit try count!",info.downloadUrl);
            }
        }
        NSUInteger leftCount = self.downloadFailedDict.count;
        if(leftCount < count)
        {
            NSLog(@"reDownload start");
            [self Start];
        }
        if(0 == leftCount)
        {
//            TODO
            NSLog(@"正在重试所有失败文件下载！");
        }
        else if(count == leftCount)
        {
            NSLog(@"剩余下%lu个下载重试3次依然未能成功!",((unsigned long)leftCount));
            for (NSString*key in [self.downloadFailedDict allKeys])
            {
                DownloadTaskInfo* info = self.downloadFailedDict[key];
                NSLog(@"%@ exceed max limit try count!count:%lu",info.downloadUrl,((unsigned long)info.tryCount));
            }
            [self AllDownloadDone];
        }
        else
        {
            NSLog(@"剩余下%ld个下载重试3次依然未能成功! 正在重试%lu个之前下载失败的文件！",((unsigned long)leftCount),((unsigned long)(count - leftCount)));
        }
    }
    else
    {
        NSLog(@"AllDownloadDone");
        [self AllDownloadDone];
    }
}

/* The last message a session receives.  A session will only become
 * invalid because of a systemic error or when it has been
 * explicitly invalidated, in which case the error parameter will be nil.
 */
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error
{
    NSLog(@"didBecomeInvalidWithError");
}

#pragma mark - Tools

- (BOOL)checkIsUrlAtString:(NSString *)url {
    NSString *pattern = @"http(s)?://([\\w-]+\\.)+[\\w-]+(/[\\w- ./?%&=]*)?";
    
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:nil];
    NSArray *regexArray = [regex matchesInString:url options:0 range:NSMakeRange(0, url.length)];
    
    if (regexArray.count > 0) {
        return YES;
    }else {
        return NO;
    }
}

- (NSString *)getTmpPathWithUrl:(NSString *)urlStr {
    
    NSString *fileName = [FileUtil getFileNameByUrl:urlStr];

    NSString *homePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *tmpDirectory = [homePath stringByAppendingPathComponent:@"resumeData"];
    
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    if (![defaultManager fileExistsAtPath:tmpDirectory]) {
        [defaultManager createDirectoryAtPath:tmpDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *tmpFile = [tmpDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.tmp", fileName]];
    return tmpFile;
}


- (NSArray *)getResumeDataFilePathArray {
    NSMutableArray *urls = [NSMutableArray array];
    //目录
    NSString *homePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *tmpDirectory = [homePath stringByAppendingPathComponent:@"resumeData"];
    NSFileManager *myFileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *myDirectoryEnumerator = [myFileManager enumeratorAtPath:tmpDirectory];
    
    BOOL isDir = NO;
    BOOL isExist = NO;
    
    //列举目录内容，可以遍历子目录
    for (NSString *path in myDirectoryEnumerator.allObjects) {
        NSString *filePath = [NSString stringWithFormat:@"%@/%@", tmpDirectory, path];
        NSLog(@"resumedata sub path:%@",filePath);
        isExist = [myFileManager fileExistsAtPath:filePath isDirectory:&isDir];
        if (isDir) {
            // 目录路径
            NSLog(@"这是个目录%@", path);
        } else {
            //文件名
            [urls addObject:filePath];
        }
    }
    return urls;
}


- (NSString *)encode:(NSString *)string {
    //先将string转换成data
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *base64Data = [data base64EncodedDataWithOptions:0];
    
    NSString *baseString = [[NSString alloc]initWithData:base64Data encoding:NSUTF8StringEncoding];
    
    return baseString;
}


- (NSString *)dencode:(NSString *)base64String
{
    //NSData *base64data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *data = [[NSData alloc]initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    NSString *string = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    
    return string;
}


- (BOOL)hasDownloaded:(NSString*)downloadUrl md5:(NSString*)md5 fileName:(NSString*)fileName
{
    NSString* localFilePath = [FileUtil getDownloadFilePathByUrl:downloadUrl fileName:fileName downloadDirPath:self.downloadTargetPath];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:localFilePath])
    {
        return FALSE;
    }
    if(![NSString isBlankString:md5])
    {
        NSString* localMd5 = [FileUtil fileMD5:localFilePath];
        if(![localMd5 isEqualToString:md5])
        {
            [fileManager removeItemAtPath:localFilePath error:NULL];
            return FALSE;
        }
    }
    return TRUE;
}

-(DownloadTaskInfo*) getTaskInfoWithUrl:(NSString*)downloadUrl fileName:(NSString*)fileName md5:(NSString*)md5 fileSize:(int64_t)fileSize
{
    NSString* localFilePath = [FileUtil getDownloadFilePathByUrl:downloadUrl fileName:NULL downloadDirPath:self.downloadTargetPath];
    DownloadTaskInfo* info = [DownloadTaskInfo alloc];
    info.downloadFilePath = localFilePath;
    info.downloadUrl = downloadUrl;
    info.md5 = md5;
    info.totalBytesExpectedToWrite = fileSize;
    info.tryCount = 0;
    if(NULL == fileName)
    {
        fileName = [FileUtil getFileNameByUrl:downloadUrl];
    }
    info.fileName = fileName;
    return info;
}


-(NSString*) renameTempFile:(NSString*)location destPath:(NSString*)savePath
{
    NSError *saveError = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:savePath]) {
       [fileManager removeItemAtPath:savePath error:nil];
    }

    BOOL success = [fileManager moveItemAtPath:location toPath:savePath error:&saveError];
    if (success) {
        NSLog(@"文件下载完成,路径为 == %@", savePath);
        return NULL;
    } else {
        NSLog(@"在转移文件时发生错误 %@", saveError);
        return saveError.localizedDescription;
    }
}

-(NSUInteger)getCurrentSysTime
{
    NSDate* dat = [NSDate date];
    NSUInteger interval = [dat timeIntervalSince1970]*1000;
    return interval;
}

- (void)dealloc {
    [self.session invalidateAndCancel];
}

@end
