/**
 * ICTextView.h
 * ------------
 * https://github.com/Exile90/ICTextView.git
 *
 *
 * Authors:
 * --------
 * Ivano Bilenchi (@SoftHardW)
 *
 *
 * Description:
 * ------------
 * `ICTextView` is a `UITextView` subclass with optimized support for string/regex search and highlighting.
 * It also features some iOS 7+ specific improvements and bugfixes to the standard `UITextView`.
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

#import <UIKit/UIKit.h>

#pragma mark Constants

/// Scroll position for ICTextView's scroll and search methods.
typedef enum
{
    /// Scrolls until the rect/range/text is visible with minimal movement.
    ICTextViewScrollPositionNone,
    
    /// Scrolls until the rect/range/text is on top of the text view.
    ICTextViewScrollPositionTop,
    
    /// Scrolls until the rect/range/text is in the middle of the text view.
    ICTextViewScrollPositionMiddle,
    
    /// Scrolls until the rect/range/text is at the bottom of the text view.
    ICTextViewScrollPositionBottom
} ICTextViewScrollPosition;

/// Direction for ICTextView's search methods.
typedef enum
{
    /// Forward search.
    ICTextViewSearchDirectionForward,
    
    /// Backward search.
    ICTextViewSearchDirectionBackward
} ICTextViewSearchDirection;

#pragma mark - Interface

/**
 UITextView subclass with optimized support for string/regex search and highlighting.
 
 It also features some iOS 7+ specific improvements and bugfixes to the standard UITextView.
 */
@interface ICTextView : UITextView

#pragma mark - Configuration

#pragma mark -- Appearance --

/// Color of the primary search highlight (default = RGB 150/200/255).
@property (nonatomic, strong) UIColor *primaryHighlightColor UI_APPEARANCE_SELECTOR;

/// Color of the secondary search highlights (default = RGB 215/240/255).
@property (nonatomic, strong) UIColor *secondaryHighlightColor UI_APPEARANCE_SELECTOR;

/// Highlight corner radius (default = fontSize * 0.2).
@property (nonatomic) CGFloat highlightCornerRadius UI_APPEARANCE_SELECTOR;

#pragma mark -- Behaviour --

/// Toggles scroll animation while searching (default = YES).
@property (nonatomic) BOOL animatedSearch;

/// Toggles circular search (default = NO).
@property (nonatomic) BOOL circularSearch;

/// Toggles highlights for search results (default = YES).
@property (nonatomic) BOOL highlightSearchResults;

/**
 Scroll position (default = ICTextViewScrollPositionNone).
 
 @see ICTextViewScrollPosition
 */
@property (nonatomic) ICTextViewScrollPosition scrollPosition;

/// Regex options to apply while searching (default = 0).
@property (nonatomic) NSRegularExpressionOptions searchOptions;

/// Allows restricting search to a specific range (default = { 0, NSUIntegerMax }).
@property (nonatomic) NSRange searchRange;

#pragma mark -- Performance --

/**
 Maximum number of cached highlighted matches (default = 100).
 
 @note This value is indicative. More search results will be highlighted if they are on-screen.
 
 @warning Setting this too high will impact memory usage.
 */
@property (nonatomic) NSUInteger maxHighlightedMatches;

/**
 Delay for the 'auto-refresh while scrolling' feature (default = 0.2 // min = 0.1 // off = 0.0).
 
 @note Decreasing/disabling this may improve performance when self.text is very big.
 */
@property (nonatomic) NSTimeInterval scrollAutoRefreshDelay;

#pragma mark - Output

/// String found during last search.
- (NSString *)foundString;

/// Index of the string found during last search (NSNotFound if not found).
- (NSUInteger)indexOfFoundString;

/// Number of matches in last search.
- (NSUInteger)numberOfMatches;

/// Range of the string found during last search ({ NSNotFound, 0 } if not found).
- (NSRange)rangeOfFoundString;

#pragma mark - Search

/// Resets search, starts from top.
- (void)resetSearch;

/**
 Scrolls to regex match.
 
 @param pattern Regular expression search pattern.
 
 @return YES if found, NO otherwise.
 */
- (BOOL)scrollToMatch:(NSString *)pattern;

/**
 Scrolls to next regex match.
 
 @see ICTextViewSearchDirection
 
 @param pattern Regular expression search pattern.
 @param searchDirection Forward or backward search.
 
 @return YES if found, NO otherwise.
 */
- (BOOL)scrollToMatch:(NSString *)pattern searchDirection:(ICTextViewSearchDirection)searchDirection;

