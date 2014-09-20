/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 */

#import <string>

#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

#import "AAPLView.h"

#import "AAPLTexturedQuad.h"
#import "AAPLTQRenderer.h"

// Only allow 1 command buffers in flight at any given time so
// we don't overwrite the renderpass descriptor.
static const uint32_t kInFlightCommandBuffers = 1;

class AAPL::Metal::TQRendererData
{
public:
    // Rendering view, viewport and layer
    AAPLView      *mpRenderView;
    CAMetalLayer  *mpRenderingLayer;
    MTLViewport    m_Viewport;
    
    // Renderer globals
    id <MTLDevice>             m_Device;
    id <MTLCommandQueue>       m_CommandQueue;
    id <MTLDepthStencilState>  m_DepthState;
    
    // Semaphore
    dispatch_semaphore_t  m_InflightSemaphore;
    
    // Clear color
    MTLClearColor m_ClearColor;
    
    // Textured quad
    AAPL::Metal::TexturedQuad *mpTexturedQuad;
};

typedef AAPL::Metal::TQRendererData   AAPLMetalTQRData;
typedef AAPLMetalTQRData             *AAPLMetalTQRDataRef;

static void AAPLMetalTQRendererReleaseDepthState(AAPLMetalTQRDataRef pRenderer)
{
    if(pRenderer->m_DepthState)
    {
        [pRenderer->m_DepthState release];
        
        pRenderer->m_DepthState = nil;
    } // if
} // AAPLMetalTQRendererReleaseDepthState

static void AAPLMetalTQRendererReleaseCommandQueue(AAPLMetalTQRDataRef pRenderer)
{
    if(pRenderer->m_CommandQueue)
    {
        [pRenderer->m_CommandQueue release];
        
        pRenderer->m_CommandQueue = nil;
    } // if
} // AAPLMetalTQRendererReleaseCommandQueue

static void AAPLMetalTQRendererReleaseDevice(AAPLMetalTQRDataRef pRenderer)
{
    if(pRenderer->m_Device)
    {
        [pRenderer->m_Device release];
        
        pRenderer->m_Device = nil;
    } // if
} // AAPLMetalTQRendererReleaseDevice

static void AAPLMetalTQRendererReleaseView(AAPLMetalTQRDataRef pRenderer)
{
    if(pRenderer->mpRenderView)
    {
        [pRenderer->mpRenderView release];
        
        pRenderer->mpRenderView     = nil;
        pRenderer->mpRenderingLayer = nil;
    } // if
} // AAPLMetalTQRendererReleaseView

static void AAPLMetalTQRendererDelete(AAPL::Metal::TQRendererData *pRenderer)
{
    if(pRenderer != nullptr)
    {
        // Release assets
        AAPLMetalTQRendererReleaseDepthState(pRenderer);
        AAPLMetalTQRendererReleaseCommandQueue(pRenderer);
        AAPLMetalTQRendererReleaseDevice(pRenderer);
        AAPLMetalTQRendererReleaseView(pRenderer);
        
        // Delete the renderer object
        delete pRenderer;
        
        pRenderer = nullptr;
    } // if
} // AAPLMetalTQRendererDelete

static bool AAPLMetalTQRendererAcquireDepthStencilState(AAPLMetalTQRDataRef pRenderer)
{
    MTLDepthStencilDescriptor *pDepthStateDesc = [MTLDepthStencilDescriptor new];
    
    if(!pDepthStateDesc)
    {
        NSLog(@">> ERROR: Failed creating a depth stencil descriptor!");
        
        return false;
    } // if
    
    pDepthStateDesc.depthCompareFunction = MTLCompareFunctionAlways;
    pDepthStateDesc.depthWriteEnabled    = true;
    
    pRenderer->m_DepthState = [pRenderer->m_Device newDepthStencilStateWithDescriptor:pDepthStateDesc];
    
    [pDepthStateDesc release];
    
    if(!pRenderer->m_DepthState)
    {
        return false;
    } // if
    
    return true;
} // AAPLMetalTQRendererAcquireDepthStencilState

