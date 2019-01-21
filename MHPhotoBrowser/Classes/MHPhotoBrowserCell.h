//
//  MHPhotoBrowserCell.h
//  MHPhotoBrowser
//
//  Created by Minghao Xue on 2019/1/21.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MHPhotoBrowserCell : UICollectionViewCell

@property (nonatomic, copy) NSString *representedAssetIdentifier;
@property (nonatomic, strong) UIImage *livePhotoBadgeImage;
@property (nonatomic, strong) UIImage *thumbnailImage;
@property (nonatomic, strong) UIImage * _Nullable selectedImage;

@end

NS_ASSUME_NONNULL_END
