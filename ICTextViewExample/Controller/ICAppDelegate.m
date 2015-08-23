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
@property (nonatomic, strong) UIWindow *mainWindow;
@end

@implementation ICAppDelegate

@synthesize mainWindow = _mainWindow;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _Pragma("unused(application, launchOptions)")
    
    UIWindow *mainWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    ICViewController *rootController = [[ICViewController alloc] init];
    mainWindow.rootViewController = rootController;
    mainWindow.backgroundColor = [UIColor whiteColor];
    [mainWindow makeKeyAndVisible];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.mainWindow = mainWindow;
    return YES;
}

@end
