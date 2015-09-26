/**
 * ICTextView.m
 * ------------
 * https://github.com/Exile90/ICTextView.git
 *
 *
 * Authors:
 * --------
 * Ivano Bilenchi (@SoftHardW)
 *
 *
 * License:
 * --------
 * Copyright (c) 2013-2015 Ivano Bilenchi
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 **/

#import "ICTextView.h"
#import "ICPreprocessor.h"
#import "ICRangeUtils.h"
#import "ICRegularExpression.h"

#import <Availability.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark Constants

static NSUInteger const ICSearchIndexAuto = NSUIntegerMax;
static NSTimeInterval const ICMinScrollAutoRefreshDelay = 0.1;

#pragma mark - Globals

// Search results highlighting supported starting from iOS 5.x
static BOOL highlightingSupported = NO;

// Accounts for textContainerInset on iOS 7+
static BOOL textContainerInsetSupported = NO;

// Fixes
static BOOL shouldApplyBecomeFirstResponderFix = NO;
static BOOL shouldApplyCaretFix = NO;
static BOOL shouldApplyCharacterRangeAtPointFix = NO;
static BOOL shouldApplyTextContainerFix = NO;

#pragma mark - Helper

NS_INLINE BOOL ICCGFloatEqualOnScreen(CGFloat f1, CGFloat f2)
{
    static CGFloat epsilon = CGFLOAT_MIN;
    
    if (epsilon < 0.0f)
        epsilon = (1.0f / [[UIScreen mainScreen] scale]);
    
    return (ABS(f1 - f2) < epsilon);
}

#pragma mark - Extension

@interface ICTextView ()

// Highlights
@property (nonatomic, strong) NSMutableDictionary *highlightsByRange;
@property (nonatomic, strong) NSMutableArray *primaryHighlights;
@property (nonatomic, strong) NSMutableOrderedSet *secondaryHighlights;

// Work
@property (nonatomic, unsafe_unretained) NSTimer *autoRefreshTimer;
@property (nonatomic, strong) ICRegularExpression *regex;
@property (nonatomic) NSRange cachedRange;
@property (nonatomic) NSUInteger searchIndex;
@property (nonatomic, strong, readonly) UIView *textSubview;

// Flags
@property (nonatomic) BOOL appliedSelectionFix;
@property (nonatomic) BOOL performedNewScroll;
@property (nonatomic) BOOL searching;
@property (nonatomic) BOOL searchVisibleRange;

@end

#pragma mark - Implementation

@implementation ICTextView

#pragma mark - Properties

// autoRefreshTimer
@synthesize autoRefreshTimer = _autoRefreshTimer;

- (void)setAutoRefreshTimer:(NSTimer *)autoRefreshTimer
{
    if (_autoRefreshTimer != autoRefreshTimer)
    {
        [_autoRefreshTimer invalidate];
        _autoRefreshTimer = autoRefreshTimer;
    }
}

// circularSearch
@synthesize circularSearch = _circularSearch;

- (void)setCircularSearch:(BOOL)circularSearch
{
    _circularSearch = circularSearch;
    self.regex.circular = circularSearch;
}

// scrollAutoRefreshDelay
@synthesize scrollAutoRefreshDelay = _scrollAutoRefreshDelay;

- (void)setScrollAutoRefreshDelay:(NSTimeInterval)scrollAutoRefreshDelay
{
    if (scrollAutoRefreshDelay < 0.0 || (scrollAutoRefreshDelay > 0.0 && scrollAutoRefreshDelay < ICMinScrollAutoRefreshDelay))
    {
        ICTextViewLog(@"Invalid scroll auto-refresh delay, keeping old value.");
        return;
    }
    
    _scrollAutoRefreshDelay = scrollAutoRefreshDelay;
}

// textSubview
@synthesize textSubview = _textSubview;

- (UIView *)textSubview
{
    if (!_textSubview)
    {
        // Detect _UITextContainerView or UIWebDocumentView (subview with text) for highlight placement
        for (UIView *view in self.subviews)
        {
            if ([view isKindOfClass:NSClassFromString(@"_UITextContainerView")] || [view isKindOfClass:NSClassFromString(@"UIWebDocumentView")])
            {
                _textSubview = view;
                break;
            }
        }
    }
    return _textSubview;
}

