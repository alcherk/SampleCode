/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 */

#import <string>

#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/CAMetalLayer.h>

#import "AAPLView.h"

#import "AAPLTQRenderer.h"
#import "AAPLViewController.h"

static AAPL::Metal::TQRenderer *AAPLViewControllerCreateRenderer(AAPLView *pRenderView)
{
    AAPL::Metal::TQRenderer *pRenderer = nullptr;
    
    if(pRenderView)
    {
        try
        {
            // Catch Memory error
            pRenderer = new AAPL::Metal::TQRenderer(pRenderView);
            
            pRenderer->finalize();
        } // try
        catch(std::bad_alloc& ba)
        {
            NSLog(@">> ERROR: Failed creating a renderer object: \"%s\"", ba.what());
            
            return nullptr;
        } // catch
    } // if
    
    return pRenderer;
} // AAPLViewControllerCreateRenderer

@implementation AAPLViewController
{
@private
    // Textured Quad renderer object
    AAPL::Metal::TQRenderer *mpRenderer;
    
    // Display link timer
    CADisplayLink *mpTimer;
}

- (void) cleanUp
{
    if(mpRenderer)
    {
        delete mpRenderer;
        
        mpRenderer = nullptr;
    } // if
    
    if(mpTimer)
    {
        [mpTimer invalidate];
        [mpTimer release];
        
        mpTimer = nil;
    } // if
} // _cleanUp

- (void) dealloc
{
    [super dealloc];
    
    [self cleanUp];
} // dealloc

- (void) render:(id)sender
{
    // There is no autorelease pool when this method is
    // called - as it is called from a secondary thread.
    // It's important to create an auto-release pool
    // for a display link callback or an application will
    // leak objects.
    NSAutoreleasePool *pPool = [NSAutoreleasePool new];
    
    if(pPool)
    {
        // Display the textured quad
        mpRenderer->present();
        
        // Release the pool
        [pPool release];
    } // if
} // render

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    AAPLView *pRenderView = (AAPLView *)self.view;
    
    mpRenderer = AAPLViewControllerCreateRenderer(pRenderView);
    
    if(mpRenderer != nullptr)
    {
        // as the timer fires, we render
        mpTimer = [CADisplayLink displayLinkWithTarget:self
                                              selector:@selector(render:)];
        
        [mpTimer addToRunLoop:[NSRunLoop mainRunLoop]
                      forMode:NSDefaultRunLoopMode];
    } // if
    else
    {
        NSLog(@">> ERROR: Exiting due to a failure in creating a renderer object!");
        
        exit(-1);
    } // else
} // viewDidLoad

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    if([self isViewLoaded] && ([[self view] window] == nil))
    {
        self.view = nil;
        
        [self cleanUp];
    } // if
} // didReceiveMemoryWarning

@end
