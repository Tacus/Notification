//
//  DownloadTask.cpp
//  Notification
//
//  Created by spr on 2021/3/2.
//

#include "DownloadTask.h"
#import "FileUtil.h"



//You must check whether user has an internet connection available
//Make sure you have the right permissions (INTERNET and WRITE_EXTERNAL_STORAGE);
//also ACCESS_NETWORK_STATE if you want to check internet availability.
//Make sure the directory were you are going to download files exist and has write permissions.
//If download is too big you may want to implement a way to resume the download if previous attempts failed.
//Users will be grateful if you allow them to interrupt the download.
//Unless you need detailed control of the download process, then consider using DownloadManager
//(3) because it already handles most of the items listed above.
//
//But also consider that your needs may change. For example,
//DownloadManager does no response caching. It will blindly download the same big file multiple times.
//There's no easy way to fix it after the fact. Where if you start with a basic HttpURLConnection (1, 2),
//then all you need is to add an HttpResponseCache. So the initial effort of learning the basic,
//standard tools can be a good investment.


//TODO 考虑使用线程池

@interface DownloadTask()<NSURLSessionDelegate, NSURLSessionDownloadDelegate>

@property NSURLSessionDownloadTask* task;
@property NSFileHandle* fileHandle;
@property long lastDownloadedSize;
@property NSOutputStream* outStream;

/***********文件下载需要的属性*************/
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary *downloadTaskDic;
@property (nonatomic, strong) NSMutableDictionary *resumeDataDic;//保存在沙盒中的resumeData
@property (nonatomic, assign) NSInteger currentCount;

@end

@implementation DownloadTask


-(instancetype)initWithUrl:(NSString*) url md5Str:(NSString*) md5Str downloadDirPath:(NSString*) downloadDirPath name:(NSString*) name downloadHandler:(id<ProcessHandler>) downloadHandler session:(NSURLSession*)session
{
    if(self = [super init])
    {
        self.downloadUrl = url;
        self.md5Str = md5Str;
        self.downloadDirPath = downloadDirPath;
        self.downloadHandler = downloadHandler;
        [self setDownloadFileName:url fileName:name];
        self.stopFlag = NO;
        self.session = session;
    }
    return self;
}

-(void) setDownloadFileName:(NSString*) url fileName:(NSString*) fileName
{
    self.downloadFilePath = [FileUtil getDownloadFilePathByUrl:url fileName:fileName downloadDirPath:self.downloadDirPath];
    self.downloadFileTempPath = [FileUtil getDownloadTempFile:self.downloadFilePath];
}

-(void)startProcess
{
    [super startProcess];
    [self.task resume];
    [self.session finishTasksAndInvalidate];
}

-(NSURLSessionDownloadTask*)task
{
    if(NULL == _task)
    {
        NSURL* url = [NSURL URLWithString:self.downloadUrl];
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
        [self configRequest:request];
        _task = [self.session downloadTaskWithRequest:request];
        
    }
    return _task;
}

-(void)configRequest:(NSMutableURLRequest*)request
{
#pragma mark    setRequest head
    unsigned long fileSize = [FileUtil getExistLen:self.downloadFileTempPath];
    self.downloadedSize = fileSize;
    NSString* range = [NSString stringWithFormat:@"bytes=%zd-",fileSize];
    [request setValue:range forHTTPHeaderField:@"Range"];
}