// Others
@synthesize animatedSearch = _animatedSearch;
@synthesize appliedSelectionFix = _appliedSelectionFix;
@synthesize cachedRange = _cachedRange;
@synthesize highlightCornerRadius = _highlightCornerRadius;
@synthesize highlightsByRange = _highlightsByRange;
@synthesize highlightSearchResults = _highlightSearchResults;
@synthesize maxHighlightedMatches = _maxHighlightedMatches;
@synthesize performedNewScroll = _performedNewScroll;
@synthesize primaryHighlightColor = _primaryHighlightColor;
@synthesize primaryHighlights = _primaryHighlights;
@synthesize regex = _regex;
@synthesize scrollPosition = _scrollPosition;
@synthesize searching = _searching;
@synthesize searchIndex = _searchIndex;
@synthesize searchOptions = _searchOptions;
@synthesize searchRange = _searchRange;
@synthesize searchVisibleRange = _searchVisibleRange;
@synthesize secondaryHighlightColor = _secondaryHighlightColor;
@synthesize secondaryHighlights = _secondaryHighlights;

#pragma mark - Class methods

+ (void)initialize
{
    if (self == [ICTextView class])
    {
        highlightingSupported = [self conformsToProtocol:@protocol(UITextInput)];
        
        // Using NSSelectorFromString() instead of @selector() to suppress unneccessary warnings on older SDKs
        textContainerInsetSupported = [self instancesRespondToSelector:NSSelectorFromString(@"textContainerInset")];
        
        shouldApplyBecomeFirstResponderFix = NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0 && NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_9_0;
        shouldApplyCaretFix = NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0 && NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_9_0;
        shouldApplyCharacterRangeAtPointFix = NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0 && NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_8_0;
        shouldApplyTextContainerFix = NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0 && NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_9_0;
    }
}

#pragma mark - Output

- (NSString *)foundString
{
    NSString *text = self.text;
    NSRange rangeOfFoundString = [self rangeOfFoundString];
    return (text.length >= (rangeOfFoundString.location + rangeOfFoundString.length) ? [text substringWithRange:rangeOfFoundString] : nil);
}

- (NSUInteger)indexOfFoundString
{
    ICRegularExpression *regex = self.regex;
    return (regex ? regex.indexOfCurrentMatch : NSNotFound);
}

- (NSUInteger)numberOfMatches
{
    return self.regex.numberOfMatches;
}

- (NSRange)rangeOfFoundString
{
    ICRegularExpression *regex = self.regex;
    return (regex ? ICRangeOffset(regex.rangeOfCurrentMatch, self.cachedRange.location) : ICRangeNotFound);
}

#pragma mark - Search

- (void)resetSearch
{
    if (highlightingSupported)
    {
        [self initializeHighlights];
        self.autoRefreshTimer = nil;
    }
    
    self.cachedRange = ICRangeZero;
    self.regex = nil;
    self.searchIndex = ICSearchIndexAuto;
    self.searching = NO;
    self.searchVisibleRange = NO;
}

- (BOOL)scrollToMatch:(NSString *)pattern
{
    return [self scrollToMatch:pattern searchDirection:ICTextViewSearchDirectionForward];
}

- (BOOL)scrollToMatch:(NSString *)pattern searchDirection:(ICTextViewSearchDirection)searchDirection
{
    // Initialize search
    if (![self initializeSearchWithPattern:pattern])
        return NO;
    
    self.searching = YES;
    
    ICRegularExpression *regex = self.regex;
    NSUInteger searchIndex = self.searchIndex;
    
    NSUInteger index = ICSearchIndexAuto;
    
    if (searchIndex != ICSearchIndexAuto && ICRangeContainsIndex(regex.matchLocationsRange, searchIndex))
        index = searchIndex - self.cachedRange.location;
    
    // Get match
    if (index == ICSearchIndexAuto)
    {
        if (searchDirection == ICTextViewSearchDirectionForward)
            [regex rangeOfNextMatch];
        else
            [regex rangeOfPreviousMatch];
    }
    else
    {
        if (searchDirection == ICTextViewSearchDirectionForward)
            [regex rangeOfFirstMatchInRange:NSMakeRange(index, regex.string.length - index)];
        else
            [regex rangeOfLastMatchInRange:NSMakeRange(0, index)];
        
        self.searchIndex = ICSearchIndexAuto;
    }
    
    NSRange matchRange = [self rangeOfFoundString];
    BOOL found = NO;
    
    if (matchRange.location == NSNotFound)
    {
        // Match not found
        self.searching = NO;
    }
    else
    {
        // Match found
        found = YES;
        self.searchVisibleRange = NO;
        
        // Add highlights
        if (highlightingSupported && self.highlightSearchResults)
            [self highlightOccurrencesInMaskedVisibleRange];
        
        // Scroll
        [self scrollRangeToVisible:matchRange consideringInsets:YES animated:self.animatedSearch];
    }
    
    return found;
}

