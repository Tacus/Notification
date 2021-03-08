//
//  AsyncTask.m
//  Notification
//
//  Created by spr on 2021/3/2.
//

#import <Foundation/Foundation.h>
#import "AsyncTask.h"

@implementation AsyncTask

-(void) start
{
    [self startProcess];
}

-(void) stop
{
    NSLog(@"task stop!");
    self.stopFlag = YES;
}

-(void)startProcess
{
    
}

-(int)getPercent
{
    return 0;
}

-(long) getProcessSpeed:(long) delta
{
    return 0l;
}

@end
