/**
 * ICTextView.m - 1.0.1
 * --------------------
 *
 * Copyright (c) 2013 Ivano Bilenchi
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
#import <QuartzCore/QuartzCore.h>

// For old SDKs
#ifndef NSFoundationVersionNumber_iOS_6_0
#define NSFoundationVersionNumber_iOS_6_0 993.0
#endif

#ifndef NSFoundationVersionNumber_iOS_6_1
#define NSFoundationVersionNumber_iOS_6_1 993.0
#endif

// Document subview tag
#define UIDocumentViewTag 181337

// Private iVars
@interface ICTextView ()
{
    // Highlights
    NSMutableDictionary *_highlightsByRange;
    NSMutableArray *_primaryHighlights;
    NSMutableOrderedSet *_secondaryHighlights;
    
    // Work variables
    NSRegularExpression *_regex;
    NSTimer *_autoRefreshTimer;
    NSRange _searchRange;
    NSUInteger _scanIndex;
    BOOL _performedNewScroll;
    BOOL _shouldUpdateScanIndex;
    
    // TODO: remove iOS 7 characterRangeAtPoint: bugfix when an official fix is available
    BOOL _hasAppliediOS7Bugfix;
}
@end

// Search results highlighting supported starting from iOS 5.x
static BOOL _highlightingSupported;

@implementation ICTextView

#pragma mark - Synthesized properties

@synthesize primaryHighlightColor = _primaryHighlightColor;
@synthesize secondaryHighlightColor = _secondaryHighlightColor;
@synthesize highlightCornerRadius = _highlightCornerRadius;
@synthesize highlightSearchResults = _highlightSearchResults;
@synthesize maxHighlightedMatches = _maxHighlightedMatches;
@synthesize scrollAutoRefreshDelay = _scrollAutoRefreshDelay;
@synthesize rangeOfFoundString = _rangeOfFoundString;

#pragma mark - Class methods

+ (void)initialize
{
    if (self == [ICTextView class])
        _highlightingSupported = [self conformsToProtocol:@protocol(UITextInput)];
}

#pragma mark - Private methods

// Adds highlight at rect (returns highlight UIView)
- (UIView *)addHighlightAtRect:(CGRect)frame
{
    UIView *highlight = [[UIView alloc] initWithFrame:frame];
    highlight.layer.cornerRadius = _highlightCornerRadius < 0.0 ? frame.size.height * 0.2 : _highlightCornerRadius;
    highlight.backgroundColor = _secondaryHighlightColor;
    [_secondaryHighlights addObject:highlight];
    [self insertSubview:highlight belowSubview:[self viewWithTag:UIDocumentViewTag]];
    return highlight;
}

// Adds highlight at text range (returns array of highlights for text range)
- (NSMutableArray *)addHighlightAtTextRange:(UITextRange *)textRange
{
    NSMutableArray *highlightsForRange = [[NSMutableArray alloc] init];
    
    // Version specific implementation
#ifdef __IPHONE_6_0
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_6_0)
    {
        // iOS 6.x and newer implementation
        CGRect previousRect = CGRectZero;
        NSArray *highlightRects = [self selectionRectsForRange:textRange];
        // Merges adjacent rects
        for (UITextSelectionRect *selectionRect in highlightRects)
        {
            CGRect currentRect = selectionRect.rect;
            if ((currentRect.origin.y == previousRect.origin.y) && (currentRect.origin.x == CGRectGetMaxX(previousRect)) && (currentRect.size.height == previousRect.size.height))
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
        // Adds last highlight
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
            // Adds highlight
            UITextPosition *lineEnd = [tokenizer positionFromPosition:start toBoundary:UITextGranularityLine inDirection:UITextStorageDirectionForward];
            // Checks if string is on multiple lines
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

// Highlights occurrences of found string in visible range masked by the user specified range
- (void)highlightOccurrencesInMaskedVisibleRange
{
    // Regex search
    if (_regex)
    {
        if (_performedNewScroll)
        {
            // Initial data
            UITextPosition *visibleStartPosition;
            NSRange visibleRange = [self visibleRangeConsideringInsets:YES startPosition:&visibleStartPosition endPosition:NULL];
            
            // Performs search in masked range
            NSRange maskedRange = NSIntersectionRange(_searchRange, visibleRange);
            NSMutableArray *rangeValues = [[NSMutableArray alloc] init];
            [_regex enumerateMatchesInString:self.text options:0 range:maskedRange usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
                NSValue *rangeValue = [NSValue valueWithRange:match.range];
                [rangeValues addObject:rangeValue];
            }];
            
            ///// ADDS SECONDARY HIGHLIGHTS /////
            
            // Array must have elements
            if (rangeValues.count)
            {
                // Removes already present highlights
                NSMutableArray *rangesArray = [rangeValues mutableCopy];
                NSMutableIndexSet *indexesToRemove = [[NSMutableIndexSet alloc] init];
                [rangeValues enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger idx, BOOL *stop){
                    if ([_highlightsByRange objectForKey:rangeValue])
                        [indexesToRemove addIndex:idx];
                }];
                [rangesArray removeObjectsAtIndexes:indexesToRemove];
                indexesToRemove = nil;
                
                // Filtered array must have elements
                if (rangesArray.count)
                {
                    // Gets text range of first result
                    NSValue *firstRangeValue = [rangesArray objectAtIndex:0];
                    NSRange previousRange = [firstRangeValue rangeValue];
                    UITextPosition *start = [self positionFromPosition:visibleStartPosition offset:(previousRange.location - visibleRange.location)];
                    UITextPosition *end = [self positionFromPosition:start offset:previousRange.length];
                    UITextRange *textRange = [self textRangeFromPosition:start toPosition:end];
                    
                    // First range
                    [_highlightsByRange setObject:[self addHighlightAtTextRange:textRange] forKey:firstRangeValue];
                    
                    if (rangesArray.count > 1)
                    {
                        // Loops through ranges
                        for (NSUInteger idx = 1; idx < rangesArray.count; idx++)
                        {
                            NSValue *rangeValue = [rangesArray objectAtIndex:idx];
                            NSRange range = [rangeValue rangeValue];
                            start = [self positionFromPosition:end offset:range.location - (previousRange.location + previousRange.length)];
                            end = [self positionFromPosition:start offset:range.length];
                            textRange = [self textRangeFromPosition:start toPosition:end];
                            [_highlightsByRange setObject:[self addHighlightAtTextRange:textRange] forKey:rangeValue];
                            previousRange = range;
                        }
                    }
                    
                    // Memory management
                    NSInteger remaining = _maxHighlightedMatches - _highlightsByRange.count;
                    if (remaining < 0)
                    {
                        NSInteger tempMin = visibleRange.location - visibleRange.length;
                        NSUInteger min = tempMin > 0 ? tempMin : 0;
                        NSUInteger max = min + 3 * visibleRange.length;
                        // Scans highlighted ranges
                        NSMutableArray *keysToRemove = [[NSMutableArray alloc] init];
                        [_highlightsByRange enumerateKeysAndObjectsUsingBlock:^(NSValue *rangeValue, NSArray *highlightsForRange, BOOL *stop){
                            
                            // Removes ranges too far from visible range
                            NSUInteger location = [rangeValue rangeValue].location;
                            if ((location < min || location > max) && location != _rangeOfFoundString.location)
                            {
                                for (UIView *hl in highlightsForRange)
                                {
                                    [hl removeFromSuperview];
                                    [_secondaryHighlights removeObject:hl];
                                }
                                [keysToRemove addObject:rangeValue];
                            }
                        }];
                        [_highlightsByRange removeObjectsForKeys:keysToRemove];
                    }
                }
            }
            
            // Eventually updates _scanIndex to match visible range
            if (_shouldUpdateScanIndex)
                _scanIndex = visibleRange.location + (_regex ? visibleRange.length : 0);
        }
        
        // Sets primary highlight
        [self setPrimaryHighlightAtRange:_rangeOfFoundString];
    }
}

// Initializes highlights
- (void)initializeHighlights
{
    [self initializePrimaryHighlights];
    [self initializeSecondaryHighlights];
}

// Initializes primary highlights
- (void)initializePrimaryHighlights
{
    // Moves primary highlights to secondary highlights array
    for (UIView *hl in _primaryHighlights)
    {
        hl.backgroundColor = _secondaryHighlightColor;
        [_secondaryHighlights addObject:hl];
    }
    [_primaryHighlights removeAllObjects];
}

// Initializes secondary highlights
- (void)initializeSecondaryHighlights
{
    // Removes secondary highlights from their superview
    for (UIView *hl in _secondaryHighlights)
        [hl removeFromSuperview];
    [_secondaryHighlights removeAllObjects];
    
    // Removes all objects in _highlightsByRange, eventually except _rangeOfFoundString (primary)
    if (_primaryHighlights.count)
    {
        NSValue *rangeValue = [NSValue valueWithRange:_rangeOfFoundString];
        NSMutableArray *primaryHighlights = [_highlightsByRange objectForKey:rangeValue];
        [_highlightsByRange removeAllObjects];
        [_highlightsByRange setObject:primaryHighlights forKey:rangeValue];
    }
    else
        [_highlightsByRange removeAllObjects];
    
    // Sets _performedNewScroll status in order to refresh the highlights
    _performedNewScroll = YES;
}

// Called when scroll animation has ended
- (void)scrollEnded
{
    // Refreshes highlights
    [self highlightOccurrencesInMaskedVisibleRange];
    
    // Disables auto-refresh timer
    [_autoRefreshTimer invalidate];
    _autoRefreshTimer = nil;
    
    // scrollView has finished scrolling
    _performedNewScroll = NO;
}

// Sets primary highlight
- (void)setPrimaryHighlightAtRange:(NSRange)range
{
    [self initializePrimaryHighlights];
    NSValue *rangeValue = [NSValue valueWithRange:range];
    NSMutableArray *highlightsForRange = [_highlightsByRange objectForKey:rangeValue];
    
    for (UIView *hl in highlightsForRange)
    {
        hl.backgroundColor = _primaryHighlightColor;
        [_primaryHighlights addObject:hl];
        [_secondaryHighlights removeObject:hl];
    }
}

#pragma mark - Overrides

// Resets search if editable
- (BOOL)becomeFirstResponder
{
    if (self.editable)
        [self resetSearch];
    return [super becomeFirstResponder];
}

// Init overrides for custom initialization
- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
        [self initialize];
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
#ifdef __IPHONE_7_0
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1)
        return [self initWithFrame:frame textContainer:nil];
    else
#endif
    {
        self = [super initWithFrame:frame];
        if (self && _highlightingSupported)
            [self initialize];
        return self;
    }
}

#ifdef __IPHONE_7_0
// TODO: remove iOS 7 NSTextContainer bugfix when an official fix is available
- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer
{
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [textStorage addLayoutManager:layoutManager];
    if (!textContainer)
        textContainer = [[NSTextContainer alloc] initWithSize:frame.size];
    [layoutManager addTextContainer:textContainer];
    self = [super initWithFrame:frame textContainer:textContainer];
    if (self && _highlightingSupported)
        [self initialize];
    return self;
}
#endif

// Convenience method used in init overrides
- (void)initialize
{
    _highlightCornerRadius = -1.0;
    _highlightsByRange = [[NSMutableDictionary alloc] init];
    _highlightSearchResults = YES;
    _maxHighlightedMatches = 100;
    _scrollAutoRefreshDelay = 0.2;
    _primaryHighlights = [[NSMutableArray alloc] init];
    _primaryHighlightColor = [UIColor colorWithRed:150.0/255.0 green:200.0/255.0 blue:1.0 alpha:1.0];
    _secondaryHighlights = [[NSMutableOrderedSet alloc] init];
    _secondaryHighlightColor = [UIColor colorWithRed:215.0/255.0 green:240.0/255.0 blue:1.0 alpha:1.0];
    
    // Detects _UITextContainerView or UIWebDocumentView (subview with text) for highlight placement
    for (UIView *view in self.subviews)
    {
        if ([view isKindOfClass:NSClassFromString(@"_UITextContainerView")] || [view isKindOfClass:NSClassFromString(@"UIWebDocumentView")])
        {
            view.tag = UIDocumentViewTag;
            break;
        }
    }
}

// Executed while scrollView is scrolling
- (void)setContentOffset:(CGPoint)contentOffset
{
    [super setContentOffset:contentOffset];
    
    if (_highlightingSupported && _highlightSearchResults)
    {
        // scrollView has scrolled
        _performedNewScroll = YES;
        
        // _shouldUpdateScanIndex check
        if (!_shouldUpdateScanIndex)
            _shouldUpdateScanIndex = ([self.panGestureRecognizer velocityInView:self].y != 0.0);
        
        // Eventually starts auto-refresh timer
        if (_regex && _scrollAutoRefreshDelay && !_autoRefreshTimer)
        {
            _autoRefreshTimer = [NSTimer timerWithTimeInterval:_scrollAutoRefreshDelay target:self selector:@selector(highlightOccurrencesInMaskedVisibleRange) userInfo:nil repeats:YES];
            [[NSRunLoop mainRunLoop] addTimer:_autoRefreshTimer forMode:UITrackingRunLoopMode];
        }
        
        // Cancels previous request and performs new one
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scrollEnded) object:nil];
        [self performSelector:@selector(scrollEnded) withObject:nil afterDelay:0.1];
    }
}

// Resets highlights on frame change
- (void)setFrame:(CGRect)frame
{
    if (_highlightingSupported && _highlightsByRange.count)
        [self initializeHighlights];
    [super setFrame:frame];
}

// Doesn't allow _scrollAutoRefreshDelay values between 0.0 and 0.1
- (void)setScrollAutoRefreshDelay:(NSTimeInterval)scrollAutoRefreshDelay
{
    _scrollAutoRefreshDelay = (scrollAutoRefreshDelay > 0.0 && scrollAutoRefreshDelay < 0.1) ? 0.1 : scrollAutoRefreshDelay;
}

// TODO: remove iOS 7 characterRangeAtPoint: bugfix when an official fix is available
#ifdef __IPHONE_7_0
- (void)setText:(NSString *)text
{
    [super setText:text];
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1 && !_hasAppliediOS7Bugfix && text.length > 1)
    {
        [self select:self];
        [self setSelectedTextRange:nil];
        _hasAppliediOS7Bugfix = YES;
    }
}
#endif

#pragma mark - Public methods

#pragma mark -- Search --

// Returns string found during last search
- (NSString *)foundString
{
    return [self.text substringWithRange:_rangeOfFoundString];
}

// Resets search, starts from top
- (void)resetSearch
{
    if (_highlightingSupported)
    {
        [self initializeHighlights];
        [_autoRefreshTimer invalidate];
        _autoRefreshTimer = nil;
    }
    _rangeOfFoundString = NSMakeRange(NSNotFound,0);
    _regex = nil;
    _scanIndex = 0;
    _searchRange = NSMakeRange(0,0);
}

#pragma mark ---- Regex search ----

// Scroll to regex match (returns YES if found, NO otherwise)

- (BOOL)scrollToMatch:(NSString *)pattern
{
    return [self scrollToMatch:pattern searchOptions:0 range:NSMakeRange(0, self.text.length)];
}

- (BOOL)scrollToMatch:(NSString *)pattern searchOptions:(NSRegularExpressionOptions)options
{
    return [self scrollToMatch:pattern searchOptions:options range:NSMakeRange(0, self.text.length)];
}

- (BOOL)scrollToMatch:(NSString *)pattern searchOptions:(NSRegularExpressionOptions)options range:(NSRange)range
{
    // Calculates a valid range
    range = NSIntersectionRange(NSMakeRange(0, self.text.length), range);
    
    // Preliminary checks
    BOOL abort = NO;
    if (!pattern)
    {
#if DEBUG
        NSLog(@"Pattern cannot be nil.");
#endif
        abort = YES;
    }
    else if (range.length == 0)
    {
#if DEBUG
        NSLog(@"Specified range is out of bounds.");
#endif
        abort = YES;
    }
    if (abort)
    {
        [self resetSearch];
        return NO;
    }
    
    // Optimization and coherence checks
    BOOL samePattern = [pattern isEqualToString:_regex.pattern];
    BOOL sameOptions = (options == _regex.options);
    BOOL sameSearchRange = NSEqualRanges(range, _searchRange);
    
    // Sets new search range
    _searchRange = range;
    
    // Creates regex
    NSError *error;
    _regex = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
    if (error)
    {
#if DEBUG
        NSLog(@"Error while creating regex: %@", error);
#endif
        [self resetSearch];
        return NO;
    }
    
    // Resets highlights
    if (_highlightingSupported && _highlightSearchResults)
    {
        [self initializePrimaryHighlights];
        if (!(samePattern && sameOptions && sameSearchRange))
            [self initializeSecondaryHighlights];
    }
    
    // Scan index logic
    if (sameSearchRange && sameOptions)
    {
        // Same search pattern, go to next match
        if (_scanIndex && samePattern)
            _scanIndex += _rangeOfFoundString.length;
        // Scan index out of range
        if (_scanIndex < range.location || _scanIndex >= (range.location + range.length))
            _scanIndex = range.location;
    }
    else
        _scanIndex = range.location;
    
    // Gets match
    NSRange matchRange = [_regex rangeOfFirstMatchInString:self.text options:0 range:NSMakeRange(_scanIndex, range.location + range.length - _scanIndex)];
    
    // Match not found
    if (matchRange.location == NSNotFound)
    {
        if (_scanIndex)
        {
            // Starts from top
            _scanIndex = range.location;
            return [self scrollToMatch:pattern searchOptions:options range:range];
        }
        _regex = nil;
        _rangeOfFoundString = NSMakeRange(NSNotFound, 0);
        return NO;
    }
    
    // Match found, saves state
    _rangeOfFoundString = matchRange;
    _scanIndex = matchRange.location;
    _shouldUpdateScanIndex = NO;
    
    // Adds highlights
    if (_highlightingSupported && _highlightSearchResults)
        [self highlightOccurrencesInMaskedVisibleRange];
    
    // Scrolls
    [self scrollRangeToVisible:matchRange consideringInsets:YES];
    
    return YES;
}

#pragma mark ---- String search ----

// Scroll to string (returns YES if found, NO otherwise)

- (BOOL)scrollToString:(NSString *)stringToFind
{
    return [self scrollToString:stringToFind searchOptions:0 range:NSMakeRange(0, self.text.length)];
}

- (BOOL)scrollToString:(NSString *)stringToFind searchOptions:(NSRegularExpressionOptions)options
{
    return [self scrollToString:stringToFind searchOptions:options range:NSMakeRange(0, self.text.length)];
}

- (BOOL)scrollToString:(NSString *)stringToFind searchOptions:(NSRegularExpressionOptions)options range:(NSRange)range
{
    // Preliminary check
    if (!stringToFind)
    {
#if DEBUG
        NSLog(@"Search string cannot be nil.");
#endif
        [self resetSearch];
        return NO;
    }
    
    // Escapes metacharacters
    stringToFind = [NSRegularExpression escapedPatternForString:stringToFind];
    
    // These checks allow better automatic search on UITextField or UISearchBar text change
    if (_regex)
    {
        NSString *lcStringToFind = [stringToFind lowercaseString];
        NSString *lcFoundString = [_regex.pattern lowercaseString];
        if (!([lcStringToFind hasPrefix:lcFoundString] || [lcFoundString hasPrefix:lcStringToFind]))
            _scanIndex += _rangeOfFoundString.length;
    }
    
    // Performs search
    return [self scrollToMatch:stringToFind searchOptions:options range:range];
}

#pragma mark -- Misc --

// Scrolls to visible range, eventually considering insets
- (void)scrollRangeToVisible:(NSRange)range consideringInsets:(BOOL)considerInsets
{
#ifdef __IPHONE_7_0
    if (considerInsets && (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1))
    {
        // Calculates rect for range
        UITextPosition *startPosition = [self positionFromPosition:self.beginningOfDocument offset:range.location];
        UITextPosition *endPosition = [self positionFromPosition:startPosition offset:range.length];
        UITextRange *textRange = [self textRangeFromPosition:startPosition toPosition:endPosition];
        CGRect rect = [self firstRectForRange:textRange];
        
        // Scrolls to visible rect
        [self scrollRectToVisible:rect animated:YES consideringInsets:YES];
    }
    else
#endif
        [super scrollRangeToVisible:range];
}

// Scrolls to visible rect, eventually considering insets
- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated consideringInsets:(BOOL)considerInsets
{
#ifdef __IPHONE_7_0
    if (considerInsets && (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1))
    {
        // Gets bounds and calculates visible rect
        CGRect bounds = self.bounds;
        UIEdgeInsets contentInset = self.contentInset;
        CGRect visibleRect = [self visibleRectConsideringInsets:YES];
        
        // Do not scroll if rect is on screen
        if (!CGRectContainsRect(visibleRect, rect))
        {
            CGPoint contentOffset = self.contentOffset;
            // Calculates new contentOffset
            if (rect.origin.y < visibleRect.origin.y)
                // rect precedes bounds, scroll up
                contentOffset.y = rect.origin.y - contentInset.top;
            else
                // rect follows bounds, scroll down
                contentOffset.y = rect.origin.y + contentInset.bottom + rect.size.height - bounds.size.height;
            [self setContentOffset:contentOffset animated:animated];
        }
    }
    else
#endif
        [super scrollRectToVisible:rect animated:animated];
}

// Returns visible range, eventually considering insets
- (NSRange)visibleRangeConsideringInsets:(BOOL)considerInsets
{
    return [self visibleRangeConsideringInsets:considerInsets startPosition:NULL endPosition:NULL];
}

// Returns visible range, with start and end position, eventually considering insets
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
    
    return NSMakeRange([self offsetFromPosition:self.beginningOfDocument toPosition:start], [self offsetFromPosition:start toPosition:end]);
}

// Returns visible rect, eventually considering insets
- (CGRect)visibleRectConsideringInsets:(BOOL)considerInsets
{
    CGRect bounds = self.bounds;
    if (considerInsets)
    {
        UIEdgeInsets contentInset = self.contentInset;
        CGRect visibleRect = self.bounds;
        visibleRect.origin.x += contentInset.left;
        visibleRect.origin.y += contentInset.top;
        visibleRect.size.width -= (contentInset.left + contentInset.right);
        visibleRect.size.height -= (contentInset.top + contentInset.bottom);
        return visibleRect;
    }
    return bounds;
}

@end
