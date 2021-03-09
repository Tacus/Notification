//
//  FileUtil.h
//  Notification
//
//  Created by spr on 2021/3/2.
//

#ifndef FileUtil_h
#define FileUtil_h




#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#define FileHashDefaultChunkSizeForReadingData 1024*8 // 8K

#import "StringUtil.h"
#define KIsBlankString(str)  [NSString isBlankString:str]


@interface NSString(NSStringExtention)
+ (BOOL) isBlankString:(NSString *)string;
@end

@interface FileUtil :NSObject

//计算NSData 的MD5值
+(NSString*)getMD5WithData:(NSData*)data;

//计算字符串的MD5值，
+(NSString*)getmd5WithString:(NSString*)string;

//计算大文件的MD5值
+(NSString*)fileMD5:(NSString*)path;

//根据下载地址获取文件下载路径
+(NSString*)getDownloadFilePathByUrl:(NSString*)url fileName:(NSString*)fileName downloadDirPath:(NSString*)downloadDirPath;
+(NSString*)getDownloadTempFile:(NSString*)downloadFilePath;
+(unsigned long long)getExistLen:(NSString*) filePath;
+(BOOL)deleteFile:(NSString*) filePath;
+(BOOL)createDirRecurse:(NSString*) dirPath;
@end

#endif /* FileUtil_h */
