/**
 * Compatibility macros and constants
 **/

#import <Foundation/Foundation.h>

#ifndef __IPHONE_6_0
typedef enum
{
    NSTextAlignmentLeft      = 0,
    NSTextAlignmentCenter    = 1,
    NSTextAlignmentRight     = 2,
    NSTextAlignmentJustified = 3,
    NSTextAlignmentNatural   = 4,
} NSTextAlignment;
#endif
