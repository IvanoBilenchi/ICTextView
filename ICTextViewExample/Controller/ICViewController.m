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

@property (nonatomic, strong) ICTextView *textView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIToolbar *toolBar;
@property (nonatomic, strong) UILabel *countLabel;

@end

#pragma mark - Implementation

@implementation ICViewController

#pragma mark - Properties

@synthesize countLabel = _countLabel;
@synthesize searchBar = _searchBar;
@synthesize textView = _textView;
@synthesize toolBar = _toolBar;

#pragma mark - Self

- (void)loadView
{
    CGRect tempFrame = [UIScreen mainScreen].bounds;
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, 0.0, tempFrame.size.width, 44.0)];
    searchBar.delegate = self;
    
    if ([searchBar respondsToSelector:@selector(setInputAccessoryView:)])
    {
        UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0, 0.0, tempFrame.size.width, 34.0)];
        
        UIBarButtonItem *prevButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Prev"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(searchPreviousMatch)];
        
        UIBarButtonItem *nextButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Next"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(searchNextMatch)];
        
        UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        
        UILabel *countLabel = [[UILabel alloc] init];
        countLabel.textAlignment = NSTextAlignmentRight;
        countLabel.textColor = [UIColor grayColor];
        
        UIBarButtonItem *counter = [[UIBarButtonItem alloc] initWithCustomView:countLabel];
        
        toolBar.items = [[NSArray alloc] initWithObjects:prevButtonItem, nextButtonItem, spacer, counter, nil];
        
        [(id)searchBar setInputAccessoryView:toolBar];
        
        self.toolBar = toolBar;
        self.countLabel = countLabel;
    }
    
    UIView *mainView = [[UIView alloc] initWithFrame:tempFrame];
    
    ICTextView *textView = [[ICTextView alloc] initWithFrame:tempFrame];
    textView.font = [UIFont systemFontOfSize:14.0];
    textView.circularSearch = YES;
    textView.scrollPosition = ICTextViewScrollPositionMiddle;
    textView.searchOptions = NSRegularExpressionCaseInsensitive;
    
    [mainView addSubview:textView];
    [mainView addSubview:searchBar];
    
    self.searchBar = searchBar;
    self.textView = textView;
    self.view = mainView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self updateTextViewInsetsWithKeyboardNotification:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateTextViewInsetsWithKeyboardNotification:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    
    ICTextView *textView = self.textView;
	textView.text = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ICTextView" ofType:@"h"]
                                              encoding:NSASCIIStringEncoding
                                                 error:NULL];
    
    [textView scrollRectToVisible:CGRectZero animated:NO consideringInsets:YES];
    [self updateCountLabel];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.searchBar becomeFirstResponder];
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
    [self.textView becomeFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self searchNextMatch];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = nil;
    [self.textView resetSearch];
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
    NSString *searchString = self.searchBar.text;
    
    if (searchString.length)
        [self.textView scrollToString:searchString searchDirection:direction];
    else
        [self.textView resetSearch];
    
    [self updateCountLabel];
}

- (void)updateCountLabel
{
    ICTextView *textView = self.textView;
    UILabel *countLabel = self.countLabel;
    
    NSUInteger numberOfMatches = textView.numberOfMatches;
    countLabel.text = numberOfMatches ? [NSString stringWithFormat:@"%lu/%lu", (unsigned long)textView.indexOfFoundString + 1, (unsigned long)numberOfMatches] : @"0/0";
    [countLabel sizeToFit];
}

#pragma mark - Keyboard

- (void)updateTextViewInsetsWithKeyboardNotification:(NSNotification *)notification
{
    UIEdgeInsets newInsets = UIEdgeInsetsZero;
    newInsets.top = self.searchBar.frame.size.height;
    
    if (notification)
    {
        CGRect keyboardFrame;
        
        [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardFrame];
        keyboardFrame = [self.view convertRect:keyboardFrame fromView:nil];
        
        newInsets.bottom = self.view.frame.size.height - keyboardFrame.origin.y;
    }
    
    ICTextView *textView = self.textView;
    textView.contentInset = newInsets;
    textView.scrollIndicatorInsets = newInsets;
}

@end
