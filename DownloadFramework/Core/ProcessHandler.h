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
-(void) unzipFailure:(NSString*)zipFilePath errorMsg:(NSString*) msg errorScope:(int) errorScope;

@required
-(void) unzipProgress:(NSString*)zipFilePath progress:(int)progress;

@required
-(void) unzipComplete:(NSString*)zipFilePath;

@required
-(void) unzipDone;

//-(void) unzipHandleStart:(AsyncTask*) task;

@required
-(void) downloadFailure:(NSString*)url errorScope:(int) errorScope errorMsg:(NSString*) msg responseCode:(int) responseCode;

@required
-(void) downloadProgress:(NSString*)url progress:(int)progress;

@required
-(void) downloadComplete:(NSString*)url downloadedFilePath:(NSString*)downloadedFilePath;

@required
-(void) downloadDone:(NSString*)errorMsg;

//-(void) downloadHandleStart:(AsyncTask*) task;


@end

NS_ASSUME_NONNULL_END
