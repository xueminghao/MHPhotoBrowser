//
//  MHPhotoBrowserVC.m
//  MHPhotoBrowser
//
//  Created by Minghao Xue on 2019/1/21.
//

#import "MHPhotoBrowserVC.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import "MHPhotoBrowserCell.h"
#import "MHPhotoEditVC.h"
#import "MHPhotoBrowserAuthorizationView.h"

#import <ReactiveObjC/ReactiveObjC.h>
#import <Masonry/Masonry.h>

@interface MHPhotoBrowserVC ()<PHPhotoLibraryChangeObserver, UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, strong) PHFetchResult *allPhotos;

@property (nonatomic, strong) PHCachingImageManager *imageManager;
@property (nonatomic, assign) CGRect previousPreheatRect;


@property (nonatomic, strong) UICollectionView *cv;
@property (nonatomic, strong) UICollectionViewFlowLayout *layout;

@property (nonatomic, assign) CGSize thumnailSize;

@property (nonatomic, strong) PHAsset *selectedPhoto;
@property (nonatomic, strong) UIImage *selectedThumbnail;

@property (nonatomic, strong) MHPhotoBrowserAuthorizationView *authorizationView;

@end

@implementation MHPhotoBrowserVC

#pragma mark - Life cycles

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Gallery", nil);
    
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next", nil) style:UIBarButtonItemStyleDone target:self action:@selector(goToNext:)];
    item.tintColor = [UIColor blackColor];
    self.navigationItem.rightBarButtonItem = item;
    
    [self.view addSubview:self.cv];
    [self.cv mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self.view addSubview:self.authorizationView];
    [self.authorizationView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self checkAuthorizatonStatusFetchAllPhotos];
}

- (void)dealloc {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

#pragma mark - Private methods

- (void)fetchAllPhotos {
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    PHFetchOptions *allPhotosOptions = [PHFetchOptions new];
    allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    self.allPhotos = [PHAsset fetchAssetsWithOptions:allPhotosOptions];
    
    CGFloat scale = [UIScreen mainScreen].scale;
    self.thumnailSize = CGSizeMake(self.layout.itemSize.width * scale, self.layout.itemSize.height * scale);
    [self resetCachedAssets];
}

- (void)checkAuthorizatonStatusFetchAllPhotos {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    switch (status) {
        case PHAuthorizationStatusNotDetermined:
        {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    [self fetchAllPhotos];
                } else {
                    self.authorizationView.hidden = NO;
                }
            }];
            break;
        }
        case PHAuthorizationStatusAuthorized:
            [self fetchAllPhotos];
            break;
        case PHAuthorizationStatusDenied:
            self.authorizationView.hidden = NO;
            break;
        case PHAuthorizationStatusRestricted:
            break;
    }
}

#pragma mark - Target action methods

- (void)goToNext:(UIBarButtonItem *)sender {
    if (!self.selectedPhoto) {
        return;
    }
    MHPhotoEditVC *editVC = [[MHPhotoEditVC alloc] init];
    editVC.thumnailImage = self.selectedThumbnail;
    editVC.asset = self.selectedPhoto;
    [self.navigationController pushViewController:editVC animated:YES];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateCachedAssets];
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PHAsset *asset = self.allPhotos[indexPath.item];
    self.selectedPhoto = asset;
    MHPhotoBrowserCell *cell = (MHPhotoBrowserCell *)[collectionView cellForItemAtIndexPath:indexPath];
    self.selectedThumbnail = cell.thumbnailImage;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.allPhotos.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PHAsset *asset = self.allPhotos[indexPath.item];
    MHPhotoBrowserCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MHPhotoBrowserCell" forIndexPath:indexPath];
    cell.representedAssetIdentifier = asset.localIdentifier;
    if (@available(iOS 9.1, *)) {
        if (asset.mediaSubtypes & PHAssetMediaSubtypePhotoLive) {
            cell.livePhotoBadgeImage = [PHLivePhotoView livePhotoBadgeImageWithOptions:PHLivePhotoBadgeOptionsOverContent];
        }
    }
    [self.imageManager requestImageForAsset:asset targetSize:self.thumnailSize contentMode:PHImageContentModeAspectFill options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        if ([cell.representedAssetIdentifier isEqualToString:asset.localIdentifier]) {
            cell.thumbnailImage = result;
        }
    }];
    
    [[RACObserve(self, selectedPhoto) takeUntil:cell.rac_willDeallocSignal] subscribeNext:^(PHAsset * _Nullable x) {
        if ([cell.representedAssetIdentifier isEqualToString:x.localIdentifier]) {
            cell.selectedImage = [UIImage imageNamed:@"photobrowser_selected" inBundle:[self resourceBundle] compatibleWithTraitCollection:nil];
        } else {
            cell.selectedImage = nil;
        }
    }];
    return cell;
}

- (NSBundle *)resourceBundle {
    NSURL *bundleURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"MHPhotoBrowser" withExtension:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
    return bundle;
}
#pragma mark - Image cache

- (void)resetCachedAssets {
    [self.imageManager stopCachingImagesForAllAssets];
    self.previousPreheatRect = CGRectZero;
}