//#pragma mark  NSUrlSessionDataDelegate start
//- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
//                                 didReceiveResponse:(NSURLResponse *)response
//                                  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
//{
//    if(NULL == response)
//    {
////        completionHandler(NSURLSessionResponseCancel);
//        self.errorMsg = @"response null";
//        self.errorScope = -1;
//        self.responseCode = -1;
//        NSLog(@"response is null");
//        [self downloadFailure];
//        return;
//    }
//    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
//        self.responseCode = (int)[(NSHTTPURLResponse *)response statusCode];
//    }
//    long len = [response expectedContentLength];//存储一共要传输的数据长度
//    if ( len >= 0)
//    {
//
//        self.totalFileSize = [response expectedContentLength] + self.downloadedSize;
//        NSFileManager* fileManager = [NSFileManager defaultManager];
//        if(![fileManager fileExistsAtPath:self.downloadFileTempPath])
//        {
//            NSLog(@"create tempfilePath:%@",self.downloadFileTempPath);
//            [fileManager createFileAtPath:self.downloadFileTempPath contents:NULL attributes:NULL];
//        }
//        NSLog(@"downloadfileTempPath:%@",self.downloadFileTempPath);
//        self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.downloadFileTempPath];
////        self.outStream = [[NSOutputStream alloc] initToFileAtPath:self.downloadFileTempPath append:YES];
////        [self.outStream open];
//        [self progress];
//        completionHandler(NSURLSessionResponseAllow);
//        NSLog(@"didReceiveResponse,totalsize:%ld,downloadedSize:%ld",self.totalFileSize,self.downloadedSize);
//    }
//    else
//    {
//        completionHandler(NSURLSessionResponseCancel);//如果Response里不包括数据长度的信息，就取消数据传输
//        self.errorScope = 1;
//        self.errorMsg = @"content len negative";
//        NSLog(self.errorMsg);
//        [self downloadFailure];
//    }
//}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    //进度
//    float progress = 1.0 * totalBytesWritten / totalBytesExpectedToWrite;
    self.totalFileSize = totalBytesExpectedToWrite;
    self.downloadedSize = bytesWritten;
    [self progress];
}
//
//- (void)URLSession:(NSURLSession *)session
//      downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask
//didFinishDownloadingToURL:(nonnull NSURL *)location {
//    //移动文件到自己想要保存的路径下,location下的文件会被系统自动删除
//    NSError *saveError = nil;
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//    NSString *savePath = [self savePathWithUrl:downloadTask.taskDescription];
//    if ([fileManager fileExistsAtPath:savePath]) {
//        [fileManager removeItemAtPath:savePath error:nil];
//    }
//    BOOL success = [fileManager moveItemAtPath:location.path toPath:savePath error:&saveError];
//    if (success) {
//        NSLog(@"文件下载完成,路径为 == %@", savePath);
//        self.downloadSuccessBlock([NSURL URLWithString:savePath]);
//        //删除之前保存的用来断点续传的resumeData
//        [self removeDownloadTmpFileWithUrl:downloadTask.taskDescription];
//    } else {
//        NSLog(@"在转移文件时发生错误 %@", saveError);
//    }
//}

/* Notification that a data task has become a download task.  No
 * future messages will be sent to the data task.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                              didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
{
    NSLog(@"didBecomeDownloadTask");
}

/*
 * Notification that a data task has become a bidirectional stream
 * task.  No future messages will be sent to the data task.  The newly
 * created streamTask will carry the original request and response as
 * properties.
 *
 * For requests that were pipelined, the stream object will only allow
 * reading, and the object will immediately issue a
 * -URLSession:writeClosedForStream:.  Pipelining can be disabled for
 * all requests in a session, or by the NSURLRequest
 * HTTPShouldUsePipelining property.
 *
 * The underlying connection is no longer considered part of the HTTP
 * connection cache and won't count against the total number of
 * connections per host.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                didBecomeStreamTask:(NSURLSessionStreamTask *)streamTask
    API_AVAILABLE(macos(10.11), ios(9.0), watchos(2.0), tvos(9.0))
{
    NSLog(@"didBecomeStreamTask");
}

/* Sent when data is available for the delegate to consume.  It is
 * assumed that the delegate will retain and not copy the data.  As
 * the data may be discontiguous, you should use
 * [NSData enumerateByteRangesUsingBlock:] to access it.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                     didReceiveData:(NSData *)data
{
//    [self.outStream write:data.bytes maxLength:data.length];
    [self.fileHandle writeData:data];
    self.downloadedSize += data.length;
    [self progress];


    NSLog(@"didReceiveData,totalFileSize:%ld:,downloadedSize:%ld",self.totalFileSize,self.downloadedSize);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                  willCacheResponse:(NSCachedURLResponse *)proposedResponse
                                  completionHandler:(void (^)(NSCachedURLResponse * _Nullable cachedResponse))completionHandler
{
    NSLog(@"willCacheResponse");
}

#pragma mark  NSUrlSessionDataDelegate end

#pragma mark  NSURLSessionTaskDelegate start
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    // 关闭fileHandle
   
//    self.downloadedSize = 0;
//    self.totalFileSize = 0;
    if(NULL == error)
    {
        [self.fileHandle closeFile];
        self.fileHandle = nil;
        [self complete];
    }
    else
    {
        self.errorMsg = error.localizedDescription;
        self.errorScope = error.code;
        NSLog(self.errorMsg);
        [self downloadFailure];
    }
}


    /*
     * Sent when a task cannot start the network loading process because the current
     * network connectivity is not available or sufficient for the task's request.
     *
     * This delegate will be called at most one time per task, and is only called if
     * the waitsForConnectivity property in the NSURLSessionConfiguration has been
     * set to YES.
     *
     * This delegate callback will never be called for background sessions, because
     * the waitForConnectivity property is ignored by those sessions.
     */
    - (void)URLSession:(NSURLSession *)session taskIsWaitingForConnectivity:(NSURLSessionTask *)task
        API_AVAILABLE(macos(10.13), ios(11.0), watchos(4.0), tvos(11.0))
    {
        NSLog(@"taskIsWaitingForConnectivity");
    }

    /* An HTTP request is attempting to perform a redirection to a different
     * URL. You must invoke the completion routine to allow the
     * redirection, allow the redirection with a modified request, or
     * pass nil to the completionHandler to cause the body of the redirection
     * response to be delivered as the payload of this request. The default
     * is to follow redirections.
     *is t
     * For tasks in background sessions, redirections will always be followed and this method will not be called.
     */
    - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                         willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                                         newRequest:(NSURLRequest *)request
                                  completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
    {
        NSLog(@"willPerformHTTPRedirection");
    }

    /* The task has received a request specific authentication challenge.
     * If this delegate is not implemented, the session specific authentication challenge
     * will *NOT* be called and the behavior will be the same as using the default handling
     * disposition.
     */
    - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                                didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
                                  completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
    {
        NSLog(@"didReceiveChallenge");
    }

    /* Sent if a task requires a new, unopened body stream.  This may be
     * necessary when authentication has failed for any request that
     * involves a body stream.
     */
    - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                                  needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))completionHandler
    {
        NSLog(@"needNewBodyStream");
    }

    /* Sent periodically to notify the delegate of upload progress.  This
     * information is also available as properties of the task.
     */
    - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                                    didSendBodyData:(int64_t)bytesSent
                                     totalBytesSent:(int64_t)totalBytesSent
                           totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
    {
        NSLog(@"didSendBodyData");
    }