- (BOOL)scrollToString:(NSString *)stringToFind
{
    return [self scrollToString:stringToFind searchDirection:ICTextViewSearchDirectionForward];
}

- (BOOL)scrollToString:(NSString *)stringToFind searchDirection:(ICTextViewSearchDirection)searchDirection
{
    if (!stringToFind)
    {
        ICTextViewLog(@"Search string cannot be nil.");
        [self resetSearch];
        return NO;
    }
    
    // Escape metacharacters
    stringToFind = [NSRegularExpression escapedPatternForString:stringToFind];
    
    // Better automatic search on UITextField or UISearchBar text change
    if (self.searching)
    {
        NSString *regexPattern = self.regex.pattern;
        NSUInteger stringToFindLength = stringToFind.length;
        NSUInteger foundStringLength = regexPattern.length;
        
        if (stringToFindLength != foundStringLength)
        {
            NSUInteger minLength = MIN(stringToFindLength, foundStringLength);
            NSString *lcStringToFind = [[stringToFind substringToIndex:minLength] lowercaseString];
            NSString *lcFoundString = [[regexPattern substringToIndex:minLength] lowercaseString];
            
            NSUInteger foundStringLocation = [self rangeOfFoundString].location;
            
            if ([lcStringToFind isEqualToString:lcFoundString] && foundStringLocation != NSNotFound)
                self.searchIndex = foundStringLocation;
        }
    }
    
    // Perform search
    return [self scrollToMatch:stringToFind searchDirection:searchDirection];
}

#pragma mark - Misc

- (void)scrollRangeToVisible:(NSRange)range consideringInsets:(BOOL)considerInsets
{
    [self scrollRangeToVisible:range consideringInsets:considerInsets animated:YES];
}

- (void)scrollRangeToVisible:(NSRange)range consideringInsets:(BOOL)considerInsets animated:(BOOL)animated
{
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_5_0)
    {
        // considerInsets, animated and scrollPosition are ignored in iOS 4.x
        // as UITextView doesn't conform to the UITextInput protocol
        [self scrollRangeToVisible:range];
        return;
    }
    
    // Calculate rect for range
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0)
        [self.layoutManager ensureLayoutForTextContainer:self.textContainer];
#endif
    
    UITextPosition *startPosition = [self positionFromPosition:self.beginningOfDocument offset:(NSInteger)range.location];
    UITextPosition *endPosition = [self positionFromPosition:startPosition offset:(NSInteger)range.length];
    UITextRange *textRange = [self textRangeFromPosition:startPosition toPosition:endPosition];
    CGRect rect = [self firstRectForRange:textRange];
    
    // Scroll to visible rect
    [self scrollRectToVisible:rect animated:animated consideringInsets:considerInsets];
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated consideringInsets:(BOOL)considerInsets
{
    UIEdgeInsets contentInset = considerInsets ? [self totalContentInset] : UIEdgeInsetsZero;
    CGRect visibleRect = [self visibleRectConsideringInsets:considerInsets];
    CGRect toleranceArea = visibleRect;
    CGFloat y = rect.origin.y - contentInset.top;
    
    switch (self.scrollPosition)
    {
        case ICTextViewScrollPositionTop:
            toleranceArea.size.height = rect.size.height * 1.5f;
            break;
            
        case ICTextViewScrollPositionMiddle:
            toleranceArea.size.height = rect.size.height * 1.5f;
            toleranceArea.origin.y += ((visibleRect.size.height - toleranceArea.size.height) * 0.5f);
            y -= ((visibleRect.size.height - rect.size.height) * 0.5f);
            break;
            
        case ICTextViewScrollPositionBottom:
            toleranceArea.size.height = rect.size.height * 1.5f;
            toleranceArea.origin.y += (visibleRect.size.height - toleranceArea.size.height);
            y -= (visibleRect.size.height - rect.size.height);
            break;
            
        case ICTextViewScrollPositionNone:
            if (rect.origin.y >= visibleRect.origin.y)
                y -= (visibleRect.size.height - rect.size.height);
            break;
    }
    
    if (!CGRectContainsRect(toleranceArea, rect))
        [self scrollToY:y animated:animated consideringInsets:considerInsets];
}

- (NSRange)visibleRangeConsideringInsets:(BOOL)considerInsets
{
    return [self visibleRangeConsideringInsets:considerInsets startPosition:NULL endPosition:NULL];
}

