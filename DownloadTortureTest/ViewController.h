//
//  ViewController.h
//  DownloadTortureTest
//
//  Created on 5/27/13.
//  Copyright (c) 2013 Box, Inc. All rights reserved.
//
#import <BoxSDK/BoxSDK.h>


@interface ViewController : UIViewController <BoxFolderPickerDelegate>
- (IBAction)browseAction:(id)sender;
- (IBAction)purgeAction:(id)sender;

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *idLabel;

@property (weak, nonatomic) IBOutlet UILabel *totalDownloadsDescriptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalDownloadsLabel;
@property (weak, nonatomic) IBOutlet UILabel *downloadsPerSecondDescriptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *downloadsPerSecondLabel;

@end