/**
 Scrolls to next matching string.
 
 @param stringToFind String to find.
 
 @return YES if found, NO otherwise.
 */
- (BOOL)scrollToString:(NSString *)stringToFind;

/**
 Scrolls to next matching string.
 
 @see ICTextViewSearchDirection
 
 @param stringToFind String to find.
 @param searchDirection Forward or backward search.
 
 @return YES if found, NO otherwise.
 */
- (BOOL)scrollToString:(NSString *)stringToFind searchDirection:(ICTextViewSearchDirection)searchDirection;

#pragma mark - Misc

/**
 Scrolls until the specified text range is completely visible. Animated.
 
 @param range Range to scroll to.
 @param considerInsets Consider 'contentInset' and 'textContainerInset' while computing the visible area.
 */
- (void)scrollRangeToVisible:(NSRange)range consideringInsets:(BOOL)considerInsets;

/**
 Scrolls until the specified text range is completely visible.
 
 @param range Range to scroll to.
 @param considerInsets Consider 'contentInset' and 'textContainerInset' while computing the visible area.
 @param animated Toggles scroll animation.
 */
- (void)scrollRangeToVisible:(NSRange)range consideringInsets:(BOOL)considerInsets animated:(BOOL)animated;

/**
 Scrolls until the specified rect is completely visible.
 
 @param rect Rect to scroll to.
 @param animated Toggles scroll animation.
 @param considerInsets Consider 'contentInset' and 'textContainerInset' while computing the visible area.
 */
- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated consideringInsets:(BOOL)considerInsets;

/**
 Currently visible text range.
 
 @param considerInsets Consider 'contentInset' and 'textContainerInset' while computing the visible area.
 
 @return Visible text range.
 */
- (NSRange)visibleRangeConsideringInsets:(BOOL)considerInsets;

/**
 Currently visible text range.
 
 @param considerInsets Consider 'contentInset' and 'textContainerInset' while computing the visible area.
 @param startPosition Returns the starting position of the text range. Pass nil if you don't need this information.
 @param endPosition Returns the ending position of the text range. Pass nil if you don't need this information.
 
 @return Visible text range.
 */
- (NSRange)visibleRangeConsideringInsets:(BOOL)considerInsets startPosition:(UITextPosition *__autoreleasing *)startPosition endPosition:(UITextPosition *__autoreleasing *)endPosition;

/**
 Currently visible rect.
 
 @param considerInsets Consider 'contentInset' and 'textContainerInset' while computing the visible area.
 
 @return Visible rect.
 */
- (CGRect)visibleRectConsideringInsets:(BOOL)considerInsets;

#pragma mark - Deprecated

- (BOOL)scrollToMatch:(NSString *)pattern searchOptions:(NSRegularExpressionOptions)options __deprecated;
- (BOOL)scrollToMatch:(NSString *)pattern searchOptions:(NSRegularExpressionOptions)options range:(NSRange)range __deprecated;
- (BOOL)scrollToMatch:(NSString *)pattern searchOptions:(NSRegularExpressionOptions)options animated:(BOOL)animated atScrollPosition:(ICTextViewScrollPosition)scrollPosition __deprecated;
- (BOOL)scrollToMatch:(NSString *)pattern searchOptions:(NSRegularExpressionOptions)options range:(NSRange)range animated:(BOOL)animated atScrollPosition:(ICTextViewScrollPosition)scrollPosition __deprecated;

- (BOOL)scrollToString:(NSString *)stringToFind searchOptions:(NSRegularExpressionOptions)options __deprecated;
- (BOOL)scrollToString:(NSString *)stringToFind searchOptions:(NSRegularExpressionOptions)options range:(NSRange)range __deprecated;
- (BOOL)scrollToString:(NSString *)stringToFind searchOptions:(NSRegularExpressionOptions)options animated:(BOOL)animated atScrollPosition:(ICTextViewScrollPosition)scrollPosition __deprecated;
- (BOOL)scrollToString:(NSString *)stringToFind searchOptions:(NSRegularExpressionOptions)options range:(NSRange)range animated:(BOOL)animated atScrollPosition:(ICTextViewScrollPosition)scrollPosition __deprecated;

- (void)scrollRangeToVisible:(NSRange)range consideringInsets:(BOOL)considerInsets animated:(BOOL)animated atScrollPosition:(ICTextViewScrollPosition)scrollPosition __deprecated;
- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated consideringInsets:(BOOL)considerInsets atScrollPosition:(ICTextViewScrollPosition)scrollPosition __deprecated;

@end
