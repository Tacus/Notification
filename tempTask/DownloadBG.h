//
//  DownloadBG.h
//  Notification
//
//  Created by spr on 2021/3/1.
//

#ifndef DownloadBG_h
#define DownloadBG_h
#import <Foundation/Foundation.h>
#import <Network/Network.h>

@protocol DownloadHelperDelegate <NSObject>
@optional
- (void) didReceiveData: (NSData *) theData;
- (void) didReceiveFilename: (NSString *) aName;
- (void) dataDownloadFailed: (NSString *) reason;
- (void) dataDownloadAtPercent: (NSNumber *) aPercent;
@end

@interface DownloadHelper : NSObject
{
    NSURLResponse *response;
    NSMutableData *data;
    NSString *urlString;
    NSURLConnection *urlconnection;
    id <DownloadHelperDelegate> delegate;
    BOOL isDownloading;
}
@property (retain) NSURLResponse *response;
@property (retain) NSURLConnection *urlconnection;
@property (retain) NSMutableData *data;
@property (retain) NSString *urlString;
@property (retain) id delegate;
@property (assign) BOOL isDownloading;

+ (DownloadHelper *) sharedInstance;
+ (void) download:(NSString *) aURLString;
+ (void) cancel;
@end

#endif /* DownloadBG_h */
