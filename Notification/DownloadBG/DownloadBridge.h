//
//  DownloadBridge.h
//  Notification
//
//  Created by spr on 2021/3/1.
//



//Tips for iOS:
//Managed-to-unmanaged calls are quite processor-intensive on iOS. Try to avoid calling multiple native methods per frame.
//
//Wrap your native methods with an additional C# layer that calls native code on the device and returns dummy values in the Editor.
//
//String values returned from a native method should be UTF–8 encoded and allocated on the heap. Mono marshalling calls free for strings like this.


#ifndef DownloadBridge_h
#define DownloadBridge_h

#import "DownloadBG.h"

#ifdef __cplusplus
extern "C"
{
#endif


typedef void (*DownloadFailure)(int errorScope,const char*msg,int responseCode);
typedef void (*DownloadProgress)(int progress);
typedef void (*DownloadComplete)(const char* downloadedFilePath);
typedef void (*DownloadStart)();

typedef void (*UnzipFailure)(const char*msg,int errorCode);
typedef void (*UnzipProgress)(int progress);
typedef void (*UnzipComplete)();
typedef void (*UnzipStart)();

void startDownload(const char* url,const char*md5,const char* fileName,int curIndex,int delayInMills);
//
//void startDownload(String url,String md5,String fileName,int curIndex,int delayInMills)
//{
//    if(null != mService)
//    {
//        mService.startDownload(url,md5,fileName,curIndex,delayInMills);
//    }
//}
//
void initDownload(const char* downloadDirPath,const char* unzipDirPath,int totalDownloadCount);
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
void startUnzip(const char* zipFilePath,int curIndex);
//{
//    if(null != mService)
//    {
//        mService.startUnzip(zipFilePath,curIndex);
//    }
//}
//



void setDownloadHandler(DownloadFailure* downloadFailurFun, DownloadProgress* downloadProgress, DownloadComplete* downloadComplete );
void setUnzipHandler(UnzipFailure* unzipFailure,UnzipProgress* unzipProgress,UnzipComplete* unzipComplete);
//{
//    if(null != mService) {
//        mService.setDownloadHandler(downloadhandler);
//        mService.setUnzipHandler(unzipHandler);
//    }
//}
//
void stopService();
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
//void initServer();
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
void startService();
//{
//    initServer();
//    Intent intent = new Intent(this, DownloadService.class);
//    bindService(intent,sc, Context.BIND_AUTO_CREATE);
//}




#ifdef __cplusplus
}
#endif


#endif /* DownloadBridge_h */
