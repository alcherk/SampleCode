/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 */

#import <Metal/Metal.h>

#import "AAPLQTransform.h"
#import "AAPLTexture.h"
#import "AAPLQuad.h"

#import "AAPLTexturedQuad.h"

static const uint32_t kSzSIMDFloat4x4        = sizeof(simd::float4x4);
static const uint32_t kSzBufferLimitPerFrame = kSzSIMDFloat4x4;

class AAPL::Metal::TexturedQuadData
{
public:
    // Interface Orientation
    UIInterfaceOrientation  mnOrientation;
    
    // Renderer globals
    id <MTLDevice>   m_Device;
    id <MTLLibrary>  m_ShaderLibrary;
    
    // textured Quad
    AAPL::Metal::Texture          *mpInTexture;
    id <MTLRenderPipelineState>    m_PipelineState;
    
    // Shaders
    id <MTLFunction> m_FragProg;
    id <MTLFunction> m_VertProg;
    
    // Quad representation
    AAPL::Metal::Quad *mpQuad;
    
    // Dimensions
    CGSize  m_Size;
    
    // Quad transform buffers
    AAPL::Metal::QTransform  m_Transform;
    id <MTLBuffer>           m_TransformBuffer;
};

typedef AAPL::Metal::TexturedQuadData   AAPLMetalTQData;
typedef AAPLMetalTQData                *AAPLMetalTQDataRef;

static void AAPLMetalTexturedQuadDeleteTexture(AAPLMetalTQDataRef pTexturedQuad)
{
    if(pTexturedQuad->mpInTexture)
    {
        delete pTexturedQuad->mpInTexture;
        
        pTexturedQuad->mpInTexture = nullptr;
    } // if
} // AAPLMetalTexturedQuadDeleteTexture

static void AAPLMetalTexturedQuadDeleteQuad(AAPLMetalTQDataRef pTexturedQuad)
{
    if(pTexturedQuad->mpQuad)
    {
        delete pTexturedQuad->mpQuad;
        
        pTexturedQuad->mpQuad = nullptr;
    } // if
} // AAPLMetalTexturedQuadDeleteQuad

static void AAPLMetalTexturedQuadReleasePipelineState(AAPLMetalTQDataRef pTexturedQuad)
{
    if(pTexturedQuad->m_PipelineState)
    {
        [pTexturedQuad->m_PipelineState release];
        
        pTexturedQuad->m_PipelineState = nil;
    } // if
} // AAPLMetalTexturedQuadReleasePipelineState

static void AAPLMetalTexturedQuadReleaseShaderLibrary(AAPLMetalTQDataRef pTexturedQuad)
{
    if(pTexturedQuad->m_ShaderLibrary)
    {
        [pTexturedQuad->m_ShaderLibrary release];
        
        pTexturedQuad->m_ShaderLibrary = nil;
    } // if
} // AAPLMetalTexturedQuadReleaseShaderLibrary

static void AAPLMetalTexturedQuadReleaseTransformBuffer(AAPLMetalTQDataRef pTexturedQuad)
{
    if(pTexturedQuad->m_TransformBuffer)
    {
        [pTexturedQuad->m_TransformBuffer release];
        
        pTexturedQuad->m_TransformBuffer = nil;
    } // if
} // AAPLMetalTexturedQuadReleaseTransformBuffer

static void AAPLMetalTexturedQuadReleaseDevice(AAPLMetalTQDataRef pTexturedQuad)
{
    if(pTexturedQuad->m_Device)
    {
        [pTexturedQuad->m_Device release];
        
        pTexturedQuad->m_Device = nil;
    } // if
} // AAPLMetalTexturedQuadReleaseDevice

static void AAPLMetalTexturedQuadDelete(AAPLMetalTQDataRef pTexturedQuad)
{
    if(pTexturedQuad != nullptr)
    {
        // Release Metal framework resources
        AAPLMetalTexturedQuadReleasePipelineState(pTexturedQuad);
        AAPLMetalTexturedQuadReleaseShaderLibrary(pTexturedQuad);
        AAPLMetalTexturedQuadReleaseTransformBuffer(pTexturedQuad);
        AAPLMetalTexturedQuadReleaseDevice(pTexturedQuad);
        
        // Delete renderer objects
        AAPLMetalTexturedQuadDeleteTexture(pTexturedQuad);
        AAPLMetalTexturedQuadDeleteQuad(pTexturedQuad);
        
        // Delete the renderer object
        delete pTexturedQuad;
        
        pTexturedQuad = nullptr;
    } // if
} // AAPLMetalTexturedQuadDelete

