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


@property NSURLSessionDownloadTask* downloadTask;
@end

static NSInteger lastWriteDeltaData = 0;
static NSInteger lastWriteDeltaTime = 0;
static BOOL allDone = NO;
@implementation DownloadTaskInfo


@end

@interface DownloadTaskManager () <NSURLSessionDelegate, NSURLSessionDownloadDelegate,SSZipArchiveDelegate>


//@property (nonatomic, copy) DownloadFailure downloadFailureBlock;

@property NSString* downloadTargetPath;
@property NSString* unzipTargetPath;
@property int totalUpdateNum;
@property id<ProcessHandler>processHandler;
@property bool* started;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary *downloadTaskDic;
@property (nonatomic, strong) NSMutableDictionary *resumeDataDic;
@property CompleteHandler completeHandler;

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
//        configuration.sessionSendsLaunchEvents = TRUE;
//        configuration.shouldUseExtendedBackgroundIdleMode = TRUE;
//        configuration.timeoutIntervalForResource = 600;
//        configuration.timeoutIntervalForRequest = 20;
//        configuration.discretionary = YES;
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:queue];
        allDone = NO;
    }
    return _session;
}

-(void) setCompleteHandler:(CompleteHandler)completeHandler;
{
    self.completeHandler = completeHandler;
}

- (void)initSession
{
    if(NULL == self.session)
    {
        
    }
}

- (instancetype)init
{
    if (self = [super init]) {
        _downloadTaskDic = [NSMutableDictionary dictionary];
        _resumeDataDic = [NSMutableDictionary dictionary];
    }
    return self;
}


- (void) InitDownload:(NSString*)downloadDirPath unzipDirPath:(NSString*)unzipDirPath totalDownloadCount:(int) totalDownloadCount
{
    self.downloadTargetPath = downloadDirPath;
    [FileUtil createDirRecurse: downloadDirPath];
    self.unzipTargetPath = unzipDirPath;
    [FileUtil createDirRecurse: unzipDirPath];
    self.totalUpdateNum = totalDownloadCount;
    if(self.session)
    {
        NSLog(@"init session");
    }
}

