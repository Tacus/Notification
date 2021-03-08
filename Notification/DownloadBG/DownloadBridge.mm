//
//  DownloadBridge.c
//  Notification
//
//  Created by spr on 2021/3/1.
//

#include "DownloadBridge.h"



void startDownload(const char* url,const char*md5,const char* fileName,int curIndex,int delayInMills)
{
    
    
}

//
void initDownload(const char*downloadDirPath,const char*unzipDirPath,int totalDownloadCount)
{
    
}
////{
////    if(null != mService)
////    {
////        mService.initDownload(downloadDirPath,unzipDirPath,totalDownloadCount);
////    }
////    else
////    {
////        Log.e(TAG,"regist service failure!");
////    }
////}
////
//void startUnzip((void*) zipFilePath,int curIndex);
////{
////    if(null != mService)
////    {
////        mService.startUnzip(zipFilePath,curIndex);
////    }
////}
////
//
//
//
//void setDownloadHandler(DownloadFailure* downloadFailurFun, DownloadProgress* downloadProgress, DownloadComplete* downloadComplete );
//void setUnzipHandler(UnzipFailure* unzipFailure,UnzipProgress* unzipProgress,UnzipComplete* unzipComplete);
////{
////    if(null != mService) {
////        mService.setDownloadHandler(downloadhandler);
////        mService.setUnzipHandler(unzipHandler);
////    }
////}
////
//void stopService();
////{
////    Log.d(TAG,"stopService");
////    if(mBound)
////    {
////        unbindService(sc);
////        mBound = false;
////    }
////    mService = null;
////    sc = null;
////}
////
////private boolean mBound = false;
////private ServiceConnection sc;
////private DownloadService mService;
////
////void initServer();
////{
////    if(sc == null)
////    {
////        sc = new ServiceConnection() {
////            @Override
////            public void onServiceConnected(ComponentName name, IBinder service) {
////                Log.d(TAG,"onServiceConnected");
////                DownloadService.LocalBinder binder = (DownloadService.LocalBinder) service;
////                mService = binder.getService();
////                mBound = true;
////            }
////
////            @Override
////            public void onServiceDisconnected(ComponentName name) {
////                Log.d(TAG,"onServiceDisconnected");
////                mBound = false;
////                mService = null;
////            }
////        };
////    }
////}
//void startService()
