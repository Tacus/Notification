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
#import "QSThreadSafeMutableArray.h"
#import "Reachability_Zhang.h"
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <mach-o/loader.h>
@interface DownloadTaskInfo : NSObject
@property NSString* downloadUrl;
@property NSString* md5;
@property NSString* fileName;
@property NSString* downloadFilePath;
@property int64_t totalBytesWritten;
@property int64_t totalBytesExpectedToWrite;
@property NSURLSessionDownloadTask* downloadTask;
@property NSString* errorMsg;
@property NSInteger errorScope;
@property NSInteger responseCode;
@property NSUInteger tryCount;
@property int priority;
@end

@interface UnzipInfo : NSObject
@property NSString* zipFilePath;
@property NSUInteger unzipedCount;
@property NSUInteger unzipTotalCount;
@property int priority;
@end
static NSUInteger lastWriteDeltaData = 0;
static NSUInteger lastWriteDeltaTime = 0;

//cal speed
static NSUInteger lastSpeed = 0;
static NSUInteger lastSpeedTime = 0;

static NSUInteger lastUnzipDeltaTime = 0;
static NSUInteger maxUnzipSameTime = 1;
static NSUInteger maxDownloadTryCount = 1;
static int64_t totalSize = 0;
static int64_t completeSize = 0;
static Reachability_Zhang *hostReachability;
static NSInteger netTypeUserConfirm = -1;
static NSInteger currentNetType = -1;
@implementation DownloadTaskInfo
@end
@implementation UnzipInfo
@end
@interface DownloadTaskManager () <NSURLSessionDelegate, NSURLSessionDownloadDelegate,SSZipArchiveDelegate>
@property NSString* downloadTargetPath;
@property NSString* unzipTargetPath;
@property int totalUpdateNum;
@property id<ProcessHandler>processHandler;
@property BOOL started;
@property (nonatomic, strong) NSURLSession *session;
@property (atomic,strong) QSThreadSafeMutableArray* downloadList;
@property (atomic, strong) NSMutableDictionary *resumeDataDict;
@property (atomic, strong) NSMutableDictionary *downloadFailedDict;
@property (atomic, strong) QSThreadSafeMutableArray *unzipList;
@property (atomic, strong) QSThreadSafeMutableArray *unzipingList;
@property BOOL resumeDataClean;
@property NSLock* unzipLock;
@property NSLock* downloadListLock;
@property (atomic,strong) dispatch_queue_t resumeDataQueue;
@property (atomic,strong) dispatch_group_t resumeDataQueueGroup;
@end

@implementation DownloadTaskManager




static void _print_image(const struct mach_header *mh, bool added)
{
    Dl_info image_info;
    int result = dladdr(mh, &image_info);

    if (result == 0) {
        printf("Could not print info for mach_header: %p\n\n", mh);
        return;
    }

    const char *image_name = image_info.dli_fname;

    const intptr_t image_base_address = (intptr_t)image_info.dli_fbase;
//    const uint64_t image_text_size = _image_text_segment_size(mh);

//    char image_uuid[37];
//    const uuid_t *image_uuid_bytes = _image_retrieve_uuid(mh);
//    uuid_unparse(*image_uuid_bytes, image_uuid);

    const char *log = added ? "Added" : "Removed";
    printf("%s: 0x%02lx %s \n\n", log, image_base_address, image_name);
}

+ (void)load
{
    _dyld_register_func_for_add_image(&image_added);
    _dyld_register_func_for_remove_image(&image_removed);
}


static void image_added(const struct mach_header *mh, intptr_t slide)
{
    _print_image(mh, true);
    NSLog(@"image added !!!!!!!!!!!!!!!!!!!!!!!!!!!");
}

static void image_removed(const struct mach_header *mh, intptr_t slide)
{
    _print_image(mh, false);
    NSLog(@"image removed !!!!!!!!!!!!!!!!!!!!!!!!!!!");
}
+ (instancetype)shareManager {
    static DownloadTaskManager *downloadManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloadManager = [[self alloc] init];
    });
    
    return downloadManager;
}