- (void)updateCachedAssets {
    if (!self.isViewLoaded || self.view.window == nil) {
        return;
    }
    CGPoint origin = self.cv.contentOffset;
    CGSize size = self.cv.bounds.size;
    CGRect visibleRect = CGRectMake(origin.x, origin.y, size.width, size.height);
    CGRect preheatRect = CGRectInset(visibleRect, 0, -0.5 * size.height);
    
    CGFloat delta = fabs(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    if (delta <= size.height / 3) {
        return;
    }
    
    CGRect added;
    CGRect removed;
    [self differencesBetweenRects:self.previousPreheatRect and:preheatRect added:&added removed:&removed];
    NSArray *addedAssets = [self assetsInRect:added];
    
    [self.imageManager startCachingImagesForAssets:addedAssets targetSize:self.thumnailSize contentMode:PHImageContentModeAspectFill options:nil];
    //不取消缓存，观察后续表现
    //    NSArray *removedAssets = [self assetsInRect:removed];
    //    [self.imageManager stopCachingImagesForAssets:removedAssets targetSize:self.thumnailSize contentMode:PHImageContentModeAspectFill options:nil];
    
    self.previousPreheatRect = preheatRect;
}

- (NSArray<PHAsset *> *)assetsInRect:(CGRect)rect {
    NSArray<UICollectionViewLayoutAttributes *> *allLayoutAttritues = [self.cv.collectionViewLayout layoutAttributesForElementsInRect:rect];
    NSMutableArray *indexPaths = [NSMutableArray new];
    for (UICollectionViewLayoutAttributes *attributes in allLayoutAttritues) {
        [indexPaths addObject:attributes.indexPath];
    }
    NSMutableArray<PHAsset *> *ret = [NSMutableArray new];
    for (NSIndexPath *indexPath in indexPaths) {
        PHAsset *asset = self.allPhotos[indexPath.item];
        [ret addObject:asset];
    }
    return [ret copy];
}

- (void)differencesBetweenRects:(CGRect)old and:(CGRect)new added:(CGRect *)added removed:(CGRect *)removed {
    CGRect intersectRet = CGRectIntersection(old, new);
    if (CGRectIsNull(intersectRet)) {
        *added = new;
        *removed = old;
    } else {
        CGFloat newMaxY = CGRectGetMaxY(new);
        CGFloat oldMaxY = CGRectGetMaxY(old);
        CGFloat newMinY = CGRectGetMinY(new);
        CGFloat oldMinY = CGRectGetMinY(old);
        
        CGRect addedRet;
        if (newMaxY > oldMaxY) {
            addedRet = CGRectMake(new.origin.x, oldMaxY, new.size.width, newMaxY - oldMaxY);
        } else { //oldMinY > newMinY
            addedRet = CGRectMake(new.origin.x, newMinY, new.size.width, oldMinY - newMinY);
        }
        CGRect removedRet;
        if (newMaxY < oldMaxY) {
            removedRet = CGRectMake(new.origin.x, newMaxY, new.size.width, oldMaxY - newMaxY);
        } else { //oldMinY > newMinY
            removedRet = CGRectMake(new.origin.x, oldMinY, new.size.width, newMinY - oldMinY);
        }
        *added = addedRet;
        *removed = removedRet;
    }
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    PHFetchResultChangeDetails *changes = [changeInstance changeDetailsForFetchResult:self.allPhotos];
    if (!changes) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([changes hasIncrementalChanges]) {
            self.allPhotos = [changes fetchResultAfterChanges];
            [self.cv performBatchUpdates:^{
                NSIndexSet *removedIndexes = [changes removedIndexes];
                [removedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:idx inSection:0];
                    [self.cv deleteItemsAtIndexPaths:@[indexPath]];
                }];
                NSIndexSet *insertedIndexes = [changes insertedIndexes];
                [insertedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:idx inSection:0];
                    [self.cv insertItemsAtIndexPaths:@[indexPath]];
                }];
                [changes enumerateMovesWithBlock:^(NSUInteger fromIndex, NSUInteger toIndex) {
                    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForItem:fromIndex inSection:0];
                    NSIndexPath *toIndexPath = [NSIndexPath indexPathForItem:toIndex inSection:0];
                    [self.cv moveItemAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
                }];
            } completion:^(BOOL finished) {
                NSIndexSet *changedIndexes = [changes changedIndexes];
                [changedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:idx inSection:0];
                    [self.cv reloadItemsAtIndexPaths:@[indexPath]];
                }];
            }];
        } else {
            [self.cv reloadData];
        }
        [self resetCachedAssets];
    });
}

#pragma mark - Lazy load

- (UICollectionView *)cv {
    if (!_cv) {
        _cv = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:self.layout];
        _cv.backgroundColor = [UIColor whiteColor];
        [_cv registerClass:[MHPhotoBrowserCell class] forCellWithReuseIdentifier:@"MHPhotoBrowserCell"];
        _cv.dataSource = self;
        _cv.delegate = self;
    }
    return _cv;
}

- (UICollectionViewFlowLayout *)layout {
    if (!_layout) {
        _layout = [UICollectionViewFlowLayout new];
        _layout.scrollDirection = UICollectionViewScrollDirectionVertical;
        _layout.minimumLineSpacing = 1;
        _layout.minimumInteritemSpacing = 1;
        CGFloat width = (([UIScreen mainScreen].bounds.size.width - _layout.minimumLineSpacing * 3) / 4);
        _layout.itemSize = CGSizeMake(width, width);
    }
    return _layout;
}

- (PHCachingImageManager *)imageManager {
    if (!_imageManager) {
        _imageManager = [PHCachingImageManager new];
    }
    return _imageManager;
}

- (MHPhotoBrowserAuthorizationView *)authorizationView {
    if (!_authorizationView) {
        _authorizationView = [MHPhotoBrowserAuthorizationView new];
        _authorizationView.hidden = YES;
    }
    return _authorizationView;
}

@end
