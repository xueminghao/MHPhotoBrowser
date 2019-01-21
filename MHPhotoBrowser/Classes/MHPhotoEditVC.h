//
//  MHPhotoEditVC.h
//  MHPhotoBrowser
//
//  Created by Minghao Xue on 2019/1/21.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

@interface MHPhotoEditVC : UIViewController

@property (nonatomic, strong) UIImage *thumnailImage;
@property (nonatomic, strong) PHAsset *asset;

@end

NS_ASSUME_NONNULL_END
