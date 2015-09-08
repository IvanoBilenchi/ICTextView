/**
 * ICRegularExpression.h
 * ---------------------
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
 * Support class used in the ICTextView project.
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

#import <Foundation/Foundation.h>

#pragma mark Interface

@interface ICRegularExpression : NSObject

#pragma mark - Properties

@property (nonatomic) BOOL circular;

@property (nonatomic, readonly) NSUInteger indexOfCurrentMatch;
@property (nonatomic, readonly) NSUInteger numberOfMatches;
@property (nonatomic, readonly) NSRange matchLocationsRange;

@property (nonatomic, readonly) NSString *string;
@property (nonatomic, readonly) NSString *pattern;
@property (nonatomic, readonly) NSRegularExpressionOptions options;

#pragma mark - Methods

- (id)initWithString:(NSString *)string pattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError *__autoreleasing *)error;

- (NSRange)rangeOfCurrentMatch;
- (NSRange)rangeOfFirstMatch;
- (NSRange)rangeOfFirstMatchInRange:(NSRange)range;
- (NSRange)rangeOfLastMatch;
- (NSRange)rangeOfLastMatchInRange:(NSRange)range;
- (NSRange)rangeOfMatchAtIndex:(NSUInteger)index;
- (NSRange)rangeOfNextMatch;
- (NSRange)rangeOfPreviousMatch;

- (NSArray *)rangesOfMatchesInRange:(NSRange)range;

@end
