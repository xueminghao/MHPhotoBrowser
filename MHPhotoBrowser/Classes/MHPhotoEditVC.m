//
//  MHPhotoEditVC.m
//  MHPhotoBrowser
//
//  Created by Minghao Xue on 2019/1/21.
//

#import "MHPhotoEditVC.h"
#import <ReactiveObjC/ReactiveObjC.h>
#import <YYWebImage/UIImage+YYWebImage.h>
#import <Masonry/Masonry.h>

#define BottomBarHeight 49

typedef NS_ENUM(NSUInteger, MHPhotoEditVCImageDirection) {
    MHPhotoEditVCImageDirectionVertical = 0,
    MHPhotoEditVCImageDirectionLandscpaeLeft,
    MHPhotoEditVCImageDirectionUpsideDown,
    MHPhotoEditVCImageDirectionLandscapeRight,
};

@interface MHPhotoEditVC ()

@property (nonatomic, strong) UIImageView *iv;

@property (nonatomic, strong) UIView *maskView;
@property (nonatomic, strong) CAShapeLayer *maskViewShapeLayer;

@property (nonatomic, strong) UIProgressView *updateProgressView;
@property (nonatomic, strong) UIView *bottomContainerView;

@property (nonatomic, assign) CGRect previoushRoundCircleFrame;

@property (nonatomic, assign) PHImageRequestID requestId;

@property (nonatomic, assign) MHPhotoEditVCImageDirection imageDirection;
@property (nonatomic, strong) NSMutableDictionary *rotatedImageCache;

@end

@implementation MHPhotoEditVC

#pragma mark - Life cyles

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = NSLocalizedString(@"Gallery", nil);
    self.view.clipsToBounds = YES;
    UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStyleDone target:self action:@selector(doneItemClicked:)];
    doneItem.tintColor = [UIColor blackColor];
    doneItem.enabled = NO;
    self.navigationItem.rightBarButtonItem = doneItem;
    [self.view addSubview:self.iv];
    [self.view addSubview:self.maskView];
    [self.view addSubview:self.updateProgressView];
    [self.view addSubview:self.bottomContainerView];
    self.previoushRoundCircleFrame = CGRectZero;
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesstureTriggered:)];
    [self.iv addGestureRecognizer:panGesture];
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGestureTriggered:)];
    [self.iv addGestureRecognizer:pinchGesture];
    self.iv.image = self.thumnailImage;
    self.iv.bounds = CGRectMake(0, 0, self.thumnailImage.size.width, self.thumnailImage.size.height);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self checkAuthorizatonStatusAndLoadFullSizeImage];
}

- (UIEdgeInsets)contentViewInsets {
    return UIEdgeInsetsMake(0, 0, BottomBarHeight, 0);
}

- (BOOL)autoInsetsSafeArea {
    return YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    [self pinIVCenterToContentView];
    self.maskView.frame = self.view.bounds;
    self.updateProgressView.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 2);
    self.bottomContainerView.frame = CGRectMake(0, CGRectGetMaxY(self.view.frame), CGRectGetWidth(self.view.frame), BottomBarHeight);
    //Update mask layer
    CGRect shapeLayerFrame = self.view.bounds;
    CGFloat width = shapeLayerFrame.size.width;
    CGFloat height = shapeLayerFrame.size.height;
    CGRect roundCircleFrame = CGRectInset(shapeLayerFrame, 0, (height - width) / 2.0);
    if (CGRectEqualToRect(roundCircleFrame, self.previoushRoundCircleFrame)) {
        return;
    }
    
    self.maskViewShapeLayer.frame = shapeLayerFrame;
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:shapeLayerFrame];
    UIBezierPath *roundPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(width / 2.0, height / 2.0) radius:width / 2.0 startAngle:0 endAngle:2 * M_PI clockwise:NO];
    [path appendPath:roundPath];
    self.maskViewShapeLayer.path = path.CGPath;
    self.maskView.layer.mask = self.maskViewShapeLayer;
    
    self.previoushRoundCircleFrame = roundCircleFrame;
}

- (void)dealloc {
    [[PHImageManager defaultManager] cancelImageRequest:self.requestId];
}