#pragma mark  NSURLSessionTaskDelegate end

#pragma mark NSURLSessionDelegate start
    
-(void) URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    NSLog(@"didBecomeInvalidWithError");
    if(NULL != error)
    {
        self.errorMsg = [error domain];
        
        self.errorScope = (int)error.code;
        if([error code] == NSURLErrorCancelled)
        {
            NSLog(@"session cancel!");
        }
        NSLog(@"session error msg!%@",self.errorMsg);
    }
    else
    {
        
    }
//    self.errorScope = -1;
//    [self downloadFailure];
}
    
    - (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
                                                 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
    {
        NSLog(@"didReceiveChallenge");
    }

    /* If an application has received an
     * -application:handleEventsForBackgroundURLSession:completionHandler:
     * message, the session delegate will receive this message to indicate
     * that all messages previously enqueued for this session have been
     * delivered.  At this time it is safe to invoke the previously stored
     * completion handler, or to begin any internal updates that will
     * result in invoking the completion handler.
     */
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session API_AVAILABLE(macos(11.0), ios(7.0), watchos(2.0), tvos(9.0))
    {
        NSLog(@"URLSessionDidFinishEventsForBackgroundURLSession");
    }

    
#pragma mark NSURLSessionDelegate end
-(long) getProcessSpeed:(long) deltaTime
{
    long speed = (self.downloadedSize - self.lastDownloadedSize) * 1000 / deltaTime;
    self.lastDownloadedSize = self.downloadedSize;
    return speed;
}

-(int) getPercent
{
    double percent = self.downloadedSize * 100 / self.totalFileSize;
    int result = (int) floor(percent);
    return result;
}

-(void)renameTempFile
{
    NSFileManager* fileManager = [NSFileManager defaultManager] ;
    if ([fileManager fileExistsAtPath:self.downloadFileTempPath])
    {
        [fileManager moveItemAtPath:self.downloadFileTempPath toPath:self.downloadFilePath error:NULL];
    }
}

-(void) progress
{
    [self.downloadHandler downloadProgress:self];
}

-(void)complete
{
    [self renameTempFile];
    if (![NSString isBlankString:self.md5Str] && ![[FileUtil fileMD5:self.downloadFilePath] isEqualToString:self.md5Str ]) {
        NSLog(@"%@ verify md5 failure!!url:%@,md5:%@",self.TAG,  self.downloadUrl, self.md5Str);
        [FileUtil deleteFile:self.downloadFilePath];
        self.errorMsg = @"md5 verify failure!!!";
        self.errorScope = 7;
        [self downloadFailure];
        return;
    }
    [self.downloadHandler downloadComplete:self];
}

-(void)stop
{
    [super stop];
//    [self.task cancel];
//    [self.session finishTasksAndInvalidate];
}

-(void) downloadStart
{
    [self.downloadHandler downloadHandleStart:self];
}

-(void) downloadFailure
{
    [self stop];
    [self.downloadHandler downloadFailure:self errorScope:self.errorScope errorMsg:self.errorMsg responseCode:self.responseCode];
}

-(long)getTotalSize
{
    return self.totalFileSize;
}

-(long) getDownloadedSize
{
    return self.downloadedSize;
}

-(NSString*) getDownloadUrl
{
    return self.downloadUrl;
}

-(int) getResponseCode
{
    return self.responseCode;
}

-(int)getRetryCount
{
    return self.retryCount;
}

-(NSString*)getDownloadFilePath
{
    return self.downloadFilePath;
}


#pragma mark - Private
//获取downloadTask并激活它,可以从resumeData激活(断点续传),也可以重新下载
- (void)activeDownloadSessionTaskWithUrl:(NSString *)urlStr {
    
    NSString *base64Url = [self encode:urlStr];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t groupQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    __weak typeof(self) weakSelf = self;
    for (NSString *filePath in [self getResumeDataFilePathArray]) {
        //判断如果沙盒中有文件的resumeData数据,则把它存储到resumeDataDic中,用resumeData开启downloadTask
        NSString *fileName = [[filePath lastPathComponent] stringByDeletingPathExtension];
        if ([fileName isEqualToString:base64Url]) {
            dispatch_group_async(group, groupQueue, ^{
                NSData *resumeData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:nil];
                [weakSelf.resumeDataDic setValue:resumeData forKey:base64Url];
            });
            break;
        }
    }
    
    dispatch_notify(group, groupQueue, ^{
        NSURLSessionDownloadTask *downloadTask = nil;

        //之前是否有过这个文件的下载任务
        if ([self.resumeDataDic.allKeys containsObject:base64Url]) {
            //到document中找找有没有之前下载过一些的resumeData文件
            //有resumeData就恢复下载
            downloadTask = [self.session downloadTaskWithResumeData:self.resumeDataDic[base64Url]];
        } else {
            //之前没下载过这个文件,就从头下载吧
            downloadTask = [self.session downloadTaskWithURL:[NSURL URLWithString:urlStr]];
        }
        
        NSLog(@"downloadTask = %@", downloadTask);
        
        //设置任务描述标签为文件url
        downloadTask.taskDescription = urlStr;
        //存储downloadTask对象
        self.downloadTaskDic[base64Url] = downloadTask;
        
        //启动任务
        [downloadTask resume];
    });
}