- (instancetype)init
{
    if (self = [super init]) {
        _resumeDataDict = [NSMutableDictionary dictionary];
        _downloadFailedDict = [NSMutableDictionary dictionary];
        _unzipingList = [[QSThreadSafeMutableArray alloc]init];
        _unzipList = [[QSThreadSafeMutableArray alloc]init];
        _downloadList = [[QSThreadSafeMutableArray alloc] init] ;
        _unzipLock = [[NSLock alloc]init];
        _downloadListLock = [[NSLock alloc]init];
        //create serial queue
        _resumeDataQueue = dispatch_queue_create("resumeDataQueue", NULL);
        _resumeDataQueueGroup = dispatch_group_create();
    }
    
    [self initNetEnv];
    return self;
}

-(NSURLSession*)session
{
    if(NULL == _session)
    {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:[CommonUtil getBundleID]];
        configuration.timeoutIntervalForRequest = 300;
        if(netTypeUserConfirm == ReachableViaWWAN)
        {
            configuration.allowsCellularAccess = YES;
        }
        else
        {
            configuration.allowsCellularAccess = YES;
        }
        configuration.discretionary = false;
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:queue];
        totalSize = 0;
        completeSize = 0;
        NSLog(@"init session");
    }
    return _session;
}

- (void)resumeDownload
{
    NSLog(@"resumeDownload");
    if(NULL == _session)
    {
        NSLog(@"Session invalid!");
        return;
    }
    [self.downloadListLock lock];
    if(self.downloadList.count == 0)
    {
        [self.downloadListLock unlock];
        return;
    }
//    DownloadTaskInfo* info = self.downloadList[0];
//    [info.downloadTask resume];
    NSArray* array = [self.downloadList mutableCopy];
    [self.downloadListLock unlock];
    for (DownloadTaskInfo* info in array)
    {
        if(NULL != info.downloadTask)
        {
            [info.downloadTask resume];
        }
    }
    [self initNetEnv];
}


-(void)Clear
{
    self.resumeDataClean = FALSE;
    [_resumeDataDict removeAllObjects];
    [_downloadFailedDict removeAllObjects];
    [_unzipingList removeAllObjects];
    [_unzipList removeAllObjects];
    [_downloadList removeAllObjects];
}

- (void) InitDownload:(NSString*)downloadDir unzipDirPath:(NSString*)unzipDirPath totalDownloadCount:(int) totalDownloadCount
{
    NSLog(@"InitDownload");
    NSString *homePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    self.downloadTargetPath = [homePath stringByAppendingPathComponent:downloadDir];
    [FileUtil createDirRecurse: self.downloadTargetPath];
    self.unzipTargetPath = homePath;
    [FileUtil createDirRecurse: self.unzipTargetPath];
    self.totalUpdateNum = totalDownloadCount;
    if(self.session)
    {
        
    }
    
    self.started = false;
}

-(void)initNetEnv
{
    if(NULL != hostReachability)
    {
        [hostReachability stopNotifier];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification_zhang object:nil];
    NSString *remoteHostName = @"www.apple.com";
    hostReachability = [Reachability_Zhang reachabilityWithHostName:remoteHostName];
    [hostReachability startNotifier];
    [self updateInterfaceWithReachability:hostReachability];
}
//
//- (void)StartDownload:(NSString*)downloadUrl md5:(NSString*)md5  fileName:(NSString*)fileName fileSize:(int64_t)fileSize
//         delayInMills:(int)delayInMills  priority:(int)priority
//{
//    NSLog(@"StartDownload url:%@ md5 %@:fileName %@:filesize:%lld delayInMills:%d",downloadUrl,md5,fileName,fileSize,delayInMills);
//    self.started = true;
//    if (![self checkIsUrlAtString:downloadUrl]) {
//        NSLog(@"无效的下载地址===%@", downloadUrl);
//        return;
//    }
//
//    NSString* localFilePath = [FileUtil getDownloadFilePathByUrl:downloadUrl fileName:fileName downloadDirPath:self.downloadTargetPath];
//    BOOL ret = [self hasDownloaded:downloadUrl md5:md5 fileName:fileName];
//    if(ret)
//    {
//        [self.processHandler downloadComplete:downloadUrl downloadedFilePath:localFilePath];
//        [self StartUnzip:localFilePath priority:priority];
//        return;
//    }
//
//    DownloadTaskInfo* info = [self HasAddedDownloadList:downloadUrl];
//    if(NULL != info)
//    {
//        info.md5 = md5;
//        NSLog(@"already exsit downloadUrl:%@",downloadUrl);
//        return;
//    }
//
//    info = [self getTaskInfoWithUrl:downloadUrl fileName:fileName md5:md5 fileSize:fileSize priority:priority];
//    [self.downloadList addObject:info];
//
//    if(0 == delayInMills)
//    {
//        [self activeDownloadSessionTaskWithUrl:downloadUrl];
//    }
//    else
//    {
//        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInMills * NSEC_PER_MSEC));
//        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//            [self activeDownloadSessionTaskWithUrl:downloadUrl];
//        });
//    }
//}

