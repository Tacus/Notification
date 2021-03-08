//*
//  ViewController.m
//  Notification
//
//  Created by spr on 2021/3/1.
//

#import "MyViewController.h"
//#import "User"
#import <UserNotifications/UNUserNotificationCenter.h>
#import "NotificationDemo.h"
#import "DownloadTaskManager.h"




#pragma mark MyViewController
@interface MyViewController ()
@property UIImageView* imageview;
@property NSMutableData* buffer;
@property NSURLSession* session;
@property NSURLSessionDownloadTask* dataTask;
@property IBOutlet UIProgressView *progressview;
@property IBOutlet UILabel *progressLabel;
@property NSUInteger expectlength;
@property NSString* downloadedFilePath;

@property double lastTime;

-(void) downloadFailure:(int) errorScope errorMsg:(NSString*) msg responseCode:(int) responseCode;

-(void) downloadProgress:(float)progress;



-(void) downloadComplete:(NSString*) downloadedFilePath;

//@property (strong,nonatomic)UIImageView * imageview;
//@property (strong,nonatomic)NSURLSession * session;
//@property (strong,nonatomic)NSURLSessionDataTask * dataTask;
//@property (weak, nonatomic) IBOutlet UIProgressView *progressview;
//@property (nonatomic)NSUInteger expectlength;
//@property (strong,nonatomic) NSMutableData * buffer;

@end

@implementation MyViewController

static NSString * imageURL = @"http://ro.xdcdn.net/res/Release/iOS/588589_593047.zip";


- (void)viewDidLoad {
    [super viewDidLoad];
}

-(void)initDownloadTask
{
   
}


-(IBAction)PushButtonClick:(id)sender
{
    NotificationDemo* center = [[NotificationDemo alloc]init];
    [center pushNotification_IOS_10_Body:@"开始下载"  promptTone:@"xx"  soundName:@"hello" imageName:@"test" movieName:@"ste" Identifier:@"com.xd.ro"];
}


//注意判断当前Task的状态
- (IBAction)pause:(UIButton *)sender {
    if (self.dataTask.state == NSURLSessionTaskStateRunning) {
        [self.dataTask suspend];
    }
}

- (IBAction)cancel:(id)sender {

}

- (IBAction)resume:(id)sender {
    NSLog(@"resume");
    __weak typeof(self) weakSelf = self;
//    [[LFDownloadNetwork shareManager] downloadWithUrl:self.filePath progress:^(float progress) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            weakSelf.progressLabel.text = [NSString stringWithFormat:@"%.2f%%", progress];
//        });
//    } success:^(NSURL * _Nonnull url) {
//        NSLog(@"下载完成 = %@", url.absoluteString);
//    } failed:^(NSError * _Nonnull error) {
//        NSLog(@"error = %@", error.localizedDescription);
//    }];
    [[DownloadTaskManager shareManager]
     initWithBlock:^(int errorScode,NSString* errorMsg, int responseCode)
    {
        NSLog(@"error = %@", errorMsg);
    }
                                     
    downloadProgress:^(float progress)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            weakSelf.progressLabel.text = [NSString stringWithFormat:@"%.2f%%", progress];
            weakSelf.progressview.progress = progress;
        });
        
    }
    downloadComplete:^(NSString*url)
    {
        NSLog(@"下载完成 = %@", url);
    }];
//    DownloadTaskManager* manger = [DownloadTaskManager shareManager];
//    [manger setWithBlock:NULL downloadProgress:NULL downloadComplete:NULL];
    [[DownloadTaskManager shareManager]  downloadWithUrl:imageURL];
}
//

-(void) downloadFailure:(int) errorScope errorMsg:(NSString*) msg responseCode:(int) responseCode
{
    
}

-(void) downloadProgress:(float)progress
{
    double curTime = [self getCurrentSysTime];
    long delta = curTime - self.lastTime;
    if( delta > 100)
    {
        self.lastTime = curTime;
        dispatch_async(dispatch_get_main_queue(), ^{
//            NSLog(@"getpercent:%d sppeed:%ld,delta:%d",[task getPercent],spped,delta);
            self.progressview.progress = progress;
            NSInteger speed = 0;
            self.progressLabel.text = [NSString stringWithFormat:@"当前下载速度%ld",speed];
        });
    }
    
}



-(void) downloadComplete:(NSString*) downloadedFilePath
{
    NSLog(@"download Complete");
    NotificationDemo* center = [[NotificationDemo alloc]init];
    [center pushNotification_IOS_10_Body:@"开始下载"  promptTone:@"xx"  soundName:@"hello" imageName:@"test" movieName:@"ste" Identifier:@"com.xd.ro"];
}

-(double)getCurrentSysTime
{
    NSDate* dat = [NSDate date];
    double interval = [dat timeIntervalSince1970]*1000;
    return interval;
}

//-(void) downloadHandleStart:(AsyncTask*) task
//{
//    NSLog(@"downlaod start");
//}

//-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
//    [self.buffer appendData:data];//数据放到缓冲区里
//    float progress = [self.buffer length]/((float) self.expectlength);
//    self.progressview.progress = progress;//更改progressview的progress
////    NSLog(@"progress:%.2f",progress);
//}
////
//-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
//    if (!error) {
//        dispatch_async(dispatch_get_main_queue(), ^{//用GCD的方式，保证在主线程上更新UI
//            self.progressview.hidden = YES;
//            self.session = nil;
//            self.dataTask = nil;
//        });
//        NSLog(@"download sucess");
//
//    }else{
//        NSDictionary * userinfo = [error userInfo];
//        NSString * failurl = [userinfo objectForKey:NSURLErrorFailingURLStringErrorKey];
//        NSString * localDescription = [userinfo objectForKey:NSLocalizedDescriptionKey];
//
//        if ([failurl isEqualToString:imageURL] && [localDescription isEqualToString:@"cancelled"]) {//如果是task被取消了，就弹出提示框
//            UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Message" message:@"The task is canceled"preferredStyle:UIAlertControllerStyleAlert];
//            UIAlertAction* ok = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){NSLog(@"ok btn click!");}];
//            [alert addAction:ok];
//            [self presentViewController:alert animated:YES completion:^{NSLog(@"alert window complete");}];
//
//
//        }else{
//            UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Unknown type error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
//            UIAlertAction* ok = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){NSLog(@"ok btn click!");}];
//            [alert addAction:ok];
//            [self presentViewController:alert animated:YES completion:^{NSLog(@"alert window complete");}];
//        }
//        self.progressview.hidden = YES;
//        self.session = nil;
//        self.dataTask = nil;
//    }
//}

@end

