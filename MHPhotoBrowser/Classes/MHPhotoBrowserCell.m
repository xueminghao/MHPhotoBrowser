//
//  MHPhotoBrowserCell.m
//  MHPhotoBrowser
//
//  Created by Minghao Xue on 2019/1/21.
//

#import "MHPhotoBrowserCell.h"
#import <Masonry/Masonry.h>

@interface MHPhotoBrowserCell ()

@property (nonatomic, strong) UIImageView *iv;
@property (nonatomic, strong) UIImageView *livePhotoBadgeImageView;
@property (nonatomic, strong) UIImageView *selectedIv;

@end

@implementation MHPhotoBrowserCell

#pragma mark - Life cycles

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:(CGRect)frame]) {
        [self.contentView addSubview:self.iv];
        [self.iv mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
        [self.contentView addSubview:self.livePhotoBadgeImageView];
        [self.livePhotoBadgeImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.equalTo(self.contentView);
            make.width.height.equalTo(@28);
        }];
        [self.contentView addSubview:self.selectedIv];
        [self.selectedIv mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.right.equalTo(self.contentView).offset(-4);
            make.height.with.equalTo(@22);
        }];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.livePhotoBadgeImageView.image = nil;
    self.iv.image = nil;
    self.selectedIv.image = nil;
}

#pragma mark - Getters & Setters

- (void)setThumbnailImage:(UIImage *)thumbnailImage {
    _thumbnailImage = thumbnailImage;
    self.iv.image = thumbnailImage;
}

- (void)setLivePhotoBadgeImage:(UIImage *)livePhotoBadgeImage {
    _livePhotoBadgeImage = livePhotoBadgeImage;
    self.livePhotoBadgeImageView.image = _livePhotoBadgeImage;
}

- (void)setSelectedImage:(UIImage *)selectedImage {
    _selectedImage = selectedImage;
    self.selectedIv.image = selectedImage;
}

- (UIImageView *)iv {
    if (!_iv) {
        _iv = [UIImageView new];
        _iv.contentMode = UIViewContentModeScaleAspectFill;
        _iv.clipsToBounds = YES;
    }
    return _iv;
}

- (UIImageView *)livePhotoBadgeImageView {
    if (!_livePhotoBadgeImageView) {
        _livePhotoBadgeImageView = [UIImageView new];
    }
    return _livePhotoBadgeImageView;
}

- (UIImageView *)selectedIv {
    if (!_selectedIv) {
        _selectedIv = [UIImageView new];
        _selectedIv.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _selectedIv;
}

@end
