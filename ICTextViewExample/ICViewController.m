//
//  ICViewController.m
//  ICTextViewExample
//
//  Created by Ivano Bilenchi on 05/11/13.
//  Copyright (c) 2013 Ivano Bilenchi. All rights reserved.
//

#import "ICViewController.h"
#import "ICTextView.h"

// For older SDKs
#ifndef NSFoundationVersionNumber_iOS_6_1
#define NSFoundationVersionNumber_iOS_6_1 993.0
#endif

@interface ICViewController ()
{
    ICTextView *_textView;
    UISearchBar *_searchBar;
}
@end

@implementation ICViewController

#pragma mark - Self

- (void)loadView
{
    BOOL iOS7 = NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1; // sigh
    
    CGRect tempFrame = [UIScreen mainScreen].applicationFrame;
    CGFloat statusBarOffset = iOS7 ? 20.0 : 0.0; // I'm being lazy here
    
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, statusBarOffset, tempFrame.size.width, 44.0)];
    _searchBar.delegate = self;
    
    UIView *mainView = [[UIView alloc] initWithFrame:tempFrame];
    
    CGFloat keyboardHeight = 216.0; // Again, lazy
    CGFloat searchBarHeight = _searchBar.frame.size.height;
    if (!iOS7)
        tempFrame.origin.y = 0.0;
    _textView = [[ICTextView alloc] initWithFrame:tempFrame];
    UIEdgeInsets tempInsets = UIEdgeInsetsMake(searchBarHeight, 0.0, keyboardHeight, 0.0);
    _textView.contentInset = tempInsets;
    _textView.font = [UIFont systemFontOfSize:14.0];
    _textView.scrollIndicatorInsets = tempInsets;
    
    [mainView addSubview:_textView];
    [mainView addSubview:_searchBar];
    self.view = mainView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	_textView.text = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ICTextView" ofType:@"h"] encoding:NSASCIIStringEncoding error:NULL];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_searchBar becomeFirstResponder];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if (!searchText || [searchText isEqualToString:@""])
    {
        [_textView resetSearch];
        return;
    }
    [_textView scrollToString:searchText searchOptions:NSRegularExpressionCaseInsensitive animated:YES atScrollPosition:ICTextViewScrollPositionMiddle];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [_textView becomeFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [_textView scrollToString:searchBar.text searchOptions:NSRegularExpressionCaseInsensitive animated:YES atScrollPosition:ICTextViewScrollPositionMiddle];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = nil;
    [_textView resetSearch];
}

@end