- (void)StartDownload:(NSString*)downloadUrl md5:(NSString*)md5  fileName:(NSString*)fileName
                                     currentIndex:(int)currentIndex delayInMills:(int)delayInMills
{
    self.started = true;
    if (![self checkIsUrlAtString:downloadUrl]) {
        NSLog(@"无效的下载地址===%@", downloadUrl);
        return;
    }
    
    NSString* localFilePath = [FileUtil getDownloadFilePathByUrl:downloadUrl fileName:fileName downloadDirPath:self.downloadTargetPath];
    BOOL ret = [self hasDownloaded:downloadUrl md5:md5 fileName:fileName];
    if(ret)
    {
        [self.processHandler downloadComplete:localFilePath];
        return;
    }
    
//    NSString* base64Url = [self encode:downloadUrl];
    if([self.downloadTaskDic.allKeys containsObject:downloadUrl])
    {
        DownloadTaskInfo* info = [self.downloadTaskDic objectForKey:downloadUrl];
        info.md5 = md5;
        NSLog(@"already exsit downloadUrl:%@-%@",downloadUrl,self.downloadTaskDic.allKeys);
        return;
    }
    
    DownloadTaskInfo* info = [self getTaskInfoWithUrl:downloadUrl fileName:fileName md5:md5];
    self.downloadTaskDic[downloadUrl] = info;
    
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

- (void)StartUnzip:(NSString*)zipFilePath currentIndex:(int)currentIndex
{
    allDone = NO;
    __weak typeof(self) weakSelf = self;
    dispatch_queue_t groupQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(groupQueue,^{
        [SSZipArchive unzipFileAtPath:zipFilePath toDestination:self.unzipTargetPath
            progressHandler:^(NSString *entry, unz_file_info zipInfo, long entryNumber, long total)
                {
                    NSInteger currentTime = [self getCurrentSysTime];
                    if(currentTime - lastWriteDeltaTime > 100)
                    {
                        double progress = entryNumber*1.0/total;
                        [weakSelf.processHandler unzipProgress:progress*100];
                     
                        NSLog(@"unzip progress:%f",progress);
                        lastWriteDeltaTime = currentTime;
                        lastWriteDeltaData = entryNumber;
                    }
                }
            completionHandler:^(NSString *path, BOOL succeeded, NSError * _Nullable error)
                {
                    if(NULL!= error)
                    {
                        [weakSelf.processHandler unzipFailure:error.localizedDescription responseCode:(int)error.code];
                        return;
                    }
                    
                    [weakSelf.processHandler unzipComplete];
                    if(currentIndex == self.totalUpdateNum)
                    {
                        allDone = YES;
                        [self allProcessDone];
                        dispatch_async(dispatch_get_main_queue(), ^{  //需要执行的方法
                           if([self appISBackground])
                           {
                               [self pushNotification_IOS_10_Body:[CommonUtil getDownloadTip]];
                           }
                        });
                       
                    }
                }
         ];
    });
}

-(BOOL)appISBackground
{
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    return state == UIApplicationStateBackground;
}

-(NSInteger)getCurrentSysTime
{
    NSDate* dat = [NSDate date];
    NSInteger interval = [dat timeIntervalSince1970]*1000;
    return interval;
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

#pragma mark - Private
- (void)activeDownloadSessionTaskWithUrl:(NSString *)urlStr {
    NSString* fileName = [FileUtil getFileNameByUrl:urlStr];
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t groupQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    __weak typeof(self) weakSelf = self;
    for (NSString *filePath in [self getResumeDataFilePathArray]) {
        //判断如果沙盒中有文件的resumeData数据,则把它存储到resumeDataDic中,用resumeData开启downloadTask
        NSString *fileName = [[filePath lastPathComponent] stringByDeletingPathExtension];
       
        if ([fileName isEqualToString:fileName]) {
            dispatch_group_async(group, groupQueue, ^{
                NSData *resumeData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:nil];
                [weakSelf.resumeDataDic setValue:resumeData forKey:fileName];
                
            });
            
            break;
        }
    }
    
    dispatch_notify(group, groupQueue, ^{
        NSURLSessionDownloadTask *downloadTask = nil;

        if ([self.resumeDataDic.allKeys containsObject:fileName]) {
            downloadTask = [self.session downloadTaskWithResumeData:self.resumeDataDic[fileName]];
            NSLog(@"continue download:%@",urlStr);
        } else {
            downloadTask = [self.session downloadTaskWithURL:[NSURL URLWithString:urlStr]];
            NSLog(@"new download:%@",urlStr);
        }
        
        downloadTask.taskDescription = urlStr;
        if([self.downloadTaskDic.allKeys containsObject:urlStr])
        {
            DownloadTaskInfo* info = [self.downloadTaskDic objectForKey:urlStr];
            info.downloadTask = downloadTask;
        }
        else
        {
            DownloadTaskInfo* info = [self getTaskInfoWithUrl:urlStr fileName:NULL md5:NULL];
            info.downloadTask = downloadTask;
            self.downloadTaskDic[urlStr] = info ;
        }
        
        [downloadTask resume];
        NSLog(@"downloadTask = %@", downloadTask);
    });
}

- (void)cancelDownloadWithUrl:(NSString *)urlStr andRemoveOrNot:(BOOL)isRemove {
 
    if (![self.downloadTaskDic.allKeys containsObject:urlStr]) {
        return;
    }
    
    NSString* fileName = [FileUtil getFileNameByUrl:urlStr];
    DownloadTaskInfo* info =[self.downloadTaskDic objectForKey:urlStr];
    if(NULL == info.downloadTask)
    {
        return;
    }
    
    NSURLSessionDownloadTask *downloadTask = info.downloadTask;
    
    [downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        self.resumeDataDic[fileName] = resumeData;
        if (!isRemove) {
            [self saveDownloadTmpFileWithResumeData:resumeData url:urlStr];
        } else {
            [self removeDownloadTmpFileWithUrl:urlStr];
        }
#warning 开启等待下载的任务
    }];
}

//保存下载过程中的resumeData
- (void)saveDownloadTmpFileWithResumeData:(NSData *)resumeData url:(NSString *)urlStr {
    NSLog(@"保存resume data");
//    NSString *base64Url = [self encode:urlStr];
    [resumeData writeToFile:[self getTmpPathWithUrl:urlStr] atomically:YES];
//    [self.downloadTaskDic removeObjectForKey:urlStr];
}

//删除之前保存的文件的resumeData
- (void)removeDownloadTmpFileWithUrl:(NSString *)urlStr {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* tempFilePath = [self getTmpPathWithUrl:urlStr];
    if([fileManager fileExistsAtPath:tempFilePath])
    {
        BOOL success = [fileManager removeItemAtPath:tempFilePath error:nil];
        if (!success) {
            NSLog(@"resumeData删除失败");
        }
    }
    
    NSLog(@"removeDownloadTmpFileWithUrl");
    NSString* fileName = [FileUtil getFileNameByUrl:urlStr];
    [self.resumeDataDic removeObjectForKey:fileName];
    [self.downloadTaskDic removeObjectForKey:urlStr];
}

