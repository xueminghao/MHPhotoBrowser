//
//  MHViewController.m
//  MHPhotoBrowser
//
//  Created by 薛明浩 on 01/21/2019.
//  Copyright (c) 2019 薛明浩. All rights reserved.
//

#import "MHViewController.h"

#import <MHPhotoBrowser/MHPhotoBrowser.h>

@interface MHViewController ()

@end

@implementation MHViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)pushBtnClicked:(id)sender {
    MHPhotoBrowserVC *vc = [MHPhotoBrowserVC new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)presentBtnClicked:(id)sender {
    MHPhotoBrowserVC *vc = [MHPhotoBrowserVC new];
    UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:navi animated:YES completion:nil];
}

@end