static bool AAPLMetalTQRendererSetRenderingLayer(AAPLView *pRenderView,
                                                 AAPLMetalTQRDataRef pRenderer)
{
    // Set the render view
    pRenderer->mpRenderView = [pRenderView retain];
    
    if(!pRenderer->mpRenderView)
    {
        return false;
    } // if
    
    // Grab the CA Metal Layer created by the nib
    pRenderer->mpRenderingLayer = (CAMetalLayer *)pRenderer->mpRenderView.layer;
    
    if(!pRenderer->mpRenderingLayer)
    {
        return false;
    } // if
    
    pRenderer->mpRenderingLayer.presentsWithTransaction = false;
    pRenderer->mpRenderingLayer.drawsAsynchronously     = true;
    
    return true;
} // AAPLMetalTQRendererSetRenderingLayer

static void AAPLMetalTQRendererSetViewport(AAPLMetalTQRDataRef pRenderer)
{
    CGRect viewBounds = pRenderer->mpRenderView.frame;
    
    MTLViewport viewport = {0.0f, 0.0f, viewBounds.size.width, viewBounds.size.height, 0.0f, 1.0f};
    
    pRenderer->m_Viewport = viewport;
} // AAPLMetalTQRendererSetViewport

// set a background color to make sure the layer appears
static void AAPLMetalTQRendererSetBackgroundColor(AAPLMetalTQRDataRef pRenderer)
{
    CGColorSpaceRef pColorSpace = CGColorSpaceCreateDeviceRGB();
    
    if(pColorSpace != nullptr)
    {
        CGFloat components[4] = {0.5, 0.5, 0.5, 1.0};
        
        CGColorRef pGrayColor = CGColorCreate(pColorSpace,components);
        
        if(pGrayColor != nullptr)
        {
            pRenderer->mpRenderingLayer.backgroundColor = pGrayColor;
            
            CFRelease(pGrayColor);
        } // if
        
        CFRelease(pColorSpace);
    } // if
} // AAPLMetalTQRendererSetBackgroundColor

static bool AAPLMetalTQRendererAcquireDevice(AAPLMetalTQRDataRef pRenderer)
{
    // Find a usable Device
    pRenderer->m_Device = MTLCreateSystemDefaultDevice();
    
    if(!pRenderer->m_Device)
    {
        return false;
    } // if
    
    // set the device on the rendering layer and provide a pixel format
    pRenderer->mpRenderingLayer.device          = pRenderer->m_Device;
    pRenderer->mpRenderingLayer.pixelFormat     = MTLPixelFormatBGRA8Unorm;
    pRenderer->mpRenderingLayer.framebufferOnly = true;
    
    return true;
} // AAPLMetalTQRendererAcquireDevice

static bool AAPLMetalTQRendererPrepare(AAPLMetalTQRDataRef pRenderer)
{
    // Initialize viewport bounds
    AAPLMetalTQRendererSetViewport(pRenderer);
    
    // Set a background color to make sure the layer appears
    AAPLMetalTQRendererSetBackgroundColor(pRenderer);
    
    // Find a usable Device
    if(!AAPLMetalTQRendererAcquireDevice(pRenderer))
    {
        NSLog(@">> ERROR: Failed creating a default system device!");
        
        return false;
    } // if
    
    // Create a new command queue
    pRenderer->m_CommandQueue = [pRenderer->m_Device newCommandQueue];
    
    if(!pRenderer->m_CommandQueue)
    {
        NSLog(@">> ERROR: Failed creating a new command queue!");
        
        return false;
    } // if
    
    if(!AAPLMetalTQRendererAcquireDepthStencilState(pRenderer))
    {
        NSLog(@">> ERROR: Failed creating a depth stencil state!");
        
        return false;
    } // if
    
    // Set the default clear color
    pRenderer->m_ClearColor = MTLClearColorMake(0.65f, 0.65f, 0.65f, 1.0f);
    
    // Create a semaphore for synchronization
    pRenderer->m_InflightSemaphore = dispatch_semaphore_create(kInFlightCommandBuffers);
    
    return true;
} // AAPLMetalTQRendererPrepare