static bool AAPLMetalTexturedQuadAcquireLibrary(AAPLMetalTQDataRef pTexturedQuad)
{
    pTexturedQuad->m_ShaderLibrary = [pTexturedQuad->m_Device newDefaultLibrary];
    
    if(!pTexturedQuad->m_ShaderLibrary)
    {
        NSLog(@">> ERROR: Failed creating a shared library!");
        
        return false;
    } // if
    
    // load the fragment program into the library
    pTexturedQuad->m_FragProg = [pTexturedQuad->m_ShaderLibrary newFunctionWithName:@"texturedQuadFragment"];
    
    if(!pTexturedQuad->m_FragProg)
    {
        NSLog(@">> ERROR: Failed creating a fragment shader!");
        
        [pTexturedQuad->m_ShaderLibrary release];
        
        return false;
    } // if
    
    // load the vertex program into the library
    pTexturedQuad->m_VertProg = [pTexturedQuad->m_ShaderLibrary newFunctionWithName:@"texturedQuadVertex"];
    
    if(!pTexturedQuad->m_VertProg)
    {
        NSLog(@">> ERROR: Failed creating a vertex shader!");
        
        [pTexturedQuad->m_FragProg       release];
        [pTexturedQuad->m_ShaderLibrary  release];
        
        return false;
    } // if
    
    return true;
} // AAPLMetalTexturedQuadAcquireLibrary

static bool AAPLMetalTexturedQuadAcquirePipelineState(AAPLMetalTQDataRef pTexturedQuad)
{
    //  create a pipeline state for the quad
    MTLRenderPipelineDescriptor *pQuadPipelineStateDescriptor = [MTLRenderPipelineDescriptor new];
    
    if(!pQuadPipelineStateDescriptor)
    {
        NSLog(@">> ERROR: Failed creating a pipeline state descriptor!");
        
        [pTexturedQuad->m_VertProg       release];
        [pTexturedQuad->m_FragProg       release];
        [pTexturedQuad->m_ShaderLibrary  release];
        
        return false;
    } // if
    
    pQuadPipelineStateDescriptor.depthAttachmentPixelFormat      = MTLPixelFormatInvalid;
    pQuadPipelineStateDescriptor.stencilAttachmentPixelFormat    = MTLPixelFormatInvalid;
    pQuadPipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    pQuadPipelineStateDescriptor.sampleCount      = 1;
    pQuadPipelineStateDescriptor.vertexFunction   = pTexturedQuad->m_VertProg;
    pQuadPipelineStateDescriptor.fragmentFunction = pTexturedQuad->m_FragProg;
    
    NSError *pError = nil;
    
    pTexturedQuad->m_PipelineState
    = [pTexturedQuad->m_Device newRenderPipelineStateWithDescriptor:pQuadPipelineStateDescriptor
                                                              error:&pError];
    
    [pQuadPipelineStateDescriptor release];
    
    [pTexturedQuad->m_VertProg release];
    [pTexturedQuad->m_FragProg release];
    
    if(!pTexturedQuad->m_PipelineState)
    {
        if(pError)
        {
            NSLog(@">> ERROR: Failed acquiring pipeline state descriptor: %@", pError);
            
            [pError release];
        } // if
        else
        {
            NSLog(@">> ERROR: Failed acquiring pipeline state descriptor!");
        } // else
        
        return false;
    } // if
    
    return true;
} // AAPLMetalTexturedQuadAcquirePipelineState

static bool AAPLMetalTexturedQuadAcquireQuad(AAPLMetalTQDataRef pTexturedQuad)
{
    try
    {
        // Catch Memory error
        pTexturedQuad->mpQuad = new AAPL::Metal::Quad(pTexturedQuad->m_Device);
    } // try
    catch(std::bad_alloc& ba)
    {
        NSLog(@">> ERROR: Failed creating a backing-store for a quad: \"%s\"", ba.what());
        
        return false;
    } // catch
    
    return true;
} // AAPLMetalTexturedQuadAcquireQuad

static bool AAPLMetalTexturedQuadAcquireTransformBuffer(AAPLMetalTQDataRef pTexturedQuad)
{
    // allocate regions of memory for the constant buffer
    pTexturedQuad->m_TransformBuffer = [pTexturedQuad->m_Device newBufferWithLength:kSzBufferLimitPerFrame
                                                                            options:0];
    
    if(!pTexturedQuad->m_TransformBuffer)
    {
        return false;
    } // if
    
    pTexturedQuad->m_TransformBuffer.label = @"TransformBuffer";
    
    return true;
} // AAPLMetalTexturedQuadAcquireTransformBuffer

