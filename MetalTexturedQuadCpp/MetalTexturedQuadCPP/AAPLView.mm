/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 */

#import <QuartzCore/CAMetalLayer.h>

#import "AAPLView.h"

@implementation AAPLView

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

@end