static AAPLMetalTQRDataRef AAPLMetalTQRendererCreate(AAPLView *pRenderView)
{
    AAPLMetalTQRDataRef pRenderer = nullptr;
    
    try
    {
        // Catch Memory error
        pRenderer = new AAPL::Metal::TQRendererData;
        
        // Initialize the opaque data reference
        std::memset(pRenderer, 0x0, sizeof(AAPL::Metal::TQRendererData));
        
        // Grab the CA Metal Layer created by the nib
        if(!AAPLMetalTQRendererSetRenderingLayer(pRenderView, pRenderer))
        {
            throw @">> ERROR: Failed acquring Core Animation Metal layer!";
        } // if
        
        // Acquire all the other assets
        if(!AAPLMetalTQRendererPrepare(pRenderer))
        {
            throw @">> ERROR: Failed acquring rendering Metal assets for a textured quad!";
        } // if
    } // try
    catch(std::bad_alloc& ba)
    {
        NSLog(@">> ERROR: Failed creating a backing-store for a textured quad renderer: \"%s\"", ba.what());
    } // catch
    catch(NSString *pString)
    {
        NSLog(@">> ERROR: %@", pString);
        
        AAPLMetalTQRendererDelete(pRenderer);
    } // catch
    
    return pRenderer;
} // AAPLMetalTQRendererCreate

static AAPLMetalTQRDataRef AAPLMetalTQRendererCreateCopy(const AAPLMetalTQRData * const pRendererSrc)
{
    AAPLMetalTQRDataRef pRendererDst = nullptr;
    
    if(pRendererSrc != nullptr)
    {
        pRendererDst = AAPLMetalTQRendererCreate(pRendererSrc->mpRenderView);
        
        if(pRendererDst != nullptr)
        {
            pRendererDst->mpTexturedQuad = pRendererSrc->mpTexturedQuad;
        } // if
    } // if
    
    return pRendererDst;
} // AAPLMetalTQRendererCreateCopy

static bool AAPLMetalTQRendererFinalize(const std::string& path,
                                        AAPLMetalTQRDataRef pRenderer)
{
    try
    {
        // Catch Memory error
        AAPL::Metal::TexturedQuad *pTexturedQuad = new AAPL::Metal::TexturedQuad(path, pRenderer->m_Device);
        
        if(pRenderer->mpTexturedQuad != nullptr)
        {
            delete pRenderer->mpTexturedQuad;
        } // if
        
        pRenderer->mpTexturedQuad = pTexturedQuad;
    } // try
    catch(std::bad_alloc& ba)
    {
        NSLog(@">> ERROR: Failed creating a textured quad from an image at path: \"%s\"", ba.what());
        
        return false;
    } // catch
    
    return true;
} // AAPLMetalTQRendererFinalize

static bool AAPLMetalTQRendererFinalize(const std::string& name,
                                        const std::string& ext,
                                        AAPLMetalTQRDataRef pRenderer)
{
    try
    {
        // Catch Memory error
        AAPL::Metal::TexturedQuad *pTexturedQuad = new AAPL::Metal::TexturedQuad(name, ext, pRenderer->m_Device);

        if(pRenderer->mpTexturedQuad != nullptr)
        {
            delete pRenderer->mpTexturedQuad;
        } // if
        
        pRenderer->mpTexturedQuad = pTexturedQuad;
    } // try
    catch(std::bad_alloc& ba)
    {
        NSLog(@">> ERROR: Failed creating a textured quad from an image in app bundle: \"%s\"", ba.what());
        
        return false;
    } // catch
    
    return true;
} // AAPLMetalTQRendererFinalize

