//
//  AsyncTask.h
//  Notification
//
//  Created by spr on 2021/3/2.
//

#ifndef AsyncTask_h
#define AsyncTask_h


#include <Foundation/Foundation.h>

@interface  AsyncTask : NSObject

    @property BOOL stopFlag;
    @property int retryCount;
    @property NSString* TAG;

    -(void) start;

    -(void) stop;

    -(void) startProcess;

    -(int) getPercent;

    -(long) getProcessSpeed:(long) delta;
@end

#endif /* AsyncTask_h */