//停止下载的同时,是否删除resumeData
- (void)cancelDownloadWithUrl:(NSString *)urlStr andRemoveOrNot:(BOOL)isRemove {
    NSString *base64Url = [self encode:urlStr];
    
    if (![self.downloadTaskDic.allKeys containsObject:base64Url]) {
        return;
    }
    NSURLSessionDownloadTask *downloadTask = self.downloadTaskDic[base64Url];
    
    [downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        
        //resumeData存到字典中
        self.resumeDataDic[base64Url] = resumeData;
        //当前正在下载的任务数减1
        if (self.currentCount > 0) {
            self.currentCount--;
        }
        
        if (!isRemove) {
            //将目前传递的文件数据resumeData存储到Document中
            [self saveDownloadTmpFileWithResumeData:resumeData url:urlStr];
        } else {
            [self removeDownloadTmpFileWithUrl:urlStr];
        }
        
#warning 开启等待下载的任务
    }];
}

//保存下载过程中的resumeData
- (void)saveDownloadTmpFileWithResumeData:(NSData *)resumeData url:(NSString *)urlStr {
    [resumeData writeToFile:[self getTmpPathWithUrl:urlStr] atomically:YES];
}


//删除之前保存的文件的resumeData
- (void)removeDownloadTmpFileWithUrl:(NSString *)urlStr {
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:[self getTmpPathWithUrl:urlStr] error:nil];
    
    if (!success) {
        NSLog(@"resumeData删除失败");
    }
    
    NSString *base64Url = [self encode:urlStr];
    [self.resumeDataDic removeObjectForKey:base64Url];
    [self.downloadTaskDic removeObjectForKey:base64Url];
}

//base64加密
- (NSString *)encode:(NSString *)string {
    //先将string转换成data
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *base64Data = [data base64EncodedDataWithOptions:0];
    
    NSString *baseString = [[NSString alloc]initWithData:base64Data encoding:NSUTF8StringEncoding];
    
    return baseString;
}

//base64解密
- (NSString *)dencode:(NSString *)base64String
{
    //NSData *base64data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *data = [[NSData alloc]initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    NSString *string = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    
    return string;
}

//遍历resumeData文件夹目录下的文件,并返回它们的文件路径数组
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

//下载的文件数据resumeData的存储地址
- (NSString *)getTmpPathWithUrl:(NSString *)urlStr {
    NSString *base64Url = [self encode:urlStr];
    
    NSString *homePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *tmpDirectory = [homePath stringByAppendingPathComponent:@"resumeData"];
    
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    if (![defaultManager fileExistsAtPath:tmpDirectory]) {
        [defaultManager createDirectoryAtPath:tmpDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *tmpFile = [tmpDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.tmp", base64Url]];
    return tmpFile;
}

- (void)dealloc {
    [self.session invalidateAndCancel];
}


@end


