//
//  DownloadTask.hpp
//  Notification
//
//  Created by spr on 2021/3/2.
//

#ifndef DownloadTask_hpp
#define DownloadTask_hpp
#import "AsyncTask.h"
#import "ProcessHandler.h"

@interface DownloadTask : AsyncTask
@property NSString* downloadUrl;
@property NSString* md5Str;
@property NSString* downloadFilePath;
@property NSString* downloadDirPath;
@property NSString* downloadFileTempPath;
@property id<ProcessHandler> downloadHandler;
@property NSString* errorMsg;
@property int responseCode;
@property int errorScope;

@property long downloadedSize;
@property long totalFileSize;


-(instancetype)initWithUrl:(NSString*) url md5Str:(NSString*) md5Str downloadDirPath:(NSString*) downloadDirPath name:(NSString*) name downloadHandler:(id<ProcessHandler>) downloadHandler;
@end


#endif /* DownloadTask_mm */
