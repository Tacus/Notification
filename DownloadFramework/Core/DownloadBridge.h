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

#ifdef __cplusplus
extern "C"
{
#endif

//
//typedef void (*DownloadFailure)(int errorScope,const char*msg,int responseCode);
//typedef void (*DownloadProgress)(int progress);
//typedef void (*DownloadComplete)(const char* downloadedFilePath);
//typedef void (*DownloadStart)();
////
//typedef void (*UnzipFailure)(const char*msg,int errorCode);
//typedef void (*UnzipProgress)(int progress);
//typedef void (*UnzipComplete)();
//typedef void (*UnzipStart)();

//
typedef void(*DownloadComplete)(const char *url,int leftDownload);
typedef void(*DownloadFailure)(int errorScope,const char* errorMsg,int responseCode);
typedef void(*DownloadProgress)(int progress);

typedef void(*UnzipFailure)(const char* errorMsg,int errorCode);
typedef void(*UnzipProgress)(int progress);
typedef void(*UnzipComplete)(void);

void InitDownload(const char* downloadDirPath,const char* unzipDirPath,int totalDownloadCount);


void RegisterDownloadCallback(DownloadFailure func, DownloadProgress func1, DownloadComplete func2);

void RegisterUnzipCallback(UnzipFailure func, UnzipProgress func1, UnzipComplete func2);

void StartDownloadiOSImp(const char* url,const char*md5,const char* fileName,int currentIndex,int delayInMills);
void AddDownload(const char* url,const char*md5,const char* fileName,int currentIndex,int delayInMills);
void StartUnzipiOSImp(const char* downLoadedFilePath, int currentIndex);
void StartiOSImp(void);

#ifdef __cplusplus
}
#endif


#endif /* DownloadBridge_h */
