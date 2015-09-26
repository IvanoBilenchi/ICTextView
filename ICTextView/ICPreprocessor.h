/**
 * ICPreprocessor.h
 * ----------------
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
 * Convenient preprocessor macros used throughout ICTextView.
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

// For old SDKs
#ifndef NSFoundationVersionNumber_iOS_5_0
#define NSFoundationVersionNumber_iOS_5_0 881.00
#endif

#ifndef NSFoundationVersionNumber_iOS_6_0
#define NSFoundationVersionNumber_iOS_6_0 993.00
#endif

#ifndef NSFoundationVersionNumber_iOS_7_0
#define NSFoundationVersionNumber_iOS_7_0 1047.20
#endif

#ifndef NSFoundationVersionNumber_iOS_7_1
#define NSFoundationVersionNumber_iOS_7_1 1047.25
#endif

#ifndef NSFoundationVersionNumber_iOS_9_0
#define NSFoundationVersionNumber_iOS_9_0 1240.1
#endif

// Unused variable suppression
#define IC_Internal_Stringify(macro_arg_string_literal) #macro_arg_string_literal
#define ICUnusedParameter(...) _Pragma(IC_Internal_Stringify(unused(__VA_ARGS__)))

// Debug logging
#if DEBUG
#define ICTextViewLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define ICTextViewLog(...)
#endif
