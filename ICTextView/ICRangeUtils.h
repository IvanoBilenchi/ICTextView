/**
 * ICRangeUtils.h
 * --------------
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
 * Utility NSRange functions and constants used throughout ICTextView.
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

#import <Foundation/NSRange.h>

#pragma mark Constants

extern NSRange const ICRangeMax;
extern NSRange const ICRangeNotFound;
extern NSRange const ICRangeZero;

#pragma mark - Blocks

extern NSComparisonResult (^ICRangeComparator)(NSValue *rangeValue1, NSValue *rangeValue2);

#pragma mark - Functions

NS_INLINE BOOL ICRangeContainsIndex (NSRange range, NSUInteger index)
{
    return (index >= range.location && index <= (range.location + range.length));
}

NS_INLINE BOOL ICRangeContainsRange (NSRange range1, NSRange range2)
{
    return ((range1.location <= range2.location) && (range1.location + range1.length >= range2.location + range2.length));
}

NS_INLINE NSRange ICRangeOffset (NSRange range, NSUInteger offset)
{
    NSUInteger newLocation = range.location + offset;
    
    if (newLocation > NSNotFound)
        return ICRangeNotFound;
    
    range.location = newLocation;
    
    return range;
}
