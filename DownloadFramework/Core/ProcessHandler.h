//
//  ProcessHandler.h
//  Notification
//
//  Created by spr on 2021/3/2.
//

#import <Foundation/Foundation.h>
//#import "AsyncTask.h"
NS_ASSUME_NONNULL_BEGIN

@protocol ProcessHandler <NSObject>

@required
-(void) unzipFailure:(NSString*) msg responseCode:(int) responseCode;

@required
-(void) unzipProgress:(int)progress;

@required
-(void) unzipComplete;

//-(void) unzipHandleStart:(AsyncTask*) task;

@required
-(void) downloadFailure:(int) errorScope errorMsg:(NSString*) msg responseCode:(int) responseCode;

@required
-(void) downloadProgress:(int)progress;

@required
-(void) downloadComplete:(NSString*)downloadedFilePath leftDownload:(int)done;

//-(void) downloadHandleStart:(AsyncTask*) task;


@end

NS_ASSUME_NONNULL_END