- (NSRange)visibleRangeConsideringInsets:(BOOL)considerInsets startPosition:(UITextPosition *__autoreleasing *)startPosition endPosition:(UITextPosition *__autoreleasing *)endPosition
{
    CGRect visibleRect = [self visibleRectConsideringInsets:considerInsets];
    CGPoint startPoint = visibleRect.origin;
    CGPoint endPoint = CGPointMake(CGRectGetMaxX(visibleRect), CGRectGetMaxY(visibleRect));
    
    UITextPosition *start = [self characterRangeAtPoint:startPoint].start;
    UITextPosition *end = [self characterRangeAtPoint:endPoint].end;
    
    if (startPosition)
        *startPosition = start;
    if (endPosition)
        *endPosition = end;
    
    // Offsets can never be negative due to how they're computed, so it's safe to just cast them to NSUInteger
    return NSMakeRange((NSUInteger)[self offsetFromPosition:self.beginningOfDocument toPosition:start],
                       (NSUInteger)[self offsetFromPosition:start toPosition:end]);
}

- (CGRect)visibleRectConsideringInsets:(BOOL)considerInsets
{
    CGRect visibleRect = self.bounds;
    
    if (considerInsets)
        visibleRect = UIEdgeInsetsInsetRect(visibleRect, [self totalContentInset]);
    
    return visibleRect;
}

#pragma mark - Private methods

// Return value: highlight UIView
- (UIView *)addHighlightAtRect:(CGRect)frame
{
    UIView *highlight = [[UIView alloc] initWithFrame:frame];
    CGFloat cornerRadius = self.highlightCornerRadius;
    highlight.layer.cornerRadius = (cornerRadius < 0.0 ? frame.size.height * 0.2f : cornerRadius);
    highlight.backgroundColor = self.secondaryHighlightColor;
    [self.secondaryHighlights addObject:highlight];
    [self insertSubview:highlight belowSubview:self.textSubview];
    return highlight;
}

// Return value: array of highlights for text range
- (NSMutableArray *)addHighlightAtTextRange:(UITextRange *)textRange
{
    NSMutableArray *highlightsForRange = [[NSMutableArray alloc] init];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_6_0)
    {
        // iOS 6.x+ implementation
        CGRect previousRect = CGRectZero;
        NSArray *highlightRects = [self selectionRectsForRange:textRange];
        
        // Merge adjacent rects
        for (UITextSelectionRect *selectionRect in highlightRects)
        {
            CGRect currentRect = selectionRect.rect;
            
            if (ICCGFloatEqualOnScreen(currentRect.origin.y, previousRect.origin.y) &&
                ICCGFloatEqualOnScreen(currentRect.origin.x, CGRectGetMaxX(previousRect)) &&
                ICCGFloatEqualOnScreen(currentRect.size.height, previousRect.size.height))
            {
                // Adjacent, add to previous rect
                previousRect = CGRectMake(previousRect.origin.x, previousRect.origin.y, previousRect.size.width + currentRect.size.width, previousRect.size.height);
            }
            else
            {
                // Not adjacent, add previous rect to highlights array
                [highlightsForRange addObject:[self addHighlightAtRect:previousRect]];
                previousRect = currentRect;
            }
        }
        
        // Add last highlight
        [highlightsForRange addObject:[self addHighlightAtRect:previousRect]];
    }
    else
#endif
    {
        // iOS 5.x implementation (a bit slower)
        CGRect previousRect = CGRectZero;
        UITextPosition *start = textRange.start;
        UITextPosition *end = textRange.end;
        id <UITextInputTokenizer> tokenizer = [self tokenizer];
        BOOL hasMoreLines;
        do {
            UITextPosition *lineEnd = [tokenizer positionFromPosition:start toBoundary:UITextGranularityLine inDirection:UITextStorageDirectionForward];
            
            // Check if string is on multiple lines
            if ([self offsetFromPosition:lineEnd toPosition:end] <= 0)
            {
                hasMoreLines = NO;
                textRange = [self textRangeFromPosition:start toPosition:end];
            }
            else
            {
                hasMoreLines = YES;
                textRange = [self textRangeFromPosition:start toPosition:lineEnd];
                start = lineEnd;
            }
            previousRect = [self firstRectForRange:textRange];
            [highlightsForRange addObject:[self addHighlightAtRect:previousRect]];
        } while (hasMoreLines);
    }
    return highlightsForRange;
}

