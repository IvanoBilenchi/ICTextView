//
//  ICViewController.m
//  ICTextViewExample
//
//  Created by Ivano Bilenchi on 05/11/13.
//  Copyright (c) 2013 Ivano Bilenchi. All rights reserved.
//

#import "ICViewController.h"
#import "ICTextView.h"
#import "Compatibility.h"

#pragma mark Extension

@interface ICViewController ()
{
    ICTextView *_textView;
    UISearchBar *_searchBar;
    UIToolbar *_toolBar;
    UILabel *_countLabel;
}
@end

#pragma mark - Implementation

@implementation ICViewController

#pragma mark - Self

- (void)loadView
{
    CGRect tempFrame = [UIScreen mainScreen].bounds;
    
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, 0.0, tempFrame.size.width, 44.0)];
    _searchBar.delegate = self;
    
    if ([_searchBar respondsToSelector:@selector(setInputAccessoryView:)])
    {
        _toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0, 0.0, tempFrame.size.width, 34.0)];
        
        UIBarButtonItem *prevButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Prev"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(searchPreviousMatch)];
        
        UIBarButtonItem *nextButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Next"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(searchNextMatch)];
        
        UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        
        _countLabel = [[UILabel alloc] init];
        _countLabel.textAlignment = NSTextAlignmentRight;
        _countLabel.textColor = [UIColor grayColor];
        
        UIBarButtonItem *counter = [[UIBarButtonItem alloc] initWithCustomView:_countLabel];
        
        _toolBar.items = [[NSArray alloc] initWithObjects:prevButtonItem, nextButtonItem, spacer, counter, nil];
        
        [(id)_searchBar setInputAccessoryView:_toolBar];
    }
    
    UIView *mainView = [[UIView alloc] initWithFrame:tempFrame];
    
    _textView = [[ICTextView alloc] initWithFrame:tempFrame];
    _textView.font = [UIFont systemFontOfSize:14.0];
    
    [mainView addSubview:_textView];
    [mainView addSubview:_searchBar];
    self.view = mainView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self updateTextViewInsetsWithKeyboardNotification:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTextViewInsetsWithKeyboardNotification:) name:UIKeyboardWillChangeFrameNotification object:nil];
    
    _textView.circularSearch = YES;
    _textView.scrollPosition = ICTextViewScrollPositionMiddle;
    _textView.searchOptions = NSRegularExpressionCaseInsensitive;
    
	_textView.text = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ICTextView" ofType:@"h"] encoding:NSASCIIStringEncoding error:NULL];
    
    [_textView scrollRectToVisible:CGRectZero animated:NO consideringInsets:YES];
    
    [self updateCountLabel];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_searchBar becomeFirstResponder];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self searchNextMatch];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [_textView becomeFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self searchNextMatch];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = nil;
    [_textView resetSearch];
    [self updateCountLabel];
}

#pragma mark - ICTextView

- (void)searchNextMatch
{
    [self searchMatchInDirection:ICTextViewSearchDirectionForward];
}

- (void)searchPreviousMatch
{
    [self searchMatchInDirection:ICTextViewSearchDirectionBackward];
}

- (void)searchMatchInDirection:(ICTextViewSearchDirection)direction
{
    NSString *searchString = _searchBar.text;
    
    if (searchString.length)
        [_textView scrollToString:searchString searchDirection:direction];
    else
        [_textView resetSearch];
    
    [self updateCountLabel];
}

- (void)updateCountLabel
{
    NSUInteger numberOfMatches = _textView.numberOfMatches;
    _countLabel.text = numberOfMatches ? [NSString stringWithFormat:@"%u/%u", _textView.indexOfFoundString + 1, numberOfMatches] : @"0/0";
    [_countLabel sizeToFit];
}

#pragma mark - Keyboard

- (void)updateTextViewInsetsWithKeyboardNotification:(NSNotification *)notification
{
    UIEdgeInsets newInsets = UIEdgeInsetsZero;
    newInsets.top = _searchBar.frame.size.height;
    
    if (notification)
    {
        CGRect keyboardFrame;
        
        [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardFrame];
        keyboardFrame = [self.view convertRect:keyboardFrame fromView:nil];
        
        newInsets.bottom = self.view.frame.size.height - keyboardFrame.origin.y;
    }
    
    _textView.contentInset = newInsets;
    _textView.scrollIndicatorInsets = newInsets;
}

@end
