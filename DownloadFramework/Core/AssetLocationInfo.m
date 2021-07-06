//
//  AssetLocationInfo.m
//  DownloadFramework
//
//  Created by spr on 2021/7/5.
//

#import <Foundation/Foundation.h>
#import "AssetLocationInfo.h"

AssetLocationInfo *assetLocation = nil;
@implementation AssetLocationInfo

NSMutableDictionary*aMutableDictionary;

+ (instancetype)shareInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        assetLocation = [[self alloc] init];
    });
    
    return assetLocation;
}


-(void)Init:(NSString*)assetLocationInfoPath
{
    if(NULL != aMutableDictionary) return;
    NSError* error;
    NSString* content = [NSString stringWithContentsOfFile:assetLocationInfoPath encoding:NSUTF8StringEncoding error:&error];
    if(NULL != error || NULL == content)
    {
        return;
    }
    aMutableDictionary = [[NSMutableDictionary alloc]init];
    NSArray* array = [content componentsSeparatedByString:@"\n"];
    for (int i = 0; i < [array count]; i++) {
        NSString* line = array[i];
        NSArray* infos = [line componentsSeparatedByString:@";"];
        if(1 < [infos count] && ![[aMutableDictionary allKeys] containsObject:infos[0]])
        {
            [aMutableDictionary setValue:infos[1] forKey:infos[0]];
        }
    }
}

-(NSString*)getAssetLocation:(NSString*)assetName
{
    if(NULL != aMutableDictionary)
    {
        return [aMutableDictionary valueForKey:assetName];
    }
    return NULL;
}

-(void)Dispose
{
    [aMutableDictionary removeAllObjects];
    aMutableDictionary = NULL;
    assetLocation = NULL;
}

@end