// Highlight occurrences of found string in visible range masked by the user specified range
- (void)highlightOccurrencesInMaskedVisibleRange
{
    if (!self.searching)
        return;
    
    if (self.performedNewScroll)
    {
        // Initial data
        UITextPosition *visibleStartPosition;
        NSRange visibleRange = [self visibleRangeConsideringInsets:YES startPosition:&visibleStartPosition endPosition:NULL];
        
        // Perform search in masked range
        NSRange cachedRange = self.cachedRange;
        NSUInteger cachedRangeLocation = cachedRange.location;
        NSRange maskedRange = ICRangeOffset(NSIntersectionRange(cachedRange, visibleRange), -cachedRangeLocation);
        NSMutableArray *rangeValues = [[NSMutableArray alloc] init];
        
        for (NSValue *rangeValue in [self.regex rangesOfMatchesInRange:maskedRange])
            [rangeValues addObject:[NSValue valueWithRange:ICRangeOffset(rangeValue.rangeValue, cachedRangeLocation)]];
        
        ///// ADD SECONDARY HIGHLIGHTS /////
        
        if (rangeValues.count)
        {
            // Remove already present highlights
            NSMutableDictionary *highlightsByRange = self.highlightsByRange;
            
            NSMutableArray *rangesArray = [rangeValues mutableCopy];
            NSMutableIndexSet *indexesToRemove = [[NSMutableIndexSet alloc] init];
            [rangeValues enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger idx, BOOL *stop){
                ICUnusedParameter(stop);
                if ([highlightsByRange objectForKey:rangeValue])
                    [indexesToRemove addIndex:idx];
            }];
            [rangesArray removeObjectsAtIndexes:indexesToRemove];
            indexesToRemove = nil;
            
            if (rangesArray.count)
            {
                // Get text range of first result
                NSValue *firstRangeValue = [rangesArray objectAtIndex:0];
                NSRange previousRange = [firstRangeValue rangeValue];
                
                UITextPosition *start = [self positionFromPosition:visibleStartPosition offset:(NSInteger)(previousRange.location - visibleRange.location)];
                UITextPosition *end = [self positionFromPosition:start offset:(NSInteger)previousRange.length];
                UITextRange *textRange = [self textRangeFromPosition:start toPosition:end];
                
                // First range
                [highlightsByRange setObject:[self addHighlightAtTextRange:textRange] forKey:firstRangeValue];
                [rangesArray removeObjectAtIndex:0];
                
                if (rangesArray.count)
                {
                    for (NSValue *rangeValue in rangesArray)
                    {
                        NSRange range = [rangeValue rangeValue];
                        start = [self positionFromPosition:end offset:(NSInteger)(range.location - (previousRange.location + previousRange.length))];
                        end = [self positionFromPosition:start offset:(NSInteger)range.length];
                        textRange = [self textRangeFromPosition:start toPosition:end];
                        [highlightsByRange setObject:[self addHighlightAtTextRange:textRange] forKey:rangeValue];
                        previousRange = range;
                    }
                }
                
                // Memory management
                NSInteger max = (NSInteger)MIN(self.maxHighlightedMatches, (NSUInteger)NSIntegerMax);
                NSInteger remaining = max - (NSInteger)highlightsByRange.count;
                if (remaining < 0)
                    [self removeHighlightsTooFarFromRange:visibleRange];
            }
        }
        
        // Eventually update searchIndex to match visible range
        if (self.searchVisibleRange)
            self.searchIndex = visibleRange.location;
    }
    
    [self setPrimaryHighlightAtRange:[self rangeOfFoundString]];
}

// Used in init overrides
- (void)initialize
{
    _animatedSearch = YES;
    _highlightCornerRadius = -1.0;
    _highlightsByRange = [[NSMutableDictionary alloc] init];
    _highlightSearchResults = YES;
    _maxHighlightedMatches = 100;
    _primaryHighlights = [[NSMutableArray alloc] init];
    _primaryHighlightColor = [UIColor colorWithRed:150.0f/255.0f green:200.0f/255.0f blue:1.0 alpha:1.0];
    _scrollAutoRefreshDelay = 0.2;
    _searchIndex = ICSearchIndexAuto;
    _searchRange = ICRangeMax;
    _secondaryHighlights = [[NSMutableOrderedSet alloc] init];
    _secondaryHighlightColor = [UIColor colorWithRed:215.0f/255.0f green:240.0f/255.0f blue:1.0 alpha:1.0];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textChanged)
                                                 name:UITextViewTextDidChangeNotification
                                               object:self];
}

- (void)initializeHighlights
{
    [self initializePrimaryHighlights];
    [self initializeSecondaryHighlights];
}

- (void)initializePrimaryHighlights
{
    // Move primary highlights to secondary highlights array
    NSMutableArray *primaryHighlights = self.primaryHighlights;
    NSMutableOrderedSet *secondaryHighlights = self.secondaryHighlights;
    UIColor *secondaryHighlightColor = self.secondaryHighlightColor;
    
    for (UIView *hl in primaryHighlights)
    {
        hl.backgroundColor = secondaryHighlightColor;
        [secondaryHighlights addObject:hl];
    }
    [primaryHighlights removeAllObjects];
}

