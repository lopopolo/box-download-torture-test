//
//  AppDelegate.m
//  DownloadTortureTest
//
//  Created on 5/27/13.
//  Copyright (c) 2013 Box, Inc. All rights reserved.
//

#import "AppDelegate.h"
#import <BoxSDK/BoxSDK.h>
#import "ViewController.h"

#import "KeychainItemWrapper.h"

#define REFRESH_TOKEN_KEY   (@"box_api_refresh_token")

@interface AppDelegate ()

@property (nonatomic, readwrite, strong) KeychainItemWrapper *keychain;
- (void)boxAPITokensDidRefresh:(NSNotification *)notification;
- (void)setRefreshTokenInKeychain:(NSString *)refreshToken;

@end

@implementation AppDelegate

@synthesize keychain = _keychain;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Setup BoxSDK
#error Set your client ID and client secret in the BoxSDK
    [BoxSDK sharedSDK].OAuth2Session.clientID = @"YOUR_CLIENT_ID";
    [BoxSDK sharedSDK].OAuth2Session.clientSecret = @"YOUR_CLIENT_SECRET";

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(boxAPITokensDidRefresh:)
                                                 name:BoxOAuth2SessionDidBecomeAuthenticatedNotification
                                               object:[BoxSDK sharedSDK].OAuth2Session];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(boxAPITokensDidRefresh:)
                                                 name:BoxOAuth2SessionDidRefreshTokensNotification
                                               object:[BoxSDK sharedSDK].OAuth2Session];
    
    // set up stored OAuth2 refresh token
    self.keychain = [[KeychainItemWrapper alloc] initWithIdentifier:REFRESH_TOKEN_KEY accessGroup:nil];

    id storedRefreshToken = [self.keychain objectForKey:(__bridge id)kSecValueData];
    if (storedRefreshToken)
    {
        [BoxSDK sharedSDK].OAuth2Session.refreshToken = storedRefreshToken;
    }

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.viewController = [[ViewController alloc] initWithNibName:@"ViewController_iPhone" bundle:nil];
    } else {
        self.viewController = [[ViewController alloc] initWithNibName:@"ViewController_iPad" bundle:nil];
    }
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)boxAPITokensDidRefresh:(NSNotification *)notification
{
    BoxOAuth2Session *OAuth2Session = (BoxOAuth2Session *) notification.object;
    [self setRefreshTokenInKeychain:OAuth2Session.refreshToken];
}

- (void)setRefreshTokenInKeychain:(NSString *)refreshToken
{
    [self.keychain setObject:@"DownloadTortureTest" forKey: (__bridge id)kSecAttrService];
    [self.keychain setObject:refreshToken forKey:(__bridge id)kSecValueData];
}

- (void)logoutFromBox
{
    // clear Tokens from memory
    [BoxSDK sharedSDK].OAuth2Session.accessToken = @"INVALID_ACCESS_TOKEN";
    // make sure OAuth2Session.isAuthorized returns NO
    [BoxSDK sharedSDK].OAuth2Session.accessTokenExpiration = [NSDate dateWithTimeIntervalSince1970:0.];
    [BoxSDK sharedSDK].OAuth2Session.refreshToken = @"INVALID_REFRESH_TOKEN";

    // clear tokens from keychain
    [self setRefreshTokenInKeychain:@"INVALID_REFRESH_TOKEN"];
}

@end
