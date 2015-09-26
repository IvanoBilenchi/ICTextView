//
//  ICViewController.m
//  ICTextViewExample
//
//  Created by Ivano Bilenchi on 05/11/13.
//  Copyright (c) 2013 Ivano Bilenchi. All rights reserved.
//
//  Disclaimer: this is a sample app, so most of the logic is dropped here in the controller.
//  In production apps, you want to move layout logic to UIView subclasses, and have a proper model layer.
//

#import "ICViewController.h"
#import "ICTextView.h"
#import "Preprocessor.h"

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
    [super loadView];
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.searchBar = searchBar;
    searchBar.delegate = self;
    
    if ([searchBar respondsToSelector:@selector(setInputAccessoryView:)])
    {
        UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:CGRectZero];
        
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
    
    ICTextView *textView = [[ICTextView alloc] initWithFrame:CGRectZero];
    self.textView = textView;
    textView.font = [UIFont systemFontOfSize:14.0];
    textView.circularSearch = YES;
    textView.scrollPosition = ICTextViewScrollPositionMiddle;
    textView.searchOptions = NSRegularExpressionCaseInsensitive;
    
    [self.view addSubview:textView];
    [self.view addSubview:searchBar];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self updateTextViewInsetsWithKeyboardNotification:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateTextViewInsetsWithKeyboardNotification:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"ICTextView" ofType:@"h"];
    
    if (filePath)
    {
        self.textView.text = [NSString stringWithContentsOfFile:filePath
                                                       encoding:NSASCIIStringEncoding
                                                          error:NULL];
    }
    
    [self updateCountLabel];
}

- (void)viewDidLayoutSubviews
{
    CGRect viewBounds = self.view.bounds;
    
    CGRect searchBarFrame = viewBounds;
    searchBarFrame.size.height = 44.0f;
    
    CGRect toolBarFrame = viewBounds;
    toolBarFrame.size.height = 34.0f;
    
    self.searchBar.frame = searchBarFrame;
    self.toolBar.frame = toolBarFrame;
    self.textView.frame = viewBounds;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.searchBar becomeFirstResponder];
    [self.textView scrollRectToVisible:CGRectZero animated:YES consideringInsets:YES];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    _Pragma("unused(searchBar, searchText)")
    [self searchNextMatch];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    _Pragma("unused(searchBar)")
    [self.textView becomeFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    _Pragma("unused(searchBar)")
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