- (BOOL)initializeSearchWithPattern:(NSString *)pattern
{
    if (!pattern.length)
    {
        ICTextViewLog(@"Pattern cannot be nil or empty.");
        [self resetSearch];
        return NO;
    }
    
    ICRegularExpression *regex = self.regex;
    NSRegularExpressionOptions searchOptions = self.searchOptions;
    
    // Calculate valid range
    NSUInteger textLength = self.text.length;
    NSRange localRange = NSIntersectionRange(NSMakeRange(0, textLength), self.searchRange);
    
    if (localRange.length == 0 && textLength != 0)
        localRange = NSMakeRange(0, textLength);
    
    // Optimization and coherence checks
    BOOL samePattern = [pattern isEqualToString:regex.pattern];
    BOOL sameOptions = (searchOptions == regex.options);
    BOOL sameSearchRange = NSEqualRanges(self.cachedRange, localRange);
    BOOL allocateNewRegex = !(samePattern && sameOptions && sameSearchRange);
    
    // Regex allocation
    if (allocateNewRegex)
    {
        NSString *newString = (sameSearchRange ? regex.string : [self.text substringWithRange:localRange]);
        NSError *__autoreleasing error = nil;
        
        regex = [[ICRegularExpression alloc] initWithString:newString
                                                     pattern:pattern
                                                     options:searchOptions
                                                       error:&error];
        if (error)
        {
            ICTextViewLog(@"Error while creating regex: %@", error);
            [self resetSearch];
            return NO;
        }
        
        self.regex = regex;
        regex.circular = self.circularSearch;
        self.cachedRange = localRange;
    }
    
    // Reset highlights
    if (highlightingSupported && self.highlightSearchResults)
    {
        [self initializePrimaryHighlights];
        if (allocateNewRegex)
            [self initializeSecondaryHighlights];
    }
    
    return YES;
}

- (void)initializeSecondaryHighlights
{
    NSMutableDictionary *highlightsByRange = self.highlightsByRange;
    NSMutableOrderedSet *secondaryHighlights = self.secondaryHighlights;
    
    for (UIView *hl in secondaryHighlights)
        [hl removeFromSuperview];
    [secondaryHighlights removeAllObjects];
    
    // Remove all objects in highlightsByRange, except rangeOfFoundString (primary)
    if (self.primaryHighlights.count)
    {
        NSValue *rangeValue = [NSValue valueWithRange:[self rangeOfFoundString]];
        NSMutableArray *primaryHighlights = [highlightsByRange objectForKey:rangeValue];
        [highlightsByRange removeAllObjects];
        [highlightsByRange setObject:primaryHighlights forKey:rangeValue];
    }
    else
        [highlightsByRange removeAllObjects];
    
    // Allow highlights to be refreshed
    self.performedNewScroll = YES;
}

- (void)removeHighlightsTooFarFromRange:(NSRange)range
{
    NSInteger tempMin = (NSInteger)range.location - (NSInteger)range.length;
    NSUInteger min = tempMin > 0 ? (NSUInteger)tempMin : 0;
    NSUInteger max = min + 3 * range.length;
    
    // Scan highlighted ranges
    NSMutableDictionary *highlightsByRange = self.highlightsByRange;
    NSMutableOrderedSet *secondaryHighlights = self.secondaryHighlights;
    
    NSMutableArray *keysToRemove = [[NSMutableArray alloc] init];
    [highlightsByRange enumerateKeysAndObjectsUsingBlock:^(NSValue *rangeValue, NSArray *highlightsForRange, BOOL *stop){
        ICUnusedParameter(stop);
        
        // Selectively remove highlights
        NSUInteger location = [rangeValue rangeValue].location;
        if ((location < min || location > max) && location != [self rangeOfFoundString].location)
        {
            for (UIView *hl in highlightsForRange)
            {
                [hl removeFromSuperview];
                [secondaryHighlights removeObject:hl];
            }
            [keysToRemove addObject:rangeValue];
        }
    }];
    [highlightsByRange removeObjectsForKeys:keysToRemove];
}

- (void)scrollEnded
{
    [self highlightOccurrencesInMaskedVisibleRange];
    self.autoRefreshTimer = nil;
    self.performedNewScroll = NO;
}

