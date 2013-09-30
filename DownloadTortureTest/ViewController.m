//
//  ViewController.m
//  DownloadTortureTest
//
//  Created on 5/27/13.
//  Copyright (c) 2013 Box, Inc. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"

// This constant defines the simulataneous number of download operations
// to enqueue with the SDK. The SDK may not execute all of the scheduled
// operations simultaneously.
// The BoxParallelAPIQueueManager limits the NSOperationQueue to 10
// simultaneous downloads
#define TORTURE_TEST_SIMULTANEOUS_DOWNLOAD_OPERATIONS     (100U)

#define TORTURE_TEST_DOWNLOAD_PREFIX                      (@"torture-test-downloads")

@interface BoxFolderPickerNavigationController (DownloadTortureTest)
@end

@implementation BoxFolderPickerNavigationController (DownloadTortureTest)

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleBlackTranslucent;
}

@end

@interface ViewController ()

@property (nonatomic, readwrite, strong) BoxFolderPickerViewController *folderPicker;

@property (nonatomic, readwrite, assign) NSUInteger completedDownloads;
@property (atomic, readwrite, strong) NSDate *downloadTestStart;

- (void)presentBoxFolderPicker;
- (void)boxError:(NSError*)error;

/**
 * Set up the torture test for a given copy of the file to download.
 * Each copy is written to disk independently.
 *
 * @param copy The operation number.
 * @param file The file to download.
 */
- (void)initiateDownloadForCopy:(NSUInteger)copy file:(BoxFile *)file;

/**
 * Update download statistics and refresh UI.
 */
- (void)logCompletedDownload;

@end

@implementation ViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)presentBoxFolderPicker
{
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        NSString *thumbnailPath = [basePath stringByAppendingPathComponent:@"BOX"];

        self.folderPicker = [[BoxSDK sharedSDK] folderPickerWithRootFolderID:BoxAPIFolderIDRoot
                                                           thumbnailsEnabled:YES
                                                        cachedThumbnailsPath:thumbnailPath
                                                        fileSelectionEnabled:YES];
        self.folderPicker.delegate = self;

        UINavigationController *controller = [[BoxFolderPickerNavigationController alloc] initWithRootViewController:self.folderPicker];
        controller.modalPresentationStyle = UIModalPresentationFormSheet;
        controller.view.tintColor = [UIColor whiteColor];

        [self presentViewController:controller animated:YES completion:nil];
    });
}

- (void)boxError:(NSError*)error
{
    if (error.code == BoxSDKOAuth2ErrorAccessTokenExpiredOperationReachedMaxReenqueueLimit)
    {
        // Launch the picker again if for some reason the OAuth2 session cannot be refreshed.
        // this will bring the login screen which will be followed by the file picker itself
        [self presentBoxFolderPicker];
        return;
    }
    else if (error.code == BoxSDKOAuth2ErrorAccessTokenExpired)
    {
        // This error code appears as part of the re-authentication process and should be ignored
        return;
    }
    else
    {
        // we really failed, let the user know
        dispatch_sync(dispatch_get_main_queue(), ^(void){
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Box" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        });
    }
}

- (IBAction)browseAction:(id)sender {
    if ([BoxSDK sharedSDK].OAuth2Session.isAuthorized)
    {
        // in order to avoid a short lag, jump immediatly to the file picker if we are already authorized
        [self presentBoxFolderPicker];
    }
    else
    {
        BoxFolderBlock success = ^(BoxFolder * folder) {
            [self presentBoxFolderPicker];
        };
        BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary){
            [self boxError:error];
        };
        // try sending a hearbeat
        [[BoxSDK sharedSDK].foldersManager folderInfoWithID:BoxAPIFolderIDRoot
                                             requestBuilder:nil
                                                    success:success
                                                    failure:failure];
    }
}

- (IBAction)purgeAction:(id)sender
{
    [self.folderPicker purgeCache];

    // purge downloads
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [documentPaths objectAtIndex:0];
    NSString *path = cachePath;
    path = [path stringByAppendingPathComponent:TORTURE_TEST_DOWNLOAD_PREFIX];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}


- (void)folderPickerController:(BoxFolderPickerViewController *)controller didSelectBoxItem:(BoxItem *)item
{
    [self dismissViewControllerAnimated:YES completion:^{
        self.nameLabel.text = [NSString stringWithFormat:@"%@ picked : %@", item.type, item.name];
        self.idLabel.text = item.modelID;

        BOXAssert([item.type isEqualToString:BoxAPIItemTypeFile], @"Folder picker should only allow file selection");
        BoxFile *file = (BoxFile *)item;

        self.completedDownloads = 0;
        self.downloadTestStart = [NSDate dateWithTimeIntervalSinceNow:0];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.downloadsPerSecondDescriptionLabel.hidden = NO;
            self.downloadsPerSecondLabel.hidden = NO;
            self.totalDownloadsDescriptionLabel.hidden = NO;
            self.totalDownloadsLabel.hidden = NO;
        });

        for (NSUInteger i=0; i < TORTURE_TEST_SIMULTANEOUS_DOWNLOAD_OPERATIONS; ++i)
        {
            [self initiateDownloadForCopy:i file:file];
        }
    }];
    
}

- (void)logCompletedDownload
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized(self) {
            self.completedDownloads += 1;
            self.totalDownloadsLabel.text = [NSString stringWithFormat:@"%d", self.completedDownloads];
            NSTimeInterval elapsedTime = abs([self.downloadTestStart timeIntervalSinceNow]);
            self.downloadsPerSecondLabel.text = [NSString stringWithFormat:@"%.3f", (float) self.completedDownloads / elapsedTime];
        }
    });

}

- (void)initiateDownloadForCopy:(NSUInteger)copy file:(BoxFile *)file
{
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [documentPaths objectAtIndex:0];
    NSString *path = cachePath;
    path = [path stringByAppendingPathComponent:TORTURE_TEST_DOWNLOAD_PREFIX];
    path = [path stringByAppendingPathComponent:file.modelID];
    path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%d",copy]];

    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:path append:NO];

    BoxDownloadSuccessBlock successBlock = ^(NSString *downloadedFileID, long long expectedContentLength)
    {
        BOXLog(@"Successfully downloaded file for copy %d", copy);
        BOXLog(@"Re-enqueueing download for copy %d", copy);
        [self logCompletedDownload];
        [self initiateDownloadForCopy:copy file:file];
    };

    BoxDownloadFailureBlock failureBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error)
    {
        BOXLog(@"Download for copy %d failed with status code %d", copy, response.statusCode);
        if (error.code == BoxSDKAPIErrorTooManyRequests)
        {
            double delayInSeconds = [[[response allHeaderFields] objectForKey:@"Retry-After"] doubleValue];

            BOXLog(@"Rate limited for download request for copy %d with retry-after: %f", copy, delayInSeconds);
            BOXLog(@"Scheduling retry after being rate limited for copy %d", copy);

            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self initiateDownloadForCopy:copy file:file];
            });
        }
    };

    [[BoxSDK sharedSDK].filesManager downloadFileWithID:file.modelID outputStream:outputStream requestBuilder:nil success:successBlock failure:failureBlock];
}

- (void)folderPickerControllerDidCancel:(BoxFolderPickerViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

/**
 * We must provide a way to logout from Box because otherwise there is no way to switch Box users.
 * Even deleting the App will not help because the refreshToken is stored in the keychain which is retained
 *
 * @NOTE: This method does not purge the folder picker's thumbnail cache, which you probably want to
 * do during a real logout.
 */
- (IBAction)logoutAction:(id)sender {
    AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
    [appDelegate logoutFromBox];
}

@end
