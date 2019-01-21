//
//  MHPhotoBrowserAuthorizationView.m
//  MHPhotoBrowser
//
//  Created by Minghao Xue on 2019/1/21.
//

#import "MHPhotoBrowserAuthorizationView.h"
#import <Masonry/Masonry.h>

@interface MHPhotoBrowserAuthorizationView ()

@property (nonatomic, strong) UIButton *btn;

@end

@implementation MHPhotoBrowserAuthorizationView

- (instancetype)init {
    if (self = [super init]) {
        [self addSubview:self.btn];
        [self.btn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
        }];
    }
    return self;
}

- (UIButton *)btn {
    if (!_btn) {
        _btn = [UIButton new];
        [_btn setTitle:NSLocalizedString(@"Access denied", nil) forState:UIControlStateNormal];
        [_btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    }
    return _btn;
}
@end