// Scrolls to y coordinate without breaking the frame and (eventually) insets
- (void)scrollToY:(CGFloat)y animated:(BOOL)animated consideringInsets:(BOOL)considerInsets
{
    CGFloat min = 0.0;
    CGFloat max = MAX(self.contentSize.height - self.bounds.size.height, 0.0f);
    
    if (considerInsets)
    {
        UIEdgeInsets contentInset = [self totalContentInset];
        min -= contentInset.top;
        max += contentInset.bottom;
    }
    
    // Calculates new content offset
    CGPoint contentOffset = self.contentOffset;
    
    if (y > max)
        contentOffset.y = max;
    else if (y < min)
        contentOffset.y = min;
    else
        contentOffset.y = y;
    
    [self setContentOffset:contentOffset animated:animated];
}

- (void)setPrimaryHighlightAtRange:(NSRange)range
{
    [self initializePrimaryHighlights];
    NSMutableArray *primaryHighlights = self.primaryHighlights;
    NSMutableOrderedSet *secondaryHighlights = self.secondaryHighlights;
    UIColor *primaryHighlightColor = self.primaryHighlightColor;
    
    NSValue *rangeValue = [NSValue valueWithRange:range];
    NSMutableArray *highlightsForRange = [self.highlightsByRange objectForKey:rangeValue];
    
    for (UIView *hl in highlightsForRange)
    {
        hl.backgroundColor = primaryHighlightColor;
        [primaryHighlights addObject:hl];
        [secondaryHighlights removeObject:hl];
    }
}

- (void)textChanged
{
    if (self.searching)
        [self resetSearch];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (shouldApplyCaretFix)
    {
        UITextRange *selectedTextRange = self.selectedTextRange;
        if (selectedTextRange.empty)
            [self scrollToCaretPosition:selectedTextRange.end];
    }
#endif
}

// Accounts for both contentInset and textContainerInset
- (UIEdgeInsets)totalContentInset
{
    UIEdgeInsets contentInset = self.contentInset;
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (textContainerInsetSupported)
    {
        UIEdgeInsets textContainerInset = self.textContainerInset;
        
        contentInset.top += textContainerInset.top;
        contentInset.bottom += textContainerInset.bottom;
        contentInset.left += textContainerInset.left;
        contentInset.right += textContainerInset.right;
    }
#endif
    
    return contentInset;
}

#pragma mark - Overrides

- (BOOL)becomeFirstResponder
{
    if (self.editable)
        [self resetSearch];
    
    return [super becomeFirstResponder];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]) && highlightingSupported)
        [self initialize];
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (shouldApplyTextContainerFix)
        return [self initWithFrame:frame textContainer:nil];
#endif
    
    if ((self = [super initWithFrame:frame]) && highlightingSupported)
        [self initialize];
    
    return self;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
- (id)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer
{
    NSTextContainer *localTextContainer = textContainer;
    
    if (!localTextContainer && shouldApplyTextContainerFix)
    {
        NSTextStorage *textStorage = [[NSTextStorage alloc] init];
        NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
        [textStorage addLayoutManager:layoutManager];
        localTextContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(frame.size.width, CGFLOAT_MAX)];
        localTextContainer.heightTracksTextView = YES;
        localTextContainer.widthTracksTextView = YES;
        [layoutManager addTextContainer:localTextContainer];
    }
    
    if ((self = [super initWithFrame:frame textContainer:textContainer]) && highlightingSupported)
        [self initialize];
    
    return self;
}
#endif

- (void)setContentOffset:(CGPoint)contentOffset
{
    [super setContentOffset:contentOffset];
    
    if (highlightingSupported && self.highlightSearchResults)
    {
        self.performedNewScroll = YES;
        
        // If user is scrolling, set flag to start searching from the visible range
        if (!self.searchVisibleRange)
            self.searchVisibleRange = ([self.panGestureRecognizer velocityInView:self].y != 0.0);
        
        // Eventually start auto-refresh timer
        NSTimeInterval autoRefreshDelay = self.scrollAutoRefreshDelay;
        if (self.searching && autoRefreshDelay > 0.0 && !self.autoRefreshTimer)
        {
            NSTimer *autoRefreshTimer = [NSTimer timerWithTimeInterval:autoRefreshDelay
                                                                target:self
                                                              selector:@selector(highlightOccurrencesInMaskedVisibleRange)
                                                              userInfo:nil
                                                               repeats:YES];
            self.autoRefreshTimer = autoRefreshTimer;
            [[NSRunLoop mainRunLoop] addTimer:autoRefreshTimer forMode:UITrackingRunLoopMode];
        }
        
        // Cancel previous request and perform new one
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scrollEnded) object:nil];
        [self performSelector:@selector(scrollEnded) withObject:nil afterDelay:0.1];
    }
}