static bool AAPLMetalTexturedQuadPrepareTexturedQuad(AAPL::Metal::TexturedQuadData *pTexturedQuad)
{
    if(!AAPLMetalTexturedQuadAcquireLibrary(pTexturedQuad))
    {
        NSLog(@">> ERROR: Failed creating a Metal library!");
        
        return false;
    } // if
    
    if(!AAPLMetalTexturedQuadAcquirePipelineState(pTexturedQuad))
    {
        NSLog(@">> ERROR: Failed creating a depth stencil state descriptor!");
        
        return false;
    } // if
    
    if(!AAPLMetalTexturedQuadAcquireTransformBuffer(pTexturedQuad))
    {
        NSLog(@">> ERROR: Failed creating a transform buffer!");
        
        return false;
    } // if
    
    if(!AAPLMetalTexturedQuadAcquireQuad(pTexturedQuad))
    {
        NSLog(@">> ERROR: Failed creating a quad!");
        
        return false;
    } // if
    
    return true;
} // AAPLMetalTexturedQuadPrepareTexturedQuad

static bool AAPLMetalTexturedQuadAcquireTexture(const std::string& path,
                                                AAPLMetalTQDataRef pTexturedQuad)
{
    try
    {
        // Catch Memory error
        pTexturedQuad->mpInTexture = new AAPL::Metal::Texture(path);
        
        if(!pTexturedQuad->mpInTexture->finalize(pTexturedQuad->m_Device))
        {
            throw @">> ERROR: Failed finalizing a 2d texture!";
        } // if
        
        pTexturedQuad->m_Size.width  = pTexturedQuad->mpInTexture->width();
        pTexturedQuad->m_Size.height = pTexturedQuad->mpInTexture->height();
        
        pTexturedQuad->mpQuad->setSize(pTexturedQuad->m_Size);
    } // try
    catch(std::bad_alloc& ba)
    {
        NSLog(@">> ERROR: Failed creating a backing-store for a 2d texture from an %s image: \"%s\"",
              path.c_str(),
              ba.what());
    } // catch
    catch(NSString *pString)
    {
        NSLog(@">> ERROR: %@", pString);
    } // catch
    
    return true;
} // AAPLMetalTexturedQuadAcquireTexture

static bool AAPLMetalTexturedQuadAcquireTexture(const std::string& name,
                                                const std::string& ext,
                                                AAPLMetalTQDataRef pTexturedQuad)
{
    try
    {
        // Catch Memory error
        pTexturedQuad->mpInTexture = new AAPL::Metal::Texture(name, ext);
        
        if(!pTexturedQuad->mpInTexture->finalize(pTexturedQuad->m_Device))
        {
            throw @">> ERROR: Failed finalizing a 2d texture!";
        } // if
        
        pTexturedQuad->m_Size.width  = pTexturedQuad->mpInTexture->width();
        pTexturedQuad->m_Size.height = pTexturedQuad->mpInTexture->height();
        
        pTexturedQuad->mpQuad->setSize(pTexturedQuad->m_Size);
    } // try
    catch(std::bad_alloc& ba)
    {
        NSLog(@">> ERROR: Failed creating a backing-store for a 2d texture from an image %s.%s in app bundle: \"%s\"",
              name.c_str(),
              ext.c_str(),
              ba.what());
        
        return false;
    } // catch
    catch(NSString *pString)
    {
        NSLog(@">> ERROR: %@", pString);
    } // catch
    
    return true;
} // AAPLMetalTexturedQuadAcquireTexture

static AAPL::Metal::TexturedQuadData *AAPLMetalTexturedQuadCreate(id <MTLDevice> device)
{
    AAPLMetalTQDataRef pTexturedQuad = nullptr;
    
    if(device)
    {
        try
        {
            // Catch Memory error
            pTexturedQuad = new AAPL::Metal::TexturedQuadData;
            
            pTexturedQuad->mnOrientation = UIInterfaceOrientationUnknown;
            pTexturedQuad->m_Device      = [device retain];
            
            pTexturedQuad->m_ShaderLibrary   = nil;
            pTexturedQuad->m_PipelineState   = nil;
            pTexturedQuad->m_FragProg        = nil;
            pTexturedQuad->m_VertProg        = nil;
            pTexturedQuad->m_TransformBuffer = nil;
            
            pTexturedQuad->mpInTexture = nullptr;
            pTexturedQuad->mpQuad      = nullptr;
            
            pTexturedQuad->m_Size = CGSizeMake(0.0, 0.0);
        } // try
        catch(std::bad_alloc& ba)
        {
            NSLog(@">> ERROR: Failed creating a backing-store for a textured quad: \"%s\"", ba.what());
        } // catch
    } // if
    
    return pTexturedQuad;
} // AAPLMetalTexturedQuadCreate

