//
//  ICAppDelegate.m
//  ICTextViewExample
//
//  Created by Ivano Bilenchi on 05/11/13.
//  Copyright (c) 2013 Ivano Bilenchi. All rights reserved.
//

#import "ICAppDelegate.h"
#import "ICViewController.h"

@interface ICAppDelegate ()
{
    UIWindow *_mainWindow;
}
@end

@implementation ICAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _mainWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    ICViewController *rootController = [[ICViewController alloc] init];
    _mainWindow.rootViewController = rootController;
    _mainWindow.backgroundColor = [UIColor whiteColor];
    [_mainWindow makeKeyAndVisible];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    return YES;
}

@end
