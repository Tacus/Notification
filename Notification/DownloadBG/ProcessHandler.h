//
//  ProcessHandler.h
//  Notification
//
//  Created by spr on 2021/3/2.
//

#import <Foundation/Foundation.h>
#import "AsyncTask.h"
NS_ASSUME_NONNULL_BEGIN

@protocol ProcessHandler <NSObject>

@required
-(void) unzipFailure:(AsyncTask*) task errorScope:(int) errorScope errorMsg:(NSString*) msg responseCode:(int) responseCode;

@required
-(void) unzipProgress:(AsyncTask*) task;

@required
-(void) unzipComplete:(AsyncTask*) task;

-(void) unzipHandleStart:(AsyncTask*) task;

@required
-(void) downloadFailure:(AsyncTask*) task errorScope:(int) errorScope errorMsg:(NSString*) msg responseCode:(int) responseCode;

@required
-(void) downloadProgress:(AsyncTask*) task;

@required
-(void) downloadComplete:(AsyncTask*) task;

-(void) downloadHandleStart:(AsyncTask*) task;


@end

NS_ASSUME_NONNULL_END