- (void)AddDownload:(NSString*)downloadUrl md5:(NSString*)md5  fileName:(NSString*)fileName fileSize:(int64_t)fileSize
       delayInMills:(int)delayInMills  priority:(int)priority
{
    NSLog(@"AddDownload url:%@ md5 %@:fileName %@:filesize:%lld delayInMills:%d",
          downloadUrl,md5,fileName,fileSize,delayInMills);
    if (![self checkIsUrlAtString:downloadUrl]) {
        NSLog(@"无效的下载地址===%@", downloadUrl);
        return;
    }
    
    NSString* localFilePath = [FileUtil getDownloadFilePathByUrl:downloadUrl fileName:fileName downloadDirPath:self.downloadTargetPath];
    BOOL ret = [self hasDownloaded:downloadUrl md5:md5 fileName:fileName];
    if(ret)
    {
        [self.processHandler downloadComplete:downloadUrl downloadedFilePath:localFilePath];
        [self StartUnzip:localFilePath priority:priority];
        NSLog(@"已经下载完成:%@", localFilePath);
        return;
    }
    
    DownloadTaskInfo* info = [self HasAddedDownloadList:downloadUrl];
    if(NULL != info)
    {
        info.md5 = md5;
        info.priority = priority;
        info.totalBytesExpectedToWrite = fileSize;
        NSLog(@"already exsit downloadUrl:%@",downloadUrl);
        return;
    }
    
    info = [self getTaskInfoWithUrl:downloadUrl fileName:fileName md5:md5 fileSize:fileSize priority:priority];
    self.resumeDataClean = FALSE;
    [self intResumeDataDict];
    [self.downloadListLock lock];
    [self.downloadList addObject:info];
    [self.downloadListLock unlock];
}

-(void)AddReDownloadInfo:(DownloadTaskInfo*)info delayInMills:(int)delayInMills
{
    NSLog(@"AddDownload:delayInMills url:%@ trycount:%ld",info.downloadUrl,(unsigned long)info.tryCount);
    info.tryCount++;
    
    if(NULL != [self HasAddedDownloadList:info.downloadUrl])
    {
        NSLog(@"already exsit downloadUrl:%@",info.downloadUrl);
        return;
    }
    [self.downloadListLock lock];
    [self.downloadList addObject:info];
    [self.downloadListLock unlock];
}

-(void)Start
{
    if(0 == self.downloadList.count)
    {
        [self.processHandler downloadDone:@""];
        return;
    }
    if(self.session)
    {
        
    }
    netTypeUserConfirm = currentNetType;
    self.started = true;
    totalSize = 0;
    completeSize = 0;
    [self.downloadListLock lock];
    NSArray* array = [self.downloadList mutableCopy];
    [self.downloadListLock unlock];
    for (DownloadTaskInfo* info in array)
    {
        totalSize += info.totalBytesExpectedToWrite;
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
        [self.downloadFailedDict removeAllObjects];
        [self Start];
    }
}