static AAPLMetalTQDataRef AAPLMetalTexturedQuadCreate(const std::string& path,
                                                      id <MTLDevice> device)
{
    AAPLMetalTQDataRef pTexturedQuad = AAPLMetalTexturedQuadCreate(device);
    
    if(pTexturedQuad != nullptr)
    {
        try
        {
            if(!AAPLMetalTexturedQuadPrepareTexturedQuad(pTexturedQuad))
            {
                throw @"Failed preparing a textured quad";
            } // if
            
            if(!AAPLMetalTexturedQuadAcquireTexture(path, pTexturedQuad))
            {
                throw @"Failed acquring a textured quad from an image at path";
            } // if
        } // try
        catch (NSString *pString)
        {
            NSLog(@">> ERROR: %@!",pString);
            
            AAPLMetalTexturedQuadDelete(pTexturedQuad);
        } // catch
    } // if
    
    return pTexturedQuad;
} // AAPLMetalTexturedQuadCreate

static AAPLMetalTQDataRef AAPLMetalTexturedQuadCreate(const std::string& name,
                                                      const std::string& ext,
                                                      id <MTLDevice> device)
{
    AAPLMetalTQDataRef pTexturedQuad = AAPLMetalTexturedQuadCreate(device);
    
    if(pTexturedQuad != nullptr)
    {
        try
        {
            if(!AAPLMetalTexturedQuadPrepareTexturedQuad(pTexturedQuad))
            {
                throw @"Failed preparing a textured quad";
            } // if
            
            const std::string rsrc_name = (!name.empty()) ? name : "Default";
            const std::string rsrc_ext  = (!ext.empty())  ? ext  : "jpg";
            
            if(!AAPLMetalTexturedQuadAcquireTexture(rsrc_name, rsrc_ext, pTexturedQuad))
            {
                throw @"Failed acquring a textured quad from an image in application bundle";
            } // if
        } // try
        catch (NSString *pString)
        {
            NSLog(@">> ERROR: %@!",pString);
            
            AAPLMetalTexturedQuadDelete(pTexturedQuad);
        } // catch
    } // if
    
    return pTexturedQuad;
} // AAPLMetalTexturedQuadFinalize

static bool AAPLMetalTexturedCopyTransformBuffer(const AAPLMetalTQData * const pTexturedQuadSrc,
                                                 AAPLMetalTQDataRef pTexturedQuadDst)
{
    simd::float4 *pTransformBufferSrc = nullptr;
    
    if(pTexturedQuadSrc->m_TransformBuffer)
    {
        pTransformBufferSrc = (simd::float4 *)[pTexturedQuadSrc->m_TransformBuffer contents];
    } // if
    
    if(pTransformBufferSrc != nullptr)
    {
        pTexturedQuadDst->m_TransformBuffer
        = [pTexturedQuadDst->m_Device newBufferWithBytes:pTransformBufferSrc
                                                  length:kSzBufferLimitPerFrame
                                                 options:MTLResourceOptionCPUCacheModeDefault];
        
        if(!pTexturedQuadDst->m_TransformBuffer)
        {
            return false;
        } // if
        
        pTexturedQuadDst->m_TransformBuffer.label = @"TransformBufferCopy";
    } // if
    else
    {
        AAPLMetalTexturedQuadAcquireTransformBuffer(pTexturedQuadDst);
    } // else
    
    return true;
} // AAPLMetalTexturedCopyTransformBuffer