#pragma mark - Private methods

- (void)checkAuthorizatonStatusAndLoadFullSizeImage {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    switch (status) {
        case PHAuthorizationStatusNotDetermined:
        {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    [self updateStaticImage];
                } else {
                    [self showAlert];
                }
            }];
            break;
        }
        case PHAuthorizationStatusAuthorized:
            [self updateStaticImage];
            break;
        case PHAuthorizationStatusDenied:
            [self showAlert];
            break;
        case PHAuthorizationStatusRestricted:
            break;
    }
}

- (void)showAlert {
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:nil message:@"Access denied" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertVC addAction:okAction];
    [self presentViewController:alertVC animated:YES completion:nil];
}

- (void)updateStaticImage {
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
    options.networkAccessAllowed = YES;
    @weakify(self);
    options.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
        @strongify(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.updateProgressView.progress = progress;
        });
    };
    self.requestId = [[PHImageManager defaultManager] requestImageForAsset:self.asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeDefault options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        @strongify(self);
        self.updateProgressView.hidden = YES;
        if (result) {
            [self updateRotatedImageCache:result forDirection:MHPhotoEditVCImageDirectionVertical];
            [self updateImage:result animted:YES];
        } else if (self.thumnailImage) {
            [self updateRotatedImageCache:self.thumnailImage forDirection:MHPhotoEditVCImageDirectionVertical];
        }
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }];
}

- (void)pinIVCenterToContentView {
    self.iv.center = CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0);
}

- (void)updateImage:(UIImage *)image animted:(BOOL)animated {
    self.iv.image = image;
    [self pinIVCenterToContentView];
    
    CGSize size = image.size;
    if (size.width == 0 || size.height == 0) {
        return;
    }
    CGSize contentViewSize = self.view.bounds.size;
    CGFloat imageRatio = size.width / size.height;
    CGFloat contentViewRatio = contentViewSize.width / contentViewSize.height;
    CGFloat width;
    CGFloat height;
    if (imageRatio > contentViewRatio) {
        width = MIN(size.width, contentViewSize.width);
        height = width / imageRatio;
    } else {
        height = MIN(size.height, contentViewSize.height);
        width = height * imageRatio;
    }
    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{
            self.iv.bounds = CGRectMake(0, 0, width, height);
        }];
    } else {
        self.iv.bounds = CGRectMake(0, 0, width, height);
    }
    [self normalizeIVSizeAnimated:animated];
}

- (void)normalizeIVPositionAnimated:(BOOL)animated {
    CGPoint offset = CGPointZero;
    CGFloat minXOffset = self.iv.frame.origin.x - self.previoushRoundCircleFrame.origin.x;
    CGFloat minYOffset = self.iv.frame.origin.y - self.previoushRoundCircleFrame.origin.y;
    CGFloat maxXOffset = CGRectGetMaxX(self.iv.frame) - CGRectGetMaxX(self.previoushRoundCircleFrame);
    CGFloat maxYOffset = CGRectGetMaxY(self.iv.frame) - CGRectGetMaxY(self.previoushRoundCircleFrame);
    if (minXOffset > 0) {
        offset = CGPointMake(offset.x - minXOffset, offset.y);
    }
    if (minYOffset > 0) {
        offset = CGPointMake(offset.x, offset.y - minYOffset);
    }
    if (maxXOffset < 0) {
        offset = CGPointMake(offset.x - maxXOffset, offset.y);
    }
    if (maxYOffset < 0) {
        offset = CGPointMake(offset.x, offset.y - maxYOffset);
    }
    
    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{
            CGPoint center = self.iv.center;
            CGPoint newCenter = CGPointMake(center.x + offset.x, center.y + offset.y);
            self.iv.center = newCenter;
        }];
    } else {
        CGPoint center = self.iv.center;
        CGPoint newCenter = CGPointMake(center.x + offset.x, center.y + offset.y);
        self.iv.center = newCenter;
    }
}

