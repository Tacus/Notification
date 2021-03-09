//
//  DownloadBG.c
//  Notification
//
//  Created by spr on 2021/3/1.
//

#include "DownloadBG.h"

#define DELEGATE_CALLBACK(X, Y) if (sharedInstance.delegate && [sharedInstance.delegate respondsToSelector:@selector(X)]) [sharedInstance.delegate performSelector:@selector(X) withObject:Y];
#define NUMBER(X) [NSNumber numberWithFloat:X]

static DownloadHelper *sharedInstance = NULL;

@implementation DownloadHelper
@synthesize response;
@synthesize data;
@synthesize delegate;
@synthesize urlString;
@synthesize urlconnection;
@synthesize isDownloading;

- (void) start
{
    self.isDownloading = NO;

    NSURL *url = [NSURL URLWithString:self.urlString];
    if (!url)
    {
        NSString *reason = [NSString stringWithFormat:@"Could not create URL from string %@", self.urlString];
        DELEGATE_CALLBACK(dataDownloadFailed:, reason);
        return;
    }

    NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:url];
    if (!theRequest)
    {
        NSString *reason = [NSString stringWithFormat:@"Could not create URL request from string %@", self.urlString];
        DELEGATE_CALLBACK(dataDownloadFailed:, reason);
        return;
    }

    self.urlconnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (!self.urlconnection)
    {
        NSString *reason = [NSString stringWithFormat:@"URL connection failed for string %@", self.urlString];
        DELEGATE_CALLBACK(dataDownloadFailed:, reason);
        return;
    }

    self.isDownloading = YES;

    // Create the new data object
    self.data = [NSMutableData data];
    self.response = nil;

    [self.urlconnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void) cleanup
{
    self.data = nil;
    self.response = nil;
    self.urlconnection = nil;
    self.urlString = nil;
    self.isDownloading = NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)aResponse
{
    // store the response information
    self.response = aResponse;

    // Check for bad connection
    if ([aResponse expectedContentLength] < 0)
    {
        NSString *reason = [NSString stringWithFormat:@"Invalid URL [%@]", self.urlString];
        DELEGATE_CALLBACK(dataDownloadFailed:, reason);
        [connection cancel];
        [self cleanup];
        return;
    }

    if ([aResponse suggestedFilename])
        DELEGATE_CALLBACK(didReceiveFilename:, [aResponse suggestedFilename]);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)theData
{
    // append the new data and update the delegate
    [self.data appendData:theData];
    if (self.response)
    {
        float expectedLength = [self.response expectedContentLength];
        float currentLength = self.data.length;
        float percent = currentLength / expectedLength;
        DELEGATE_CALLBACK(dataDownloadAtPercent:, NUMBER(percent));
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // finished downloading the data, cleaning up
    self.response = nil;

    // Delegate is responsible for releasing data
    if (self.delegate)
    {
//        NSData *theData = [self.data retain];
//        DELEGATE_CALLBACK(didReceiveData:, theData);
    }
    [self.urlconnection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self cleanup];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.isDownloading = NO;
    NSLog(@"Error: Failed connection, %@", [error localizedDescription]);
    DELEGATE_CALLBACK(dataDownloadFailed:, @"Failed Connection");
    [self cleanup];
}

+ (DownloadHelper *) sharedInstance
{
    if(!sharedInstance) sharedInstance = [[self alloc] init];
    return sharedInstance;
}

+ (void) download:(NSString *) aURLString
{
    if (sharedInstance.isDownloading)
    {
        NSLog(@"Error: Cannot start new download until current download finishes");
        DELEGATE_CALLBACK(dataDownloadFailed:, @"");
        return;
    }

    sharedInstance.urlString = aURLString;
    [sharedInstance start];
}

+ (void) cancel
{
    if (sharedInstance.isDownloading) [sharedInstance.urlconnection cancel];
}
@end

//
//    extern void startDownloadWithUrl((void*) url,(void*)md5,(void*)fileName,int curIndex,int delayInMills);
//
//
//#if defined (__cplusplus)
//}
//#endif
//
//#if defined (__cplusplus)
//extern "C" {
//#endif
//
//    void startDownloadWithUrl((void*) url,(void*)md5,(void*)fileName,int curIndex,int delayInMills)
//    {
//        if(null != mService)
//        {
//            mService.startDownload(url,md5,fileName,curIndex,delayInMills);
//        }
//    }
////
//public void initDownload(String downloadDirPath,String unzipDirPath,int totalDownloadCount)
//{
//    if(null != mService)
//    {
//        mService.initDownload(downloadDirPath,unzipDirPath,totalDownloadCount);
//    }
//    else
//    {
//        Log.e(TAG,"regist service failure!");
//    }
//}
//
//public void startUnzip(String zipFilePath,int curIndex)
//{
//    if(null != mService)
//    {
//        mService.startUnzip(zipFilePath,curIndex);
//    }
//}
//
//public void setHandler(DownloadHandlerForCSharp downloadhandler,UnzipHandlerForCSharp unzipHandler)
//{
//    if(null != mService) {
//        mService.setDownloadHandler(downloadhandler);
//        mService.setUnzipHandler(unzipHandler);
//    }
//}
//
//private void stopService()
//{
//    Log.d(TAG,"stopService");
//    if(mBound)
//    {
//        unbindService(sc);
//        mBound = false;
//    }
//    mService = null;
//    sc = null;
//}
//
//private boolean mBound = false;
//private ServiceConnection sc;
//private DownloadService mService;
//
//private void initServer()
//{
//    if(sc == null)
//    {
//        sc = new ServiceConnection() {
//            @Override
//            public void onServiceConnected(ComponentName name, IBinder service) {
//                Log.d(TAG,"onServiceConnected");
//                DownloadService.LocalBinder binder = (DownloadService.LocalBinder) service;
//                mService = binder.getService();
//                mBound = true;
//            }
//
//            @Override
//            public void onServiceDisconnected(ComponentName name) {
//                Log.d(TAG,"onServiceDisconnected");
//                mBound = false;
//                mService = null;
//            }
//        };
//    }
//}
//private void startService()
//{
//    initServer();
//    Intent intent = new Intent(this, DownloadService.class);
//    bindService(intent,sc, Context.BIND_AUTO_CREATE);
//}

