/**
 * ICRangeUtils.m
 * --------------
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

#import "ICRangeUtils.h"

#pragma mark Constants

NSRange const ICRangeMax = { 0, NSUIntegerMax };
NSRange const ICRangeNotFound = { NSNotFound, 0 };
NSRange const ICRangeZero = { 0, 0 };

#pragma mark - Blocks

NSComparisonResult (^ICRangeComparator)(NSValue *rangeValue1, NSValue *rangeValue2) = ^NSComparisonResult(NSValue *rangeValue1, NSValue *rangeValue2)
{
    NSRange range1 = [rangeValue1 rangeValue];
    NSRange range2 = [rangeValue2 rangeValue];
    
    NSComparisonResult result = NSOrderedSame;
    
    if (range1.location < range2.location)
        result = NSOrderedAscending;
    else if (range1.location > range2.location)
        result = NSOrderedDescending;
    else if (range1.length < range2.length)
        result = NSOrderedAscending;
    else if (range1.length > range2.length)
        result = NSOrderedDescending;
    
    return result;
};