-(void)CheckAllDownloadDone
{
    if(self.downloadList.count > 0)
    {
        return;
    }
    NSUInteger count = self.downloadFailedDict.count;
    if( count > 0)
    {
        for (NSString*key in [self.downloadFailedDict allKeys])
        {
            DownloadTaskInfo* info = self.downloadFailedDict[key];
            if(info.tryCount < maxDownloadTryCount)
            {
                NSLog(@"reDownload addDownloadInfo downloadUrl:%@,try count:%lu",info.downloadUrl,(unsigned long)info.tryCount);
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
            NSLog(@"剩余下%lu个下载重试%lu次依然未能成功!",((unsigned long)leftCount),(unsigned long)maxDownloadTryCount);
//            for (NSString*key in [self.downloadFailedDict allKeys])
//            {
//                DownloadTaskInfo* info = self.downloadFailedDict[key];
//                NSLog(@"%@ exceed max limit try count!count:%lu",info.downloadUrl,((unsigned long)info.tryCount));
//            }
            [self AllDownloadDone];
        }
        else
        {
            NSLog(@"剩余下%ld个下载重试%lu次依然未能成功! 正在重试%lu个之前下载失败的文件！",((unsigned long)leftCount),(unsigned long)maxDownloadTryCount,((unsigned long)(count - leftCount)));
        }
    }
    else
    {
        [self AllDownloadDone];
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
    UnzipInfo* exsitInfo = [self HasAddedUnzipList:zipFilePath List:self.unzipingList];
    if(NULL != exsitInfo)
    {
        exsitInfo.unzipedCount = totalFileWriten;
        exsitInfo.unzipTotalCount = totalFileExpectedWriten;
    }
    long writed = 0;
    long total = 0;
    
    for (UnzipInfo* info in self.unzipingList)
    {
        writed += info.unzipedCount;
        total += info.unzipTotalCount;
    }
    
    return 1.0*writed/total;
}

-(void)unzipProgress:(NSString *)zipFilePath entryNumber:(long) entryNumber total:(long) total
{
    NSUInteger currentTime = [self getCurrentSysTime];
    if(currentTime - lastUnzipDeltaTime > 100)
    {
        double progress = [self CalUnzipProgress:zipFilePath totalFileWriten:entryNumber totalFileExpectedWriten:total];
        if(progress > 1.0)
        {
            progress = 1.0;
        }
        [self.processHandler unzipProgress:zipFilePath progress:progress*100];
        lastUnzipDeltaTime = currentTime;
//        NSLog(@"unzip path:%@,progress:%f",zipFilePath,progress);
    }
}

-(void)unzipComplete:(NSString *)path succeeded:(BOOL) succeeded error:(NSError*) error
{
    NSLog(@"unzipComplete path:%@,error:%@",path,error);
    if(NULL != path)
    {
        [self RemoveUnzipInfoFromList:path List:self.unzipingList];
    }
    
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
    
    if(0 == self.unzipingList.count && 0 == self.downloadList.count && 0 == self.downloadFailedDict.count)
    {
        [self.processHandler unzipDone];
        NSLog(@"下载列表，解压列表为空！且终失败列表大小：%lu",((unsigned long)self.downloadFailedDict.count));
    }
}

- (void)NextUnzipStart
{
    [self.unzipLock lock];
    int index = 0;
    NSLog(@"NextUnzipStart unzipingDict:%lu,unzipList:%lu",(unsigned long)self.unzipingList.count,(unsigned long)self.unzipList.count);
    while(maxUnzipSameTime > self.unzipingList.count && 0 < self.unzipList.count)
    {
        UnzipInfo* unzipInfo = self.unzipList[index++];
        if([self HasHigherPriorityToBeUnzip:unzipInfo])
        {
            [self.unzipLock unlock];
            return;
        }
        [self RemoveUnzipInfoFromList:unzipInfo.zipFilePath List:self.unzipList];
        [self.unzipingList addObject:unzipInfo];
//        self.unzipingDict[unzipInfo.zipFilePath] = unzipInfo;
        NSLog(@"NextUnzipStart：%@",unzipInfo.zipFilePath);
        [self StartUnzipProcess:unzipInfo.zipFilePath];
    }
    [self.unzipLock unlock];
}

-(BOOL)HasHigherPriorityToBeUnzip:(UnzipInfo*)info
{
    [self.downloadListLock lock];
    NSArray* array = [self.downloadList mutableCopy];
    [self.downloadListLock unlock];
    for (DownloadTaskInfo* downloadInfo in array) {
        if(downloadInfo.priority < info.priority)
        {
            return TRUE;
        }
    }
       
    for (NSString* key in self.downloadFailedDict.allKeys) {
        DownloadTaskInfo* downloadInfo = [self.downloadFailedDict objectForKey:key];
        if(NULL != downloadInfo && downloadInfo.priority < info.priority)
        {
            return TRUE;
        }
            
    }
    return FALSE;
}

-(void)StartUnzip:(NSString*) zipFilePath priority:(int)priority
{
    NSLog(@"StartUnzip：%@",zipFilePath);
    if(NULL != [self HasAddedUnzipList:zipFilePath List:self.unzipList] || NULL != [self HasAddedUnzipList:zipFilePath List:self.unzipingList])
    {
        NSLog(@"StartUnzip is unziping：%@",zipFilePath);
        return;
    }
    [self.unzipList addObject:[self GetUnzipInfo:zipFilePath priority:priority]];

    NSArray* array = [self.unzipList sortedArrayUsingComparator:^NSComparisonResult(UnzipInfo* obj1, UnzipInfo* obj2) {
        //这里的代码可以参照上面compare:默认的排序方法，也可以把自定义的方法写在这里，给对象排序
        NSComparisonResult result = obj1.priority > obj2.priority;
        return result;
    }];
    QSThreadSafeMutableArray* temp = [[QSThreadSafeMutableArray alloc] init];
    for (UnzipInfo* info in array) {
        [temp addObject:info];
    }
    self.unzipList = temp;
    
    for (UnzipInfo* info in self.unzipList) {
        NSLog(@"StartUnzip url:%@, priority %d",info.zipFilePath,info.priority);
    }
    [self NextUnzipStart];
}


//+ (BOOL)unzipFileAtPath:(NSString *)path
//          toDestination:(NSString *)destination
//     preserveAttributes:(BOOL)preserveAttributes
//              overwrite:(BOOL)overwrite
//         nestedZipLevel:(NSInteger)nestedZipLevel
//               password:(nullable NSString *)password
//                  error:(NSError **)error
//               delegate:(nullable id<SSZipArchiveDelegate>)delegate
//        progressHandler:(void (^_Nullable)(NSString *entry, unz_file_info zipInfo, long entryNumber, long total))progressHandler
//      completionHandler:(void (^_Nullable)(NSString *path, BOOL succeeded, NSError * _Nullable error))completionHandler;


- (void)StartUnzipProcess:(NSString*)zipFilePath
{
    NSLog(@"StartUnzipProcess：%@",zipFilePath);
    __weak typeof(self) weakSelf = self;
    dispatch_queue_t groupQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(groupQueue,^{
        [SSZipArchive unzipFileAtPath:zipFilePath
                        toDestination:self.unzipTargetPath
                   preserveAttributes:NO
                            overwrite:YES
                       nestedZipLevel:0
                             password:nil
                                error:nil
                             delegate:nil
                      progressHandler:^(NSString *entry, unz_file_info zipInfo, long entryNumber, long total)
        {
            [weakSelf unzipProgress:zipFilePath entryNumber:entryNumber total:total];
        }
                    completionHandler:^(NSString *path, BOOL succeeded, NSError * _Nullable error)
        {
            [weakSelf unzipComplete:path succeeded:succeeded error:error];
            
        }];
    });
}

-(UnzipInfo*)GetUnzipInfo:(NSString*)unzipFilePath priority:(int)priority
{
    UnzipInfo* info = [[UnzipInfo alloc] init];
    info.zipFilePath = unzipFilePath;
    info.priority = priority;
    return info;
}

#pragma mark - Private

-(void)intResumeDataDict
{
    if(!self.resumeDataClean)
    {
        for (NSString *filePath in [self getResumeDataFilePathArray]) {
            //判断如果沙盒中有文件的resumeData数据,则把它存储到resumeDataDic中,用resumeData开启downloadTask
            NSString *fileName = [[filePath lastPathComponent] stringByDeletingPathExtension];
//            dispatch_queue_t groupQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_group_async(self.resumeDataQueueGroup,self.resumeDataQueue,  ^{
                NSData *resumeData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:nil];
                [self.resumeDataDict setValue:resumeData forKey:fileName];
            });
        }
        self.resumeDataClean = TRUE;
    }
}

