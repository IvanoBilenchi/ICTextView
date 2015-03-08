/**
 * ICTextView.m
 * ------------
 * https://github.com/Exile90/ICTextView.git
 *
 *
 * Version:
 * --------
 * 2.0.0
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

#pragma mark - Globals

// Search results highlighting supported starting from iOS 5.x
static BOOL highlightingSupported = NO;

// Accounts for textContainerInset on iOS 7+
static BOOL textContainerInsetSupported = NO;

// Fixes
static BOOL shouldApplyCaretFix = NO;
static BOOL shouldApplyCharacterRangeAtPointFix = NO;
static BOOL shouldApplyTextContainerFix = NO;

#pragma mark - Extension

@interface ICTextView ()
{
    // Highlights
    NSMutableDictionary *_highlightsByRange;
    NSMutableArray *_primaryHighlights;
    NSMutableOrderedSet *_secondaryHighlights;
    
    // Work variables
    NSTimer *_autoRefreshTimer;
    NSRange _cachedRange;
    ICRegularExpression *_regex;
    NSUInteger _searchIndex;
    UIView *_textSubview;
    BOOL _performedNewScroll;
    BOOL _searching;
    BOOL _searchVisibleRange;
    
    // Fixes
    BOOL _appliedCharacterRangeAtPointFix;
}

@end

#pragma mark - Implementation

@implementation ICTextView

#pragma mark - Synthesized properties

@synthesize animatedSearch = _animatedSearch;
@synthesize circularSearch = _circularSearch;
@synthesize highlightCornerRadius = _highlightCornerRadius;
@synthesize highlightSearchResults = _highlightSearchResults;
@synthesize maxHighlightedMatches = _maxHighlightedMatches;
@synthesize primaryHighlightColor = _primaryHighlightColor;
@synthesize scrollAutoRefreshDelay = _scrollAutoRefreshDelay;
@synthesize searchOptions = _searchOptions;
@synthesize searchRange = _searchRange;
@synthesize scrollPosition = _scrollPosition;
@synthesize secondaryHighlightColor = _secondaryHighlightColor;

#pragma mark - Accessor methods

// circularSearch
- (void)setCircularSearch:(BOOL)circularSearch
{
    _circularSearch = circularSearch;
    _regex.circular = circularSearch;
}

// scrollAutoRefreshDelay
- (void)setScrollAutoRefreshDelay:(NSTimeInterval)scrollAutoRefreshDelay
{
    _scrollAutoRefreshDelay = (scrollAutoRefreshDelay > 0.0 && scrollAutoRefreshDelay < 0.1) ? 0.1 : scrollAutoRefreshDelay;
}

#pragma mark - Class methods

+ (void)initialize
{
    if (self == [ICTextView class])
    {
        highlightingSupported = [self conformsToProtocol:@protocol(UITextInput)];
        
        // Using NSSelectorFromString() instead of @selector() to suppress unneccessary warnings on older SDKs
        textContainerInsetSupported = [self instancesRespondToSelector:NSSelectorFromString(@"textContainerInset")];
        
        shouldApplyCaretFix = NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0;
        shouldApplyCharacterRangeAtPointFix = NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0 && NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_7_1;
        shouldApplyTextContainerFix = NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0;
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
    return (_regex ? _regex.indexOfCurrentMatch : NSNotFound);
}

- (NSUInteger)numberOfMatches
{
    return _regex.numberOfMatches;
}

- (NSRange)rangeOfFoundString
{
    return (_regex ? ICRangeOffset(_regex.rangeOfCurrentMatch, _cachedRange.location) : ICRangeNotFound);
}

#pragma mark - Search

- (void)resetSearch
{
    if (highlightingSupported)
    {
        [self initializeHighlights];
        [_autoRefreshTimer invalidate];
        _autoRefreshTimer = nil;
    }
    
    _cachedRange = ICRangeZero;
    _regex = nil;
    _searchIndex = ICSearchIndexAuto;
    _searching = NO;
    _searchVisibleRange = NO;
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
    
    _searching = YES;
    
    // Get match
    if (_searchIndex == ICSearchIndexAuto)
    {
        if (searchDirection == ICTextViewSearchDirectionForward)
            [_regex rangeOfNextMatch];
        else
            [_regex rangeOfPreviousMatch];
    }
    else
    {
        NSUInteger index = _searchIndex - _cachedRange.location;
        
        if (searchDirection == ICTextViewSearchDirectionForward)
            [_regex rangeOfFirstMatchInRange:NSMakeRange(index, _regex.string.length - index)];
        else
            [_regex rangeOfLastMatchInRange:NSMakeRange(0, index)];
        
        _searchIndex = ICSearchIndexAuto;
    }
    
    NSRange matchRange = [self rangeOfFoundString];
    BOOL found = NO;
    
    if (matchRange.location == NSNotFound)
    {
        // Match not found
        _searching = NO;
    }
    else
    {
        // Match found
        found = YES;
        _searchVisibleRange = NO;
        
        // Add highlights
        if (highlightingSupported && _highlightSearchResults)
            [self highlightOccurrencesInMaskedVisibleRange];
        
        // Scroll
        [self scrollRangeToVisible:matchRange consideringInsets:YES animated:_animatedSearch];
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
    if (_searching)
    {
        NSUInteger stringToFindLength = stringToFind.length;
        NSUInteger foundStringLength = _regex.pattern.length;
        
        if (stringToFindLength != foundStringLength)
        {
            NSUInteger minLength = MIN(stringToFindLength, foundStringLength);
            NSString *lcStringToFind = [[stringToFind substringToIndex:minLength] lowercaseString];
            NSString *lcFoundString = [[_regex.pattern substringToIndex:minLength] lowercaseString];
            
            NSUInteger foundStringLocation = [self rangeOfFoundString].location;
            
            if ([lcStringToFind isEqualToString:lcFoundString] && foundStringLocation != NSNotFound)
                _searchIndex = foundStringLocation;
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
    
    UITextPosition *startPosition = [self positionFromPosition:self.beginningOfDocument offset:range.location];
    UITextPosition *endPosition = [self positionFromPosition:startPosition offset:range.length];
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
    
    switch (_scrollPosition)
    {
        case ICTextViewScrollPositionTop:
            toleranceArea.size.height = rect.size.height * 1.5;
            break;
            
        case ICTextViewScrollPositionMiddle:
            toleranceArea.size.height = rect.size.height * 1.5;
            toleranceArea.origin.y += ((visibleRect.size.height - toleranceArea.size.height) * 0.5);
            y -= ((visibleRect.size.height - rect.size.height) * 0.5);
            break;
            
        case ICTextViewScrollPositionBottom:
            toleranceArea.size.height = rect.size.height * 1.5;
            toleranceArea.origin.y += (visibleRect.size.height - toleranceArea.size.height);
            y -= (visibleRect.size.height - rect.size.height);
            break;
            
        case ICTextViewScrollPositionNone:
        default:
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
    
    return NSMakeRange([self offsetFromPosition:self.beginningOfDocument toPosition:start], [self offsetFromPosition:start toPosition:end]);
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
    highlight.layer.cornerRadius = _highlightCornerRadius < 0.0 ? frame.size.height * 0.2 : _highlightCornerRadius;
    highlight.backgroundColor = _secondaryHighlightColor;
    [_secondaryHighlights addObject:highlight];
    [self insertSubview:highlight belowSubview:_textSubview];
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
    if (!_searching)
        return;
    
    if (_performedNewScroll)
    {
        // Initial data
        UITextPosition *visibleStartPosition;
        NSRange visibleRange = [self visibleRangeConsideringInsets:YES startPosition:&visibleStartPosition endPosition:NULL];
        
        // Perform search in masked range
        NSUInteger cachedRangeLocation = _cachedRange.location;
        NSRange maskedRange = ICRangeOffset(NSIntersectionRange(_cachedRange, visibleRange), -cachedRangeLocation);
        NSMutableArray *rangeValues = [[NSMutableArray alloc] init];
        
        for (NSValue *rangeValue in [_regex rangesOfMatchesInRange:maskedRange])
            [rangeValues addObject:[NSValue valueWithRange:ICRangeOffset(rangeValue.rangeValue, cachedRangeLocation)]];
        
        ///// ADD SECONDARY HIGHLIGHTS /////
        
        if (rangeValues.count)
        {
            // Remove already present highlights
            NSMutableArray *rangesArray = [rangeValues mutableCopy];
            NSMutableIndexSet *indexesToRemove = [[NSMutableIndexSet alloc] init];
            [rangeValues enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger idx, BOOL *stop){
                if ([_highlightsByRange objectForKey:rangeValue])
                    [indexesToRemove addIndex:idx];
            }];
            [rangesArray removeObjectsAtIndexes:indexesToRemove];
            indexesToRemove = nil;
            
            if (rangesArray.count)
            {
                // Get text range of first result
                NSValue *firstRangeValue = [rangesArray objectAtIndex:0];
                NSRange previousRange = [firstRangeValue rangeValue];
                UITextPosition *start = [self positionFromPosition:visibleStartPosition offset:(previousRange.location - visibleRange.location)];
                UITextPosition *end = [self positionFromPosition:start offset:previousRange.length];
                UITextRange *textRange = [self textRangeFromPosition:start toPosition:end];
                
                // First range
                [_highlightsByRange setObject:[self addHighlightAtTextRange:textRange] forKey:firstRangeValue];
                
                if (rangesArray.count > 1)
                {
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
                    [self removeHighlightsTooFarFromRange:visibleRange];
            }
        }
        
        // Eventually update _searchIndex to match visible range
        if (_searchVisibleRange)
            _searchIndex = visibleRange.location;
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
    _primaryHighlightColor = [UIColor colorWithRed:150.0/255.0 green:200.0/255.0 blue:1.0 alpha:1.0];
    _scrollAutoRefreshDelay = 0.2;
    _searchIndex = ICSearchIndexAuto;
    _searchRange = ICRangeMax;
    _secondaryHighlights = [[NSMutableOrderedSet alloc] init];
    _secondaryHighlightColor = [UIColor colorWithRed:215.0/255.0 green:240.0/255.0 blue:1.0 alpha:1.0];
    
    // Detect _UITextContainerView or UIWebDocumentView (subview with text) for highlight placement
    for (UIView *view in self.subviews)
    {
        if ([view isKindOfClass:NSClassFromString(@"_UITextContainerView")] || [view isKindOfClass:NSClassFromString(@"UIWebDocumentView")])
        {
            _textSubview = view;
            break;
        }
    }
    
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
    for (UIView *hl in _primaryHighlights)
    {
        hl.backgroundColor = _secondaryHighlightColor;
        [_secondaryHighlights addObject:hl];
    }
    [_primaryHighlights removeAllObjects];
}

- (BOOL)initializeSearchWithPattern:(NSString *)pattern
{
    if (!pattern.length)
    {
        ICTextViewLog(@"Pattern cannot be nil or empty.");
        [self resetSearch];
        return NO;
    }
    
    // Calculate valid range
    NSUInteger textLength = self.text.length;
    NSRange localRange = NSIntersectionRange(NSMakeRange(0, textLength), _searchRange);
    
    if (localRange.length == 0 && textLength != 0)
        localRange = NSMakeRange(0, textLength);
    
    // Optimization and coherence checks
    BOOL samePattern = [pattern isEqualToString:_regex.pattern];
    BOOL sameOptions = (_searchOptions == _regex.options);
    BOOL sameSearchRange = NSEqualRanges(_cachedRange, localRange);
    BOOL allocateNewRegex = !(samePattern && sameOptions && sameSearchRange);
    
    // Regex allocation
    if (allocateNewRegex)
    {
        NSString *newString = (sameSearchRange ? _regex.string : [self.text substringWithRange:localRange]);
        
        NSError *__autoreleasing error = nil;
        
        _regex = [[ICRegularExpression alloc] initWithString:newString
                                                     pattern:pattern
                                                     options:_searchOptions
                                                       error:&error];
        if (error)
        {
            ICTextViewLog(@"Error while creating regex: %@", error);
            [self resetSearch];
            return NO;
        }
        
        _regex.circular = _circularSearch;
        _cachedRange = localRange;
    }
    
    // Reset highlights
    if (highlightingSupported && _highlightSearchResults)
    {
        [self initializePrimaryHighlights];
        if (allocateNewRegex)
            [self initializeSecondaryHighlights];
    }
    
    return YES;
}

- (void)initializeSecondaryHighlights
{
    for (UIView *hl in _secondaryHighlights)
        [hl removeFromSuperview];
    [_secondaryHighlights removeAllObjects];
    
    // Remove all objects in _highlightsByRange, except _rangeOfFoundString (primary)
    if (_primaryHighlights.count)
    {
        NSValue *rangeValue = [NSValue valueWithRange:[self rangeOfFoundString]];
        NSMutableArray *primaryHighlights = [_highlightsByRange objectForKey:rangeValue];
        [_highlightsByRange removeAllObjects];
        [_highlightsByRange setObject:primaryHighlights forKey:rangeValue];
    }
    else
        [_highlightsByRange removeAllObjects];
    
    // Allow highlights to be refreshed
    _performedNewScroll = YES;
}

- (void)removeHighlightsTooFarFromRange:(NSRange)range
{
    NSInteger tempMin = range.location - range.length;
    NSUInteger min = tempMin > 0 ? tempMin : 0;
    NSUInteger max = min + 3 * range.length;
    
    // Scan highlighted ranges
    NSMutableArray *keysToRemove = [[NSMutableArray alloc] init];
    [_highlightsByRange enumerateKeysAndObjectsUsingBlock:^(NSValue *rangeValue, NSArray *highlightsForRange, BOOL *stop){
        
        // Selectively remove highlights
        NSUInteger location = [rangeValue rangeValue].location;
        if ((location < min || location > max) && location != [self rangeOfFoundString].location)
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

- (void)scrollEnded
{
    [self highlightOccurrencesInMaskedVisibleRange];
    
    [_autoRefreshTimer invalidate];
    _autoRefreshTimer = nil;
    
    _performedNewScroll = NO;
}

// Scrolls to y coordinate without breaking the frame and (eventually) insets
- (void)scrollToY:(CGFloat)y animated:(BOOL)animated consideringInsets:(BOOL)considerInsets
{
    CGFloat min = 0.0;
    CGFloat max = self.contentSize.height - self.bounds.size.height;
    
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
    NSValue *rangeValue = [NSValue valueWithRange:range];
    NSMutableArray *highlightsForRange = [_highlightsByRange objectForKey:rangeValue];
    
    for (UIView *hl in highlightsForRange)
    {
        hl.backgroundColor = _primaryHighlightColor;
        [_primaryHighlights addObject:hl];
        [_secondaryHighlights removeObject:hl];
    }
}

- (void)textChanged
{
    if (_searching)
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
        localTextContainer = [[NSTextContainer alloc] initWithSize:frame.size];
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
    
    if (highlightingSupported && _highlightSearchResults)
    {
        _performedNewScroll = YES;
        
        // If user is scrolling, set flag to start searching from the visible range
        if (!_searchVisibleRange)
            _searchVisibleRange = ([self.panGestureRecognizer velocityInView:self].y != 0.0);
        
        // Eventually start auto-refresh timer
        if (_searching && _scrollAutoRefreshDelay && !_autoRefreshTimer)
        {
            _autoRefreshTimer = [NSTimer timerWithTimeInterval:_scrollAutoRefreshDelay target:self selector:@selector(highlightOccurrencesInMaskedVisibleRange) userInfo:nil repeats:YES];
            [[NSRunLoop mainRunLoop] addTimer:_autoRefreshTimer forMode:UITrackingRunLoopMode];
        }
        
        // Cancel previous request and perform new one
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scrollEnded) object:nil];
        [self performSelector:@selector(scrollEnded) withObject:nil afterDelay:0.1];
    }
}

- (void)setFrame:(CGRect)frame
{
    if (highlightingSupported && _highlightsByRange.count)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(initializeHighlights) object:nil];
        [self performSelector:@selector(initializeHighlights) withObject:nil afterDelay:0.1];
    }
    [super setFrame:frame];
}

#pragma mark - Fixes

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self characterRangeAtPointFix];
}

- (void)characterRangeAtPointFix
{
    if (shouldApplyCharacterRangeAtPointFix && !_appliedCharacterRangeAtPointFix && self.text.length > 1)
    {
        [self select:self];
        [self setSelectedTextRange:nil];
        _appliedCharacterRangeAtPointFix = YES;
    }
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
    [self characterRangeAtPointFix];
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
    [self characterRangeAtPointFix];
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