static AAPLMetalTQDataRef AAPLMetalTexturedQuadCreateCopy(const AAPLMetalTQData * const pTexturedQuadSrc)
{
    AAPLMetalTQDataRef pTexturedQuadDst = nullptr;
    
    if(pTexturedQuadSrc != nullptr)
    {
        pTexturedQuadDst = AAPLMetalTexturedQuadCreate(pTexturedQuadSrc->m_Device);
        
        if(pTexturedQuadDst != nullptr)
        {
            pTexturedQuadDst->mnOrientation = pTexturedQuadSrc->mnOrientation;
            pTexturedQuadDst->mpInTexture   = pTexturedQuadSrc->mpInTexture;
            pTexturedQuadDst->mpInTexture   = pTexturedQuadSrc->mpInTexture;
            pTexturedQuadDst->mpQuad        = pTexturedQuadSrc->mpQuad;
            pTexturedQuadDst->m_Size        = pTexturedQuadSrc->m_Size;
            pTexturedQuadDst->m_Transform   = pTexturedQuadSrc->m_Transform;
            
            try
            {
                if(!AAPLMetalTexturedQuadAcquireLibrary(pTexturedQuadDst))
                {
                    throw @">> ERROR: Failed copying the Metal library for a textured quad!";
                } // if
                
                if(!AAPLMetalTexturedQuadAcquirePipelineState(pTexturedQuadDst))
                {
                    throw @">> ERROR: Failed copying the depth stencil state descriptor for a textured quad!";
                } // if
                
                if(!AAPLMetalTexturedCopyTransformBuffer(pTexturedQuadSrc, pTexturedQuadDst))
                {
                    throw @">> ERROR: Failed copying the depth stencil state descriptor for a textured quad!";
                } // if
            } // try
            catch(NSString *pString)
            {
                NSLog(@">> ERROR: %@!",pString);
                
                AAPLMetalTexturedQuadDelete(pTexturedQuadDst);
            } // catch
        } // if
    } // if
    
    return pTexturedQuadDst;
} // AAPLMetalTexturedQuadCreateCopy

static void AAPLMetalTexturedQuadUpdate(const CGRect& frame,
                                        AAPLMetalTQDataRef pTexturedQuad)
{
    // To correctly compute the aspect ration determine the device
    // interface orientation.
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    // Update the quad and linear _transformation matrices, if and
    // only if, the device orientation is changed.
    if(pTexturedQuad->mnOrientation != orientation)
    {
        // Update the device orientation
        pTexturedQuad->mnOrientation = orientation;
        
        // Get the bounds for the current rendering layer
        pTexturedQuad->mpQuad->setBounds(frame);
        
        // Set the device orientation
        pTexturedQuad->m_Transform.setOrientation(pTexturedQuad->mnOrientation);
        
        // Get the aspect ratio
        const float aspect = pTexturedQuad->mpQuad->aspect();
        
        // Create a mvp linear transformation matrix
        simd::float4x4  mvp = pTexturedQuad->m_Transform(aspect);
        
        // Update the buffer associated with the linear _transformation matrix
        float *pTransform = (float *)[pTexturedQuad->m_TransformBuffer contents];
        
        // Copy the mvp linear transformation into the transform buffer
        std::memcpy(pTransform, &mvp, kSzSIMDFloat4x4);
    } // if
} // AAPLMetalTexturedQuadUpdate

static void AAPLMetalTexturedQuadEncode(id <MTLRenderCommandEncoder> renderEncoder,
                                        AAPLMetalTQDataRef pTexturedQuad)
{
    if(renderEncoder)
    {
        [renderEncoder setRenderPipelineState:pTexturedQuad->m_PipelineState];
        
        [renderEncoder setVertexBuffer:pTexturedQuad->m_TransformBuffer
                                offset:0
                               atIndex:2 ];
        
        [renderEncoder setFragmentTexture:pTexturedQuad->mpInTexture->texture()
                                  atIndex:0];
        
        // Encode quad vertex and texture coordinate buffers
        pTexturedQuad->mpQuad->encode(renderEncoder);
    } // if
} // AAPLMetalTexturedQuadEncode

// Construct a textured quad with an image at application boundle.
// Use "Default" the image name  and "jpg" as the file's extension.
AAPL::Metal::TexturedQuad::TexturedQuad(id <MTLDevice> device)
{
    mpTexturedQuad = AAPLMetalTexturedQuadCreate("Default", "jpg", device);
} // Constructor

// Construct a textured quad with an image at an absolute path.
// If the path is an empty string finalize will fail.
AAPL::Metal::TexturedQuad::TexturedQuad(const std::string& path,
                                        id <MTLDevice> device)
{
    mpTexturedQuad = AAPLMetalTexturedQuadCreate(path, device);
} // Constructor

// Construct a textured quad with an image at application boundle.
// If name is an empty string use "Default" as name.  If the ext
// is an empty string use "jpg" as the file's extension.
AAPL::Metal::TexturedQuad::TexturedQuad(const std::string& name,
                                        const std::string& ext,
                                        id <MTLDevice> device)
{
    mpTexturedQuad = AAPLMetalTexturedQuadCreate(name, ext, device);
} // Constructor