static MTLRenderPassDescriptor *AAPLMetalTQRendererCreateDescriptor(id <MTLTexture> texture,
                                                                    AAPLMetalTQRDataRef pRenderer)
{
    MTLRenderPassDescriptor *pRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    
    if(!pRenderPassDescriptor)
    {
        NSLog(@">> ERROR: Failed acquiring a render pass descriptor!");
        
        return nil;
    } // if
    
    pRenderPassDescriptor.colorAttachments[0].texture     = texture;
    pRenderPassDescriptor.colorAttachments[0].loadAction  = MTLLoadActionClear;
    pRenderPassDescriptor.colorAttachments[0].clearColor  = pRenderer->m_ClearColor;
    pRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    return pRenderPassDescriptor;
} // AAPLMetalTQRendererCreateDescriptor

static void AAPLMetalTQRendererEncode(id <MTLRenderCommandEncoder> renderEncoder,
                                      AAPLMetalTQRDataRef pRenderer)
{
    if(renderEncoder)
    {
        // Set context state with the render encoder
        [renderEncoder setViewport:pRenderer->m_Viewport];
        [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [renderEncoder setDepthStencilState:pRenderer->m_DepthState];
        
        // Encode the textured quad
        pRenderer->mpTexturedQuad->encode(renderEncoder);
        
        // Tell the render context we want to draw our triangle primitives
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6
                        instanceCount:1];
        
        // End the encoding
        [renderEncoder endEncoding];
    } // if
} // AAPLMetalTQRendererEncode

static void AAPLMetalTQRendererPresent(AAPLMetalTQRDataRef pRenderer)
{
    dispatch_semaphore_wait(pRenderer->m_InflightSemaphore, DISPATCH_TIME_FOREVER);
    
    // Update the linear transformation matrices of the textured quad
    pRenderer->mpTexturedQuad->update(pRenderer->mpRenderingLayer.frame);
    
    // Acquire the next drawable from the rendering layer
    id <CAMetalDrawable>  drawable = [pRenderer->mpRenderingLayer nextDrawable];
    
    if(drawable)
    {
        id <MTLCommandBuffer> commandBuffer = [pRenderer->m_CommandQueue commandBuffer];
        
        if(commandBuffer)
        {
            // obtain the renderpass descriptor for this drawable
            MTLRenderPassDescriptor *pRenderPassDescriptor
            = AAPLMetalTQRendererCreateDescriptor(drawable.texture, pRenderer);
            
            if(pRenderPassDescriptor)
            {
                // Get a render encoder
                id <MTLRenderCommandEncoder>  renderEncoder
                = [commandBuffer renderCommandEncoderWithDescriptor:pRenderPassDescriptor];
                
                // Encode into a renderer
                AAPLMetalTQRendererEncode(renderEncoder, pRenderer);
                
                // Dispatch the command buffer
                __block dispatch_semaphore_t dispatchSemaphore = pRenderer->m_InflightSemaphore;
                
                [commandBuffer addCompletedHandler:^(id <MTLCommandBuffer> cmdb){
                    dispatch_semaphore_signal(dispatchSemaphore);
                }];
                
                // Present and commit the command buffer
                [commandBuffer presentDrawable:drawable];
                [commandBuffer commit];
            } // if
        } // if
    } // if
} // AAPLMetalTQRendererPresent

// Construct a render from an application view
AAPL::Metal::TQRenderer::TQRenderer(AAPLView *pRenderView)
{
    mpRenderer = AAPLMetalTQRendererCreate(pRenderView);
} // Constructor

// Copy Constructor
AAPL::Metal::TQRenderer::TQRenderer(const AAPL::Metal::TQRenderer& rRenderer)
{
    AAPLMetalTQRDataRef pRenderer = AAPLMetalTQRendererCreateCopy(rRenderer.mpRenderer);
    
    if(pRenderer != nullptr)
    {
        AAPLMetalTQRendererDelete(mpRenderer);
        
        mpRenderer = pRenderer;
    } // if
} // Copy Constructor

