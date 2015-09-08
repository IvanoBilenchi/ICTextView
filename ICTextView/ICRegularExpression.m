/**
 * ICRegularExpression.m
 * ---------------------------
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

#import "ICRegularExpression.h"
#import "ICPreprocessor.h"
#import "ICRangeUtils.h"

#pragma mark Extension

@interface ICRegularExpression ()

@property (nonatomic, strong, readonly) NSMutableArray *cachedMatchRanges;
@property (nonatomic, strong, readonly) NSRegularExpression *regex;

@property (nonatomic, readwrite) NSUInteger indexOfCurrentMatch;

@end

#pragma mark - Implementation

@implementation ICRegularExpression

#pragma mark - Properties

// cachedMatchRanges
@synthesize cachedMatchRanges = _cachedMatchRanges;

- (NSMutableArray *)cachedMatchRanges
{
    if (!_cachedMatchRanges)
    {
        NSMutableArray *cachedMatchRanges = [[NSMutableArray alloc] init];
        NSString *string = self.string;
        [self.regex enumerateMatchesInString:string
                                     options:(NSMatchingOptions)0
                                       range:NSMakeRange(0,string.length)
                                  usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                      ICUnusedParameter(flags, stop);
                                      [cachedMatchRanges addObject:[NSValue valueWithRange:result.range]];
                                  }];
        
        _cachedMatchRanges = cachedMatchRanges;
    }
    return _cachedMatchRanges;
}

// indexOfCurrentMatch
@synthesize indexOfCurrentMatch = _indexOfCurrentMatch;

- (void)setIndexOfCurrentMatch:(NSUInteger)indexOfCurrentMatch
{
    _indexOfCurrentMatch = (indexOfCurrentMatch < self.numberOfMatches ? indexOfCurrentMatch : NSNotFound);
}

// matchLocationsRange
@synthesize matchLocationsRange = _matchLocationsRange;

- (NSRange)matchLocationsRange
{
    if (NSEqualRanges(_matchLocationsRange, ICRangeNotFound))
    {
        NSMutableArray *matches = self.cachedMatchRanges;
        if (matches.count)
            _matchLocationsRange = NSMakeRange([[matches objectAtIndex:0] rangeValue].location, [[matches lastObject] rangeValue].location);
    }
    return _matchLocationsRange;
}

// Others
@synthesize circular = _circular;
@synthesize regex = _regex;
@synthesize string = _string;

#pragma mark - Public methods

- (id)initWithString:(NSString *)string pattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError *__autoreleasing *)error
{
    if ((self = [super init]))
    {
        NSError *__autoreleasing localError = nil;
        _regex = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&localError];
        
        if (error)
            *error = localError;
        
        if (localError)
            return nil;
        
        _indexOfCurrentMatch = NSNotFound;
        _matchLocationsRange = ICRangeNotFound;
        _string = string ?: [NSString string];
    }
    return self;
}

- (NSUInteger)numberOfMatches
{
    return self.cachedMatchRanges.count;
}

- (NSRegularExpressionOptions)options
{
    return self.regex.options;
}

- (NSString *)pattern
{
    return self.regex.pattern;
}

- (NSRange)rangeOfCurrentMatch
{
    return [self rangeOfMatchAtIndex:self.indexOfCurrentMatch];
}

- (NSRange)rangeOfFirstMatch
{
    return [self rangeOfMatchAtIndex:0];
}

- (NSRange)rangeOfFirstMatchInRange:(NSRange)range
{
    return [self rangeOfMatchAtIndex:[self indexOfFirstMatchInRange:range]];
}

- (NSRange)rangeOfLastMatch
{
    return [self rangeOfMatchAtIndex:self.numberOfMatches - 1];
}

- (NSRange)rangeOfLastMatchInRange:(NSRange)range
{
    return [self rangeOfMatchAtIndex:[self indexOfLastMatchInRange:range]];
}

- (NSRange)rangeOfMatchAtIndex:(NSUInteger)index
{
    NSRange returnRange = ICRangeNotFound;
    
    if (index < self.numberOfMatches)
    {
        self.indexOfCurrentMatch = index;
        returnRange = [[self.cachedMatchRanges objectAtIndex:index] rangeValue];
    }
    else
        self.indexOfCurrentMatch = NSNotFound;
    
    return returnRange;
}

- (NSRange)rangeOfNextMatch
{
    NSUInteger current = self.indexOfCurrentMatch;
    NSRange returnRange = ICRangeNotFound;
    
    if (current == NSNotFound || (self.circular && current == (self.numberOfMatches - 1)))
        returnRange = [self rangeOfMatchAtIndex:0];
    else
        returnRange = [self rangeOfMatchAtIndex:current + 1];
    
    return returnRange;
}

- (NSRange)rangeOfPreviousMatch
{
    NSUInteger current = self.indexOfCurrentMatch;
    NSRange returnRange = ICRangeNotFound;
    
    if (current == NSNotFound || (self.circular && current == 0))
        returnRange = [self rangeOfMatchAtIndex:(self.numberOfMatches - 1)];
    else
        returnRange = [self rangeOfMatchAtIndex:current - 1];
    
    return returnRange;
}

- (NSArray *)rangesOfMatchesInRange:(NSRange)range
{
    NSRange indexRange = [self indexRangeOfMatchesInRange:range];
    return (NSEqualRanges(indexRange, ICRangeNotFound) ? [NSArray array] : [self.cachedMatchRanges subarrayWithRange:indexRange]);
}

#pragma mark - Private methods

- (NSUInteger)indexOfFirstMatchInRange:(NSRange)range
{
    NSValue *comparisonRangeValue = [NSValue valueWithRange:NSMakeRange(range.location, 0)];
    NSUInteger count = self.numberOfMatches;
    NSArray *cachedMatchRanges = self.cachedMatchRanges;
    
    NSUInteger indexOfFirstPossibleRange = [cachedMatchRanges indexOfObject:comparisonRangeValue
                                                              inSortedRange:NSMakeRange(0, count)
                                                                    options:NSBinarySearchingInsertionIndex
                                                            usingComparator:ICRangeComparator];
    
    if (indexOfFirstPossibleRange >= count)
        return NSNotFound;
    
    NSRange possibleRange = [[cachedMatchRanges objectAtIndex:indexOfFirstPossibleRange] rangeValue];
    NSUInteger returnIndex = NSNotFound;
    
    if (ICRangeContainsRange(range, possibleRange))
        returnIndex = indexOfFirstPossibleRange;
    
    return returnIndex;
}

- (NSUInteger)indexOfLastMatchInRange:(NSRange)range
{
    NSRange indexRange = [self indexRangeOfMatchesInRange:range];
    return (NSEqualRanges(indexRange, ICRangeNotFound) ? NSNotFound : indexRange.location + indexRange.length - 1);
}

- (NSRange)indexRangeOfMatchesInRange:(NSRange)range
{
    NSUInteger indexOfFirstMatch = [self indexOfFirstMatchInRange:range];
    
    if (indexOfFirstMatch == NSNotFound)
        return ICRangeNotFound;
    
    NSRange returnRange = NSMakeRange(indexOfFirstMatch, 0);
    
    for (NSValue *rangeValue in [self.cachedMatchRanges subarrayWithRange:NSMakeRange(indexOfFirstMatch, self.numberOfMatches - indexOfFirstMatch)])
    {
        NSRange resultRange = rangeValue.rangeValue;
        
        if (ICRangeContainsRange(range, resultRange))
            returnRange.length++;
        else
            break;
    }
    
    return returnRange;
}

@end