// Copy Constructor
AAPL::Metal::TexturedQuad::TexturedQuad(const AAPL::Metal::TexturedQuad& rTexturedQuad)
{
    AAPLMetalTQDataRef pTexturedQuad = AAPLMetalTexturedQuadCreateCopy(rTexturedQuad.mpTexturedQuad);
    
    if(pTexturedQuad != nullptr)
    {
        AAPLMetalTexturedQuadDelete(mpTexturedQuad);
        
        mpTexturedQuad = pTexturedQuad;
    } // if
} // Copy Constructor

// Assignment operator
AAPL::Metal::TexturedQuad& AAPL::Metal::TexturedQuad::operator=(const AAPL::Metal::TexturedQuad& rTexturedQuad)
{
    if(this != &rTexturedQuad)
    {
        AAPLMetalTQDataRef pTexturedQuad = AAPLMetalTexturedQuadCreateCopy(rTexturedQuad.mpTexturedQuad);
        
        if(pTexturedQuad != nullptr)
        {
            AAPLMetalTexturedQuadDelete(mpTexturedQuad);
            
            mpTexturedQuad = pTexturedQuad;
        } // if
    } // if
    
    return *this;
} // Assignment operator

// Delete the rendxerer object
AAPL::Metal::TexturedQuad::~TexturedQuad()
{
    AAPLMetalTexturedQuadDelete(mpTexturedQuad);
} // Destructor

// Update the linear transformations of a textured quad
void AAPL::Metal::TexturedQuad::update(const CGRect& frame)
{
    if(mpTexturedQuad != nullptr)
    {
        AAPLMetalTexturedQuadUpdate(frame, mpTexturedQuad);
    } // if
} // update

// Encode a textured quad
void AAPL::Metal::TexturedQuad::encode(id <MTLRenderCommandEncoder> renderEncoder)
{
    if(mpTexturedQuad != nullptr)
    {
        AAPLMetalTexturedQuadEncode(renderEncoder, mpTexturedQuad);
    } // if
} // encode

// Get the texture target
const MTLTextureType AAPL::Metal::TexturedQuad::target() const
{
    return (mpTexturedQuad != nullptr) ? mpTexturedQuad->mpInTexture->target() : MTLTextureType(0);
} // target

// Get the texture width
const uint32_t AAPL::Metal::TexturedQuad::width() const
{
    return (mpTexturedQuad != nullptr) ? mpTexturedQuad->mpInTexture->width() : 0;
} // width

// Get the texture height
const uint32_t AAPL::Metal::TexturedQuad::height() const
{
    return (mpTexturedQuad != nullptr) ? mpTexturedQuad->mpInTexture->height() : 0;
} // height

// Get the texture depth
const uint32_t AAPL::Metal::TexturedQuad::depth() const
{
    return (mpTexturedQuad != nullptr) ? mpTexturedQuad->mpInTexture->depth() : 0;
} // depth

// Get the texture format
const uint32_t AAPL::Metal::TexturedQuad::format() const
{
    return (mpTexturedQuad != nullptr) ? mpTexturedQuad->mpInTexture->format() : 0;
} // format

// Querey:  Is the image vertically reflected?
const bool AAPL::Metal::TexturedQuad::isFlipped() const
{
    return (mpTexturedQuad != nullptr) ? mpTexturedQuad->mpInTexture->isFlipped() : false;
} // isFlipped

// Get the quad size
const CGSize AAPL::Metal::TexturedQuad::size() const
{
    return (mpTexturedQuad != nullptr) ? mpTexturedQuad->mpQuad->size() : CGSizeMake(0.0, 0.0);
} // size

// Get the bounding view rectangle
const CGRect AAPL::Metal::TexturedQuad::bounds() const
{
    return (mpTexturedQuad != nullptr) ? mpTexturedQuad->mpQuad->bounds() : CGRectMake(0.0, 0.0, 0.0, 0.0);
} // bounds

// Get the aspect ratio
const float AAPL::Metal::TexturedQuad::aspect() const
{
    return (mpTexturedQuad != nullptr) ? mpTexturedQuad->mpQuad->aspect() : 0.0;
} // aspect

// Set the view bounding rectangle
void AAPL::Metal::TexturedQuad::setBounds(const CGRect& bounds)
{
    if(mpTexturedQuad != nullptr)
    {
        mpTexturedQuad->mpQuad->setBounds(bounds);
    } // if
} // setBounds