- (void)normalizeIVSizeAnimated:(BOOL)animated {
    CGSize size = self.iv.bounds.size;
    
    CGFloat newWidth = size.width;
    CGFloat newHeight = size.height;
    
    if (size.width < size.height) {
        if (size.width < self.previoushRoundCircleFrame.size.width) { //最小限制
            newWidth = self.previoushRoundCircleFrame.size.width;
            newHeight = newWidth / size.width * size.height;
        }
    } else {
        if (size.height < self.previoushRoundCircleFrame.size.height) { //最小限制
            newHeight = self.previoushRoundCircleFrame.size.height;
            newWidth = newHeight / size.height * size.width;
        }
    }
    if (size.width > self.iv.image.size.width &&
        self.iv.image.size.width > self.previoushRoundCircleFrame.size.width) { //最大限制
        newWidth = self.iv.image.size.width;
        newHeight = newWidth / size.width * size.height;
    }
    if (size.height > self.iv.image.size.height &&
        self.iv.image.size.height > self.previoushRoundCircleFrame.size.width) {
        newHeight = self.iv.image.size.height;
        newWidth = newHeight / size.height * size.width;
    }
    
    CGSize newSize = CGSizeMake(newWidth, newHeight);
    if (CGSizeEqualToSize(newSize, size)) {
        return;
    }
    
    CGRect newBounds = CGRectMake(0, 0, newSize.width, newSize.height);
    
    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{
            self.iv.bounds = newBounds;
        } completion:^(BOOL finished) {
            [self normalizeIVPositionAnimated:YES];
        }];
    } else {
        self.iv.bounds = newBounds;
        [self normalizeIVPositionAnimated:NO];
    }
}

- (UIImage *)getClippedImage {
    UIImage *originalImage = self.iv.image;
    CGSize targetSize = self.previoushRoundCircleFrame.size;
    CGRect bounds = CGRectMake(0, 0, targetSize.width, targetSize.height);
    CGRect roundCircleFrame = [self.view convertRect:self.previoushRoundCircleFrame toView:self.iv];
    CGRect imageBounds = CGRectMake(-roundCircleFrame.origin.x, -roundCircleFrame.origin.y, self.iv.frame.size.width, self.iv.frame.size.height);
    
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:bounds];
    CGContextAddPath(ctx, path.CGPath);
    CGContextClip(ctx);
    [originalImage drawInRect:imageBounds];
    
    UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return ret;
}

- (UIImage *)imageForRotateDirection:(MHPhotoEditVCImageDirection)direction {
    UIImage *image = [self.rotatedImageCache objectForKey:@(direction)];
    if (!image) {
        image = [self generateImageWithRotateDirection:direction];
        [self updateRotatedImageCache:image forDirection:direction];
    }
    return image;
}

- (void)updateRotatedImageCache:(UIImage *)image forDirection:(MHPhotoEditVCImageDirection)direction {
    if (!self.rotatedImageCache) {
        self.rotatedImageCache = [NSMutableDictionary new];
    }
    [self.rotatedImageCache setObject:image forKey:@(direction)];
}

- (UIImage *)generateImageWithRotateDirection:(MHPhotoEditVCImageDirection)direction {
    UIImage *originalImage = [self imageForRotateDirection:MHPhotoEditVCImageDirectionVertical];
    switch (direction) {
        case MHPhotoEditVCImageDirectionVertical:
            return originalImage;
        case MHPhotoEditVCImageDirectionLandscpaeLeft:
            return [originalImage yy_imageByRotateLeft90];
        case MHPhotoEditVCImageDirectionUpsideDown:
            return [originalImage yy_imageByRotate180];
        case MHPhotoEditVCImageDirectionLandscapeRight:
            return [originalImage yy_imageByRotateRight90];
    }
}

#pragma mark - Target action methods

- (void)doneItemClicked:(UIBarButtonItem *)sender {
    UIImage *image = [self getClippedImage];
    NSArray *vcs = self.navigationController.viewControllers;
    if (vcs.count < 3) {
        @weakify(self);
        [self dismissViewControllerAnimated:YES completion:^{
            @strongify(self);
            [self doCallBackWithImage:image];
        }];
    } else {
        UIViewController *vc = self.navigationController.viewControllers[self.navigationController.viewControllers.count - 3];
        [self.navigationController popToViewController:vc animated:YES];
        [self doCallBackWithImage:image];
    }
}

