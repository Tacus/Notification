//
//  AssetLocationInfo.h
//  DownloadFramework
//
//  Created by spr on 2021/7/5.
//

#ifndef AssetLocationInfo_h
#define AssetLocationInfo_h

@interface AssetLocationInfo : NSObject
+ (instancetype)shareInstance;
-(void)Init:(NSString*)assetLocationInfoPath;
-(void)Dispose;
-(NSString*)getAssetLocation:(NSString*)assetName;
@end

#endif /* AssetLocationInfo_h */