- (void)activeDownloadSessionTaskWithUrl:(NSString *)urlStr {
    dispatch_group_notify(self.resumeDataQueueGroup,self.resumeDataQueue,^(){
//        NSLog(@"resumeDataDict:%@",self.resumeDataDict.allKeys);
        NSString* fileName = [FileUtil getFileNameByUrl:urlStr];
        NSURLSessionDownloadTask *downloadTask = nil;
        NSLog(@"activeDownloadSessionTaskWithUrl%@",self.resumeDataDict.allKeys);
        if ([self.resumeDataDict.allKeys containsObject:fileName]) {
            downloadTask = [self.session downloadTaskWithResumeData:self.resumeDataDict[fileName]];
            NSLog(@"continue download:%@",urlStr);
        } else {
            downloadTask = [self.session downloadTaskWithURL:[NSURL URLWithString:urlStr]];
            NSLog(@"new download:%@",urlStr);
        }
        
        downloadTask.taskDescription = urlStr;
        DownloadTaskInfo* info = [self HasAddedDownloadList:urlStr];
        info.downloadTask = downloadTask;
        [downloadTask resume];
        NSLog(@"downloadTask = %@", downloadTask);
    });
}

- (void)cancelDownloadWithUrl:(NSString *)urlStr andRemoveOrNot:(BOOL)isRemove {
 
//    if (![self.downloadTaskDict.allKeys containsObject:urlStr]) {
//        return;
//    }
//
//    NSString* fileName = [FileUtil getFileNameByUrl:urlStr];
//    DownloadTaskInfo* info =[self.downloadTaskDict objectForKey:urlStr];
//    if(NULL == info.downloadTask)
//    {
//        return;
//    }
//
//    NSURLSessionDownloadTask *downloadTask = info.downloadTask;
//
//    [downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
//        self.resumeDataDict[fileName] = resumeData;
//        if (!isRemove) {
//            [self saveDownloadTmpFileWithResumeData:resumeData url:urlStr];
//        } else {
//            [self removeDownloadTmpFileWithUrl:urlStr];
//        }
////#warning 开启等待下载的任务
//    }];
}

