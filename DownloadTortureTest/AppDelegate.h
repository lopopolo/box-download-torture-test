//
//  AppDelegate.h
//  DownloadTortureTest
//
//  Created on 5/27/13.
//  Copyright (c) 2013 Box, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

/**
 * Destroy the current BoxOAuth2Session, remove tokens from memory,
 * remove tokens from keychain.
 */
- (void)logoutFromBox;

@end