- (void)doCallBackWithImage:(UIImage *)image {
    
}

- (void)rotateBtnClicked:(UIButton *)sender {
    MHPhotoEditVCImageDirection direction;
    if (self.imageDirection == MHPhotoEditVCImageDirectionLandscapeRight) {
        direction = MHPhotoEditVCImageDirectionVertical;
    } else {
        direction = (MHPhotoEditVCImageDirection)(self.imageDirection + 1);
    }
    UIImage *image = [self imageForRotateDirection:direction];
    [self updateImage:image animted:NO];
    self.imageDirection = direction;
}

- (void)panGesstureTriggered:(UIPanGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            break;
        case UIGestureRecognizerStateChanged:
        {
            CGPoint center = self.iv.center;
            CGPoint translation = [gesture translationInView:gesture.view];
            CGPoint newCenter = CGPointMake(center.x + translation.x, center.y + translation.y);
            self.iv.center = newCenter;
            [gesture setTranslation:CGPointZero inView:gesture.view];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
        {
            [self normalizeIVPositionAnimated:YES];
            break;
        }
        default:
            break;
    }
}

- (void)pinchGestureTriggered:(UIPinchGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
        {
            CGFloat scale = gesture.scale;
            CGRect bounds = self.iv.bounds;
            CGRect newBounds = CGRectMake(0, 0, bounds.size.width * scale, bounds.size.height * scale);
            self.iv.bounds = newBounds;
            gesture.scale = 1.0;
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
        {
            [self normalizeIVSizeAnimated:YES];
            break;
        }
        default:
            break;
    }
}

#pragma mark - Getters

- (UIImageView *)iv {
    if (!_iv) {
        _iv = [UIImageView new];
        _iv.userInteractionEnabled = YES;
        _iv.contentMode = UIViewContentModeScaleAspectFill;
    }
    return _iv;
}

- (UIView *)maskView {
    if (!_maskView) {
        _maskView = [UIView new];
        _maskView.userInteractionEnabled = NO;
        _maskView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    }
    return _maskView;
}

- (CAShapeLayer *)maskViewShapeLayer {
    if (!_maskViewShapeLayer) {
        _maskViewShapeLayer = [CAShapeLayer new];
    }
    return _maskViewShapeLayer;
}

- (UIProgressView *)updateProgressView {
    if (!_updateProgressView) {
        _updateProgressView = [UIProgressView new];
        _updateProgressView.progressTintColor = [UIColor blueColor];
        _updateProgressView.trackTintColor = [UIColor whiteColor];
    }
    return _updateProgressView;
}

- (UIView *)bottomContainerView {
    if (!_bottomContainerView) {
        _bottomContainerView = [UIView new];
        _bottomContainerView.backgroundColor = [UIColor whiteColor];
        UIView *topLine = [UIView new];
        topLine.backgroundColor = [UIColor orangeColor];
        [_bottomContainerView addSubview:topLine];
        [topLine mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.right.equalTo(self->_bottomContainerView);
            make.height.equalTo(@1);
        }];
        UIImageView *iv = [UIImageView new];
        [_bottomContainerView addSubview:iv];
        [iv mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(topLine.mas_bottom).offset(6);
            make.centerX.equalTo(self->_bottomContainerView);
            make.width.height.equalTo(@24);
        }];
        UILabel *lbl = [UILabel new];
        lbl.font = [UIFont systemFontOfSize:10];
        lbl.textColor = [UIColor lightTextColor];
        lbl.text = NSLocalizedString(@"Rotate", nil);
        [_bottomContainerView addSubview:lbl];
        [lbl mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self->_bottomContainerView).offset(-2);
            make.centerX.equalTo(self->_bottomContainerView);
        }];
        UIControl *control = [UIControl new];
        [_bottomContainerView addSubview:control];
        [control mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(iv.mas_top);
            make.bottom.equalTo(lbl.mas_bottom);
            make.width.equalTo(@75);
            make.centerX.equalTo(iv);
        }];
        [control addTarget:self action:@selector(rotateBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _bottomContainerView;
}
@end