-(void)tryAddLoadingTask:(NSURLSessionDownloadTask*) downloadTask
{
    NSString* downloadUrl = downloadTask.taskDescription;
    if(![self.downloadTaskDic.allKeys containsObject:downloadUrl])
    {
        DownloadTaskInfo* info = [self getTaskInfoWithUrl:downloadUrl fileName:NULL md5:NULL];
        self.downloadTaskDic[downloadUrl] = info;
        info.downloadTask = downloadTask;
        NSLog(@"add exsit download task:",downloadUrl);
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

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    //进度
    if(!self.started) {
        NSLog(@"download task description%@,%@",downloadTask.taskDescription,downloadTask);
        [self tryAddLoadingTask:downloadTask];
        return;
    };
    NSInteger currentTime = [self getCurrentSysTime];
    NSInteger deltaTime = currentTime - lastWriteDeltaTime;
    if( deltaTime > 300)
    {
        float progress = 1.0 * totalBytesWritten / totalBytesExpectedToWrite;
        long long deltaData = totalBytesWritten - lastWriteDeltaData;
        NSInteger speed = deltaData * 1000.0 /deltaTime;
        NSString* speedStr = [StringUtil humanReadableByteCount:speed];
        
        NSLog(@"download progress:%f,speed:%@",progress,speedStr);
        [self.processHandler downloadProgress:progress*100];
        lastWriteDeltaTime = currentTime;
        lastWriteDeltaData = totalBytesWritten;
//        NSLog(@"download task description%@,%@,%f",downloadTask.taskDescription,downloadTask,progress);
    }
}

-(void)allProcessDone
{
    [self.session invalidateAndCancel];
    self.session = NULL;
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(nonnull NSURL *)location {
    NSLog(@"didFinishDownloadingToURL");
    //移动文件到自己想要保存的路径下,location下的文件会被系统自动删除
    NSString* downloadUrl = downloadTask.taskDescription;
    
    if([self.downloadTaskDic.allKeys containsObject:downloadUrl])
    {
        DownloadTaskInfo* info = [self.downloadTaskDic objectForKey:downloadUrl];
        NSString* downloadFilePath = info.downloadFilePath;
        [self renameTempFile:location.path downloadFilePaht:downloadFilePath];
        
        if(![self hasDownloaded:downloadUrl md5:info.md5 fileName:info.fileName])
        {
            NSLog(@"verify md5 failure!!url:%@,md5:%@ localmd5:%@",downloadUrl,info.md5,[FileUtil fileMD5:downloadFilePath]);
            [FileUtil deleteFile:downloadFilePath];
            NSString* errorMsg = @"md5 verify failure!!!";
            int errorScope = 7;
            [self removeDownloadTmpFileWithUrl:downloadUrl];
            int responseCode = 0;
            if ([downloadTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
                responseCode =(int)[(NSHTTPURLResponse *)downloadTask.response statusCode];
            }
            [self.processHandler downloadFailure:errorScope errorMsg:errorMsg responseCode:responseCode];
            return;
        }
        [self removeDownloadTmpFileWithUrl:downloadUrl];
        [self.processHandler downloadComplete:downloadFilePath];
    }
    
}

#pragma mark - NSURLSessionTaskDelegate

-(void)URLSession:(nonnull NSURLSession *)session
             task:(nonnull NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    NSLog(@"didCompleteWithError");
    NSString* downloadUrl = task.taskDescription;
    if (error) {
        int errorScope = 0;
        if ([error.localizedDescription isEqualToString:@"cancelled"]) {
            errorScope = 4;
        }
        else if ([error.userInfo objectForKey:NSURLErrorBackgroundTaskCancelledReasonKey]) {
            errorScope = 8;
        }
        else
        {
            errorScope = error.code;
        }
        [self saveDownloadTmpFileWithResumeData:[error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData] url:downloadUrl];
   
        NSLog(@"error = %@", error);
        int responseCode = 0;
        if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
            responseCode =(int)[(NSHTTPURLResponse *)task.response statusCode];
        }
        if(self.started)
        {
            [self.downloadTaskDic removeObjectForKey:downloadUrl];
            [self.processHandler downloadFailure:errorScope errorMsg:error.localizedDescription responseCode:responseCode];
        }
    }
    [self.downloadTaskDic removeObjectForKey:downloadUrl];
    NSString* fileName = [FileUtil getFileNameByUrl:downloadUrl];
    [self.resumeDataDic removeObjectForKey:fileName];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSLog(@"所有任务下载完成后调用,URLSessionDidFinishEventsForBackgroundURLSession");
    //TODO invovl complete handler;
    if(NULL != self.completeHandler && allDone)
    {
        self.completeHandler();
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

-(DownloadTaskInfo*) getTaskInfoWithUrl:(NSString*)downloadUrl fileName:(NSString*)fileName md5:(NSString*)md5
{
    NSString* localFilePath = [FileUtil getDownloadFilePathByUrl:downloadUrl fileName:NULL downloadDirPath:self.downloadTargetPath];
    NSString* base64Url = [self encode:downloadUrl];
    DownloadTaskInfo* info = [DownloadTaskInfo alloc];
    info.downloadFilePath = localFilePath;
    info.downloadUrl = downloadUrl;
    info.md5 = md5;
    if(NULL == fileName)
    {
        fileName = [FileUtil getFileNameByUrl:downloadUrl];
    }
    info.fileName = fileName;
    return info;
}


-(void) renameTempFile:(NSString*)location downloadFilePaht:(NSString*)savePath
{
    NSError *saveError = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:savePath]) {
       [fileManager removeItemAtPath:savePath error:nil];
    }

    BOOL success = [fileManager moveItemAtPath:location toPath:savePath error:&saveError];
    if (success) {
       NSLog(@"文件下载完成,路径为 == %@", savePath);

    } else {
       NSLog(@"在转移文件时发生错误 %@", saveError);
    }
}

- (void)dealloc {
    [self.session invalidateAndCancel];
}

@end
