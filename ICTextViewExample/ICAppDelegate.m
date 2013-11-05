//
//  ICAppDelegate.m
//  ICTextViewExample
//
//  Created by Ivano Bilenchi on 05/11/13.
//  Copyright (c) 2013 Ivano Bilenchi. All rights reserved.
//

#import "ICAppDelegate.h"
#import "ICViewController.h"

@implementation ICAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    ICViewController *rootController = [[ICViewController alloc] init];
    self.window.rootViewController = rootController;
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