// Assignment operator
AAPL::Metal::TQRenderer& AAPL::Metal::TQRenderer::operator=(const AAPL::Metal::TQRenderer& rRenderer)
{
    if(this != &rRenderer)
    {
        AAPLMetalTQRDataRef pRenderer = AAPLMetalTQRendererCreateCopy(rRenderer.mpRenderer);
        
        if(pRenderer != nullptr)
        {
            AAPLMetalTQRendererDelete(mpRenderer);
            
            mpRenderer = pRenderer;
        } // if
    } // if
    
    return *this;
} // Assignment operator

// Destructor
AAPL::Metal::TQRenderer::~TQRenderer()
{
    AAPLMetalTQRendererDelete(mpRenderer);
} // Destructor

// Add a textured quad constructed from an image at a path.
// If the path is an empty string finalize will fail.
bool AAPL::Metal::TQRenderer::finalize(const std::string& path)
{
    return (mpRenderer != nullptr) ? AAPLMetalTQRendererFinalize(path, mpRenderer) : false;
} // finalize

// Add a textured quad constructed from an image in app bundle.
// If name is an empty string use "Default" as name.  If the
// ext is an empty string use "jpg" as the file's extension.
bool AAPL::Metal::TQRenderer::finalize(const std::string& name,
                                       const std::string& ext)
{
    return (mpRenderer != nullptr) ? AAPLMetalTQRendererFinalize(name, ext, mpRenderer) : false;
} // finalize

// Present the rendered textured quad
void AAPL::Metal::TQRenderer::present()
{
    if(mpRenderer != nullptr)
    {
        AAPLMetalTQRendererPresent(mpRenderer);
    } // if
} // present

// Get the texture target
const MTLTextureType AAPL::Metal::TQRenderer::target() const
{
    return (mpRenderer != nullptr) ? mpRenderer->mpTexturedQuad->target() : MTLTextureType(0);
} // target

// Get the texture width
const uint32_t AAPL::Metal::TQRenderer::width() const
{
    return (mpRenderer != nullptr) ? mpRenderer->mpTexturedQuad->width() : 0;
} // width

// Get the texture height
const uint32_t AAPL::Metal::TQRenderer::height() const
{
    return (mpRenderer != nullptr) ? mpRenderer->mpTexturedQuad->height() : 0;
} // height

// Get the texture depth
const uint32_t AAPL::Metal::TQRenderer::depth() const
{
    return (mpRenderer != nullptr) ? mpRenderer->mpTexturedQuad->depth() : 0;
} // depth

// Get the texture format
const uint32_t AAPL::Metal::TQRenderer::format() const
{
    return (mpRenderer != nullptr) ? mpRenderer->mpTexturedQuad->format() : 0;
} // format

// Querey:  Is the image vertically reflected?
const bool AAPL::Metal::TQRenderer::isFlipped() const
{
    return (mpRenderer != nullptr) ? mpRenderer->mpTexturedQuad->isFlipped() : false;
} // isFlipped

// Get the quad size
const CGSize AAPL::Metal::TQRenderer::size() const
{
    return (mpRenderer != nullptr) ? mpRenderer->mpTexturedQuad->size() : CGSizeMake(0.0, 0.0);
} // size

// Get the bounding view rectangle
const CGRect AAPL::Metal::TQRenderer::bounds() const
{
    return (mpRenderer != nullptr) ? mpRenderer->mpTexturedQuad->bounds() : CGRectMake(0.0, 0.0, 0.0, 0.0);
} // bounds

// Get the aspect ratio
const float AAPL::Metal::TQRenderer::aspect() const
{
    return (mpRenderer != nullptr) ? mpRenderer->mpTexturedQuad->aspect() : 0.0;
} // aspect

// Set the view bounding rectangle
void AAPL::Metal::TQRenderer::setBounds(const CGRect& bounds)
{
    if(mpRenderer != nullptr)
    {
        mpRenderer->mpTexturedQuad->setBounds(bounds);
    } // if
} // setBounds