//保存下载过程中的resumeData
- (void)saveDownloadTmpFileWithResumeData:(NSData *)resumeData url:(NSString *)urlStr {
    NSLog(@"保存resume data");
//    NSString *base64Url = [self encode:urlStr];
    [resumeData writeToFile:[self getTmpPathWithUrl:urlStr] atomically:YES];
//    self.resumeDataClean = FALSE;
    NSString* fileName = [FileUtil getFileNameByUrl:urlStr];
//    if([self.resumeDataDict.allKeys containsObject:fileName])
//    {
        [self.resumeDataDict setValue:resumeData forKey:fileName];
//    }
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
    NSLog(@"tryAddLoadingTask%@:",downloadUrl);
    DownloadTaskInfo* info = [self HasAddedDownloadList:downloadUrl];
    if(NULL == info)
    {
        DownloadTaskInfo* info = [self getTaskInfoWithUrl:downloadUrl fileName:NULL md5:NULL fileSize:0 priority:0];
        [self.downloadListLock lock];
        [self.downloadList addObject:info];
        [self.downloadListLock unlock];
        info.downloadTask = downloadTask;
        info.totalBytesWritten = totalBytesWritten;
        info.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
        totalSize += totalBytesExpectedToWrite;
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
//        NSLog(@"%@本地推送 :( 报错 %@",identifier,error);
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
    DownloadTaskInfo* info = [self HasAddedDownloadList:downloadUrl];
    if(NULL != info)
    {
        info.totalBytesWritten = totalBytesWritten;
        info.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    }
    int64_t writed = 0;
    NSLog(@"downloadUrl:%@,writed:%lld,CalProgress:%lld",downloadUrl,totalBytesWritten,totalBytesExpectedToWrite);
    [self.downloadListLock lock];
    NSArray* array = [self.downloadList mutableCopy];
    [self.downloadListLock unlock];
    for (DownloadTaskInfo* info in array)
    {
        writed += info.totalBytesWritten;
    }
    
    return 1.0*(writed+completeSize)/totalSize;
}

-(void)AddFailureDownload:(DownloadTaskInfo*)info
{
    NSLog(@"AddFailureDownload:%@",info.downloadUrl);
    if(![self.downloadFailedDict.allKeys containsObject:info.downloadUrl])
    {
        info.downloadTask = NULL;
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

-(void)Notify:(NSString*)content
{
    dispatch_async(dispatch_get_main_queue(), ^{  //需要执行的方法
       if([self appISBackground])
       {
           [self pushNotification_IOS_10_Body:content];
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
    
    if(0 < self.downloadFailedDict.count)
    {
        [self Notify:[CommonUtil getPartialFailureDownloadTip]];
        NSString* errorTip = NULL;
        for (NSString* key in self.downloadFailedDict) {
            DownloadTaskInfo* info = self.downloadFailedDict[key];
            errorTip = [NSString stringWithFormat:@"errorMsg&:&%@|&$|errorScope&:&%ld|&$|responseCode&:&%ld|&$|downloadUrl&:&%@",info.errorMsg,(long)info.errorScope,(long)info.responseCode,info.downloadUrl];
            NSLog(@"AllDownloadDone errorTip:%@",errorTip);
            break;
        }
        [self.processHandler downloadDone:errorTip];
    }
    else
    {
        [self Notify:[CommonUtil getDownloadTip]];
        [self.processHandler downloadProgress:@"" progress:100 speed:@""];
        [self.processHandler downloadDone:@""];
    }
}

-(DownloadTaskInfo*)HasAddedDownloadList:(NSString*)downloadUrl
{
    [self.downloadListLock lock];
    NSArray* array = [self.downloadList mutableCopy];
    [self.downloadListLock unlock];
    for (DownloadTaskInfo* info in array) {
        if([info.downloadUrl isEqualToString:downloadUrl])
        {
            return info;
        }
    }
    return NULL;
}

-(void)RemoveDownloadInfo:(NSString*)downloadUrl
{
    NSLog(@"RemoveDownloadInfo:%@",downloadUrl);
    DownloadTaskInfo* info = [self HasAddedDownloadList:downloadUrl];
    if(NULL == info) return;
    [self.downloadListLock lock];
    [self.downloadList removeObject:info];
    [self.downloadListLock unlock];
}

-(UnzipInfo*)HasAddedUnzipList:(NSString*)zipFilePath List:(QSThreadSafeMutableArray*)array
{
    for (UnzipInfo* info in array) {
        if([info.zipFilePath isEqualToString:zipFilePath])
        {
            return info;
        }
    }
    return NULL;
}

-(void)RemoveUnzipInfoFromList:(NSString*)zipFilePath List:(QSThreadSafeMutableArray*)array
{
    for (UnzipInfo* info in array) {
        if([info.zipFilePath isEqualToString:zipFilePath])
        {
            [array removeObject:info];
            return;
        }
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
//        NSLog(@"download task description%@,%@",downloadTask.taskDescription,downloadTask);
        [self tryAddLoadingTask:downloadTask totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
        return;
    };
    NSInteger currentTime = [self getCurrentSysTime];
    NSInteger deltaTime = currentTime - lastWriteDeltaTime;
    lastWriteDeltaData += bytesWritten;
    if( deltaTime > 300)
    {
        float progress = [self CalProgress:downloadTask.taskDescription totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
       
        if(progress >1.0)
        {
            progress = 1.0;
        }
        lastWriteDeltaTime = currentTime;
        long speedDelta = currentTime - lastSpeedTime;
        if(speedDelta > 2000)
        {
            lastSpeed = lastWriteDeltaData * 1000.0 /speedDelta;
            lastSpeedTime = currentTime;
            lastWriteDeltaData = 0;
        }
        
        NSString* speedStr = [StringUtil humanReadableByteCount:lastSpeed];
        [self.processHandler downloadProgress:downloadTask.taskDescription progress:progress*100 speed:speedStr];
    }
}

-(void)DownloadComplete:(NSString*)downloadUrl
{
    DownloadTaskInfo* info = [self HasAddedDownloadList:downloadUrl];
    if(NULL != info)
    {
        [self RemoveDownloadInfo:downloadUrl];
        completeSize += info.totalBytesExpectedToWrite;
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

    NSString* downloadUrl = downloadTask.taskDescription;
    NSLog(@"didFinishDownloadingToURL URL:%@",downloadUrl);
    DownloadTaskInfo* info = [self HasAddedDownloadList:downloadUrl];
    int responseCode = -1;
    int errorScope = -1;
    if ([downloadTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
        responseCode =(int)[(NSHTTPURLResponse *)downloadTask.response statusCode];
    }
    if(NULL != info)
    {
        [self DownloadComplete:downloadUrl];
        NSString* errorMsg = NULL;
        NSString* downloadFilePath = info.downloadFilePath;
        
        if(responseCode == 200 || responseCode == 206)
        {
            NSString* moveError = [self renameTempFile:location.path destPath:downloadFilePath];
            
            if(NULL == moveError)
            {
                [self removeDownloadTmpFileWithUrl:downloadUrl];
                if(![self hasDownloaded:downloadUrl md5:info.md5 fileName:info.fileName])
                {
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
        }
        else
        {
            errorMsg = @"response not ok";
            errorScope = 6;
        }

        if(!self.started)
        {
            return;
        }
        
        if(NULL == errorMsg)
        {
            [self.processHandler downloadComplete:info.downloadUrl downloadedFilePath:downloadFilePath];
            [self StartUnzip:downloadFilePath priority:info.priority];
        }
        else
        {
            
            info.errorMsg = errorMsg;
            info.errorScope = errorScope;
            info.responseCode = responseCode;
            info.tryCount = maxDownloadTryCount;
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
        
//    });
    
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
    NSString* downloadUrl = task.taskDescription;
    NSLog(@"didCompleteWithError downloadUrl:%@",downloadUrl);
    DownloadTaskInfo* info = [self HasAddedDownloadList:downloadUrl];
    if (NULL != error && NULL != info)
    {
        int errorScope = -1;
        if ([error.localizedDescription isEqualToString:@"cancelled"]) {
            if([self isWifiChToCellular])
            {
                errorScope = 10;
            }
            else if(NotReachable == currentNetType)
            {
                errorScope = 11;
            }
            else
            {
                errorScope = 4;
            }

            info.tryCount = maxDownloadTryCount;
            NSLog(@"user cancel task");
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

    if(!self.started) return;
    [self DownloadComplete:downloadUrl];
    [self CheckAllDownloadDone];
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
    if(!self.started)
    {
        return;
    }
//    [self CheckAllDownloadDone];
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


- (NSMutableArray *)getResumeDataFilePathArray {
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
        NSLog(@"file not exsit!(%@)",localFilePath);
        return FALSE;
    }
    if(![NSString isBlankString:md5])
    {
        NSString* localMd5 = [FileUtil fileMD5:localFilePath];
        if(![localMd5 isEqualToString:md5])
        {
            NSLog(@"file exsit! but md5 not equal .local md5:%@ server md5:%@",localMd5,md5);
            [fileManager removeItemAtPath:localFilePath error:NULL];
            return FALSE;
        }
    }
    return TRUE;
}

-(DownloadTaskInfo*) getTaskInfoWithUrl:(NSString*)downloadUrl fileName:(NSString*)fileName md5:(NSString*)md5 fileSize:(int64_t)fileSize priority:(int)priority
{
    NSString* localFilePath = [FileUtil getDownloadFilePathByUrl:downloadUrl fileName:NULL downloadDirPath:self.downloadTargetPath];
    DownloadTaskInfo* info = [DownloadTaskInfo alloc];
    info.downloadFilePath = localFilePath;
    info.downloadUrl = downloadUrl;
    info.md5 = md5;
    info.totalBytesExpectedToWrite = fileSize;
    info.tryCount = 0;
    info.priority = priority;
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification_zhang object:nil];
}

- (void) reachabilityChanged:(NSNotification *)note
{
    Reachability_Zhang* curReach = [note object];
    NSParameterAssert([curReach isKindOfClass:[Reachability_Zhang class]]);
    [self updateInterfaceWithReachability:curReach];
    
}

- (void)updateInterfaceWithReachability:(Reachability_Zhang *)reachability
{
    if (reachability == hostReachability)
    {
        BOOL connectionRequired = [reachability connectionRequired];
        currentNetType = [reachability currentReachabilityStatus];
        switch (currentNetType)
        {
            case NotReachable:
            {
                NSLog(@"当前无网络");
                connectionRequired = NO;
                break;
            }
            case ReachableViaWWAN:
            {
                NSLog(@"当前移动网络");
                break;
            }
            case ReachableViaWiFi:
            {
                NSLog(@"当前wifi环境");
                break;
            }
        }
        NSLog(@"isWifiChToCellular:%hhd",[self isWifiChToCellular]);
        if(TRUE == [self isWifiChToCellular])
        {
            [self CancelAllDownload];
        }
        else if(NotReachable == currentNetType)
        {
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5000 * NSEC_PER_MSEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                if(NotReachable == currentNetType)
                {
                    [self CancelAllDownload];
                }
            });
        }
    }
}

-(void)CancelAllDownload
{
    [self.downloadListLock lock];
    NSArray* array = [self.downloadList mutableCopy];
    [self.downloadListLock unlock];
    if(0 == array.count) return;
    for (DownloadTaskInfo* info in array) {
        NSLog(@"cancel CancelAllDownload url:%@",info.downloadUrl);
        if(NULL != info.downloadTask)
        {
            [info.downloadTask cancelByProducingResumeData:^(NSData* resumeDate){
                NSLog(@"cancel allDownload url:%@",info.downloadUrl);
                [self saveDownloadTmpFileWithResumeData:resumeDate url:info.downloadUrl];
            }];
            info.downloadTask = NULL;
        }
    }
   
    if(NULL != _session)
    {
        [self.session invalidateAndCancel];
    }
    self.session = NULL;
}

-(BOOL)isWifiChToCellular
{
    if(netTypeUserConfirm == ReachableViaWiFi && currentNetType == ReachableViaWWAN)
    {
        return TRUE;
    }
    return FALSE;
}

@end
