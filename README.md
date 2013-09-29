# DownloadTortureTest

This app uses the [Box iOS SDK](https://github.com/box/box-ios-sdk-v2) to download a file repeatedly.

The app uses the iOS Folder Picker widget to prompt the user for a file from their account. Upon
selection, the app will enqueue 100 download operations with the SDK. As each download completes,
the app will reenqueue another download.

Each operation will detect if it has been rate limited and back off on downloads if that is the case.
All other errors will result in the operation chain exiting.

This app simulates a pathological scenario to test for resource leaks.

![Memory profile in XCode 5](https://raw.github.com/lopopolo/box-download-torture-test/master/mem-profile.png)

Memory usage is pretty constant over a 15 minute test.