- (void)setFrame:(CGRect)frame
{
    if (highlightingSupported && self.highlightsByRange.count)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(initializeHighlights) object:nil];
        [self performSelector:@selector(initializeHighlights) withObject:nil afterDelay:0.1];
    }
    [super setFrame:frame];
}

#pragma mark - Fixes

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000

- (void)applySelectionFix
{
    if ((shouldApplyBecomeFirstResponderFix || shouldApplyCharacterRangeAtPointFix) && !self.appliedSelectionFix && self.text.length > 1)
    {
        [self select:self];
        [self setSelectedTextRange:nil];
        self.appliedSelectionFix = YES;
    }
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self applySelectionFix];
}

- (void)scrollToCaretPosition:(UITextPosition *)position
{
    ICTextViewScrollPosition oldPosition = self.scrollPosition;
    self.scrollPosition = ICTextViewScrollPositionNone;
    [self scrollRectToVisible:[self caretRectForPosition:position] animated:NO consideringInsets:YES];
    self.scrollPosition = oldPosition;
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    [super setAttributedText:attributedText];
    [self applySelectionFix];
}

- (void)setSelectedTextRange:(UITextRange *)selectedTextRange
{
    [super setSelectedTextRange:selectedTextRange];
    
    if (shouldApplyCaretFix && selectedTextRange.empty)
        [self scrollToCaretPosition:selectedTextRange.end];
}

- (void)setText:(NSString *)text
{
    [super setText:text];
    [self applySelectionFix];
}
#endif

#pragma mark - Deprecated

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (BOOL)scrollToMatch:(NSString *)pattern searchOptions:(NSRegularExpressionOptions)options
{
    self.searchOptions = options;
    return [self scrollToMatch:pattern];
}

- (BOOL)scrollToMatch:(NSString *)pattern searchOptions:(NSRegularExpressionOptions)options range:(NSRange)range
{
    self.searchOptions = options;
    self.searchRange = range;
    return [self scrollToMatch:pattern];
}

- (BOOL)scrollToMatch:(NSString *)pattern searchOptions:(NSRegularExpressionOptions)options animated:(BOOL)animated atScrollPosition:(ICTextViewScrollPosition)scrollPosition
{
    self.animatedSearch = animated;
    self.scrollPosition = scrollPosition;
    self.searchOptions = options;
    return [self scrollToMatch:pattern];
}

- (BOOL)scrollToMatch:(NSString *)pattern searchOptions:(NSRegularExpressionOptions)options range:(NSRange)range animated:(BOOL)animated atScrollPosition:(ICTextViewScrollPosition)scrollPosition
{
    self.animatedSearch = animated;
    self.scrollPosition = scrollPosition;
    self.searchOptions = options;
    self.searchRange = range;
    return [self scrollToMatch:pattern];
}

- (BOOL)scrollToString:(NSString *)stringToFind searchOptions:(NSRegularExpressionOptions)options
{
    self.searchOptions = options;
    return [self scrollToString:stringToFind];
}

- (BOOL)scrollToString:(NSString *)stringToFind searchOptions:(NSRegularExpressionOptions)options range:(NSRange)range
{
    self.searchOptions = options;
    self.searchRange = range;
    return [self scrollToString:stringToFind];
}

- (BOOL)scrollToString:(NSString *)stringToFind searchOptions:(NSRegularExpressionOptions)options animated:(BOOL)animated atScrollPosition:(ICTextViewScrollPosition)scrollPosition
{
    self.animatedSearch = animated;
    self.scrollPosition = scrollPosition;
    self.searchOptions = options;
    return [self scrollToString:stringToFind];
}

- (BOOL)scrollToString:(NSString *)stringToFind searchOptions:(NSRegularExpressionOptions)options range:(NSRange)range animated:(BOOL)animated atScrollPosition:(ICTextViewScrollPosition)scrollPosition
{
    self.animatedSearch = animated;
    self.scrollPosition = scrollPosition;
    self.searchOptions = options;
    self.searchRange = range;
    return [self scrollToString:stringToFind];
}

- (void)scrollRangeToVisible:(NSRange)range consideringInsets:(BOOL)considerInsets animated:(BOOL)animated atScrollPosition:(ICTextViewScrollPosition)scrollPosition
{
    self.scrollPosition = scrollPosition;
    [self scrollRangeToVisible:range consideringInsets:considerInsets animated:animated];
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated consideringInsets:(BOOL)considerInsets atScrollPosition:(ICTextViewScrollPosition)scrollPosition
{
    self.scrollPosition = scrollPosition;
    [self scrollRectToVisible:rect animated:animated consideringInsets:considerInsets];
}

#pragma clang diagnostic pop

@end
