/**
 * Compatibility macros and constants
 **/

#import <Foundation/Foundation.h>

#pragma mark Preprocessor

// Foundation versions
#ifndef NSFoundationVersionNumber_iOS_6_1
#define NSFoundationVersionNumber_iOS_6_1 993.00
#endif

// Background dispatch priority
#define DISPATCH_QUEUE_PRIORITY_BG (FOUNDATION_LE(NSFoundationVersionNumber_iOS_4_2) ? DISPATCH_QUEUE_PRIORITY_LOW : DISPATCH_QUEUE_PRIORITY_BACKGROUND)

// Enums and options
#ifndef NS_ENUM

#undef NS_OPTIONS
#undef CF_ENUM
#undef CF_OPTIONS

#if (__cplusplus && __cplusplus >= 201103L && (__has_extension(cxx_strong_enums) || __has_feature(objc_fixed_enum))) || (!__cplusplus && __has_feature(objc_fixed_enum))
#define CF_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#if (__cplusplus)
#define CF_OPTIONS(_type, _name) _type _name; enum : _type
#else
#define CF_OPTIONS(_type, _name) enum _name : _type _name; enum _name : _type
#endif
#else
#define CF_ENUM(_type, _name) _type _name; enum
#define CF_OPTIONS(_type, _name) _type _name; enum
#endif

#define NS_ENUM(_type, _name) CF_ENUM(_type, _name)
#define NS_OPTIONS(_type, _name) CF_OPTIONS(_type, _name)

#endif

#pragma mark - Constants

#ifndef __IPHONE_6_0
typedef NS_ENUM(NSInteger, NSTextAlignment)
{
    NSTextAlignmentLeft      = 0,
#if TARGET_OS_IPHONE
    NSTextAlignmentCenter    = 1,
    NSTextAlignmentRight     = 2,
#else
    NSTextAlignmentRight     = 1,
    NSTextAlignmentCenter    = 2,
#endif
    NSTextAlignmentJustified = 3,
    NSTextAlignmentNatural   = 4,
};
#endif
