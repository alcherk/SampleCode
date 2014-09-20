/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 */

#import <string>
#import <unordered_map>

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#import <Metal/Metal.h>
#import <simd/simd.h>

#import "AAPLQuad.h"

static const uint32_t kCntQuadTexCoords = 6;
static const uint32_t kSzQuadTexCoords  = kCntQuadTexCoords * sizeof(simd::float2);

static const uint32_t kCntQuadVertices = kCntQuadTexCoords;
static const uint32_t kSzQuadVertices  = kCntQuadVertices * sizeof(simd::float4);

static const simd::float4 kQuadVertices[kCntQuadVertices] =
{
    { -1.0f,  -1.0f, 0.0f, 1.0f },
    {  1.0f,  -1.0f, 0.0f, 1.0f },
    { -1.0f,   1.0f, 0.0f, 1.0f },
    
    {  1.0f,  -1.0f, 0.0f, 1.0f },
    { -1.0f,   1.0f, 0.0f, 1.0f },
    {  1.0f,   1.0f, 0.0f, 1.0f }
};

static const simd::float2 kQuadTexCoords[kCntQuadTexCoords] =
{
    { 0.0f, 0.0f },
    { 1.0f, 0.0f },
    { 0.0f, 1.0f },
    
    { 1.0f, 0.0f },
    { 0.0f, 1.0f },
    { 1.0f, 1.0f }
};

namespace AAPL
{
    namespace Metal
    {
        uint8_t kQuadIndexKeyVertex   = 0;
        uint8_t kQuadIndexKeyTexCoord = 1;
        uint8_t kQuadIndexKeySampler  = 2;
        
        static const uint8_t kQuadIndexMax = 3;
        
        class QuadData
        {
        public:
            // textured Quad
            id <MTLBuffer>  m_VertexBuffer;
            id <MTLBuffer>  m_TexCoordBuffer;
            id <MTLDevice>  m_Device;
            
            // Sampler state
            id <MTLSamplerState> m_QuadSampler;
            
            // Dimensions
            CGSize  m_Size;
            CGRect  m_Bounds;
            float   mnAspect;
            
            // Scale
            simd::float2 m_Scale;
            
            // Table for indices
            NSUInteger m_Index[kQuadIndexMax];
        }; // QuadData
    } // Metal
} // AAPL

// Delete Metal Quad opaque data reference
static void AAPLMetalQuadDelete(AAPL::Metal::QuadData *pQuad)
{
    if(pQuad)
    {
        if(pQuad->m_VertexBuffer)
        {
            [pQuad->m_VertexBuffer release];
            
            pQuad->m_VertexBuffer = nil;
        } // if
        
        if(pQuad->m_TexCoordBuffer)
        {
            [pQuad->m_TexCoordBuffer release];
            
            pQuad->m_TexCoordBuffer = nil;
        } // if
        
        if(pQuad->m_QuadSampler)
        {
            [pQuad->m_QuadSampler release];
            
            pQuad->m_QuadSampler = nil;
        } // if

        if(pQuad->m_Device)
        {
            [pQuad->m_Device release];
            
            pQuad->m_Device = nil;
        } // if
        
        delete pQuad;
        
        pQuad = nullptr;
    } // if
} // AAPLMetalQuadDelete

static id <MTLSamplerState> AAPLMetalQuadCreateSampler(AAPL::Metal::QuadData *pQuad)
{
    // create a sampler for the quad
    MTLSamplerDescriptor *pSamplerDescriptor = [MTLSamplerDescriptor new];
    
    if(!pSamplerDescriptor)
    {
        NSLog(@">> ERROR: Failed creating a sampler descriptor!");
        
        return nullptr;
    } // if
    
    pSamplerDescriptor.minFilter             = MTLSamplerMinMagFilterNearest;
    pSamplerDescriptor.magFilter             = MTLSamplerMinMagFilterNearest;
    pSamplerDescriptor.mipFilter             = MTLSamplerMipFilterNotMipmapped;
    pSamplerDescriptor.maxAnisotropy         = 1.0f;
    pSamplerDescriptor.sAddressMode          = MTLSamplerAddressModeClampToEdge;
    pSamplerDescriptor.tAddressMode          = MTLSamplerAddressModeClampToEdge;
    pSamplerDescriptor.rAddressMode          = MTLSamplerAddressModeClampToEdge;
    pSamplerDescriptor.normalizedCoordinates = true;
    pSamplerDescriptor.lodMinClamp           = 0;
    pSamplerDescriptor.lodMaxClamp           = FLT_MAX;
    
    id <MTLSamplerState> sampler = [pQuad->m_Device newSamplerStateWithDescriptor:pSamplerDescriptor];
    
    [pSamplerDescriptor release];

    return sampler;
} // AAPLMetalQuadCreateSampler

// Create a default Metal quad from a valid device
static AAPL::Metal::QuadData *AAPLMetalQuadCreate(id<MTLDevice> device)
{
    AAPL::Metal::QuadData *pQuad = nullptr;
    
    try
    {
        // Catch Memory error
        pQuad = new AAPL::Metal::QuadData;
        
        if(!device)
        {
            throw @">> ERROR: Invalid Metal device!";
        } // if
        
        pQuad->m_Device = [device retain];
        
        pQuad->m_VertexBuffer = [pQuad->m_Device newBufferWithBytes:kQuadVertices
                                                             length:kSzQuadVertices
                                                            options:MTLResourceOptionCPUCacheModeDefault];
        
        if(!pQuad->m_VertexBuffer)
        {
            throw @">> ERROR: Failed creating a vertex buffer for a quad!";
        } // if
        
        pQuad->m_TexCoordBuffer = [pQuad->m_Device newBufferWithBytes:kQuadTexCoords
                                                               length:kSzQuadTexCoords
                                                              options:MTLResourceOptionCPUCacheModeDefault];
        
        if(!pQuad->m_TexCoordBuffer)
        {
            throw @">> ERROR: Failed creating a 2d texture coordinate buffer!";
        } // if
        
        pQuad->m_QuadSampler = AAPLMetalQuadCreateSampler(pQuad);
        
        if(!pQuad->m_QuadSampler)
        {
            throw @">> ERROR: Failed creating a quad sampler!";
        } // if
        
        // Dimensions
        pQuad->m_Size   = CGSizeMake(0.0, 0.0);
        pQuad->m_Bounds = CGRectMake(0.0, 0.0, 0.0, 0.0);
        pQuad->mnAspect = 1.0f;
        pQuad->m_Scale  = 1.0f;
        
        pQuad->m_Index[AAPL::Metal::kQuadIndexKeyVertex]   = 0;
        pQuad->m_Index[AAPL::Metal::kQuadIndexKeyTexCoord] = 1;
        pQuad->m_Index[AAPL::Metal::kQuadIndexKeySampler]  = 0;
    } // Constructor
    catch(std::bad_alloc& ba)
    {
        NSLog(@">> ERROR: Failed allocating memory for the quad data store: \"%s\"", ba.what());
    } // catch
    catch(NSString *pString)
    {
        AAPLMetalQuadDelete(pQuad);
        
        NSLog(@">> ERROR: %@", pString);
    } // catch
    
    return pQuad;
} // AAPLMetalQuadCreate

// Create a copy of Metal quad from a valid source
static AAPL::Metal::QuadData *AAPLMetalQuadCreateCopy(const AAPL::Metal::QuadData * const pQuadSrc)
{
    AAPL::Metal::QuadData *pQuadDst = nullptr;
    
    try
    {
        // Catch Memory error
        pQuadDst = new AAPL::Metal::QuadData;
        
        std::memset(pQuadDst, 0x0, sizeof(AAPL::Metal::QuadData));
        
        if(!pQuadSrc)
        {
            throw @">> ERROR: Invalid source quad!";
        } // if
        
        if(!pQuadSrc->m_Device)
        {
            throw @">> ERROR: Invalid source Metal device!";
        } // if
        
        pQuadDst->m_Device = [pQuadSrc->m_Device retain];
        
        simd::float4 *pVerticesSrc = (simd::float4 *)[pQuadSrc->m_VertexBuffer contents];
        
        if(!pVerticesSrc)
        {
            throw @">> ERROR: Invalid source vertices!";
        } // if
        
        pQuadDst->m_VertexBuffer = [pQuadDst->m_Device newBufferWithBytes:pVerticesSrc
                                                                   length:kSzQuadVertices
                                                                  options:MTLResourceOptionCPUCacheModeDefault];
        
        if(!pQuadDst->m_VertexBuffer)
        {
            throw @">> ERROR: Failed creating a vertex buffer copy!";
        } // if
        
        simd::float2 *pTexCoordsSrc = (simd::float2 *)[pQuadSrc->m_TexCoordBuffer contents];

        if(!pTexCoordsSrc)
        {
            throw @">> ERROR: Invalid source texture coordinates!";
        } // if
        
        pQuadDst->m_TexCoordBuffer = [pQuadDst->m_Device newBufferWithBytes:pTexCoordsSrc
                                                                     length:kSzQuadTexCoords
                                                                    options:MTLResourceOptionCPUCacheModeDefault];
        
        if(!pQuadDst->m_TexCoordBuffer)
        {
            throw @">> ERROR: Failed creating a 2d texture coordinate buffer copy!";
        } // if
        
        pQuadDst->m_QuadSampler = AAPLMetalQuadCreateSampler(pQuadDst);
        
        if(!pQuadDst->m_QuadSampler)
        {
            throw @">> ERROR: Failed creating a quad sampler!";
        } // if
        
        pQuadDst->m_Size   = pQuadSrc->m_Size;
        pQuadDst->m_Bounds = pQuadSrc->m_Bounds;
        pQuadDst->mnAspect = pQuadSrc->mnAspect;
        pQuadDst->m_Scale  = pQuadSrc->m_Scale;
       
        pQuadDst->m_Index[AAPL::Metal::kQuadIndexKeyVertex]   = pQuadSrc->m_Index[AAPL::Metal::kQuadIndexKeyVertex];
        pQuadDst->m_Index[AAPL::Metal::kQuadIndexKeyTexCoord] = pQuadSrc->m_Index[AAPL::Metal::kQuadIndexKeyTexCoord];
        pQuadDst->m_Index[AAPL::Metal::kQuadIndexKeySampler]  = pQuadSrc->m_Index[AAPL::Metal::kQuadIndexKeySampler];
    } // Constructor
    catch(std::bad_alloc& ba)
    {
        NSLog(@">> ERROR: Failed allocating memory for the quad data store: \"%s\"", ba.what());
    } // catch
    catch(NSString *pString)
    {
        AAPLMetalQuadDelete(pQuadDst);
        
        NSLog(@">> ERROR: %@", pString);
    } // catch
    
    return pQuadDst;
} // AAPLMetalQuadCreateCopy

static void AAPLMetalQuadSetBounds(const CGRect& bounds,
                                   AAPL::Metal::QuadData *pQuad)
{
    if(!CGRectIsEmpty(bounds))
    {
        pQuad->m_Bounds = bounds;
        pQuad->mnAspect = fabsf(pQuad->m_Bounds.size.width / pQuad->m_Bounds.size.height);
        
        float         aspect = 1.0f/pQuad->mnAspect;
        simd::float2  scale  = 0.0f;
        
        scale.x = aspect * pQuad->m_Size.width / pQuad->m_Bounds.size.width;
        scale.y = pQuad->m_Size.height / pQuad->m_Bounds.size.height;
        
        // Did the scaling factor change
        BOOL bNewScale = (scale.x != pQuad->m_Scale.x) || (scale.y != pQuad->m_Scale.y);
        
        // Set the (x,y) bounds of the quad
        if(bNewScale)
        {
            // Update the scaling factor
            pQuad->m_Scale = scale;
            
            // Update the vertex buffer with the quad bounds
            simd::float4 *pVertices = (simd::float4 *)[pQuad->m_VertexBuffer contents];
            
            if(pVertices != nullptr)
            {
                // First triangle
                pVertices[0].x = -pQuad->m_Scale.x;
                pVertices[0].y = -pQuad->m_Scale.y;
                
                pVertices[1].x =  pQuad->m_Scale.x;
                pVertices[1].y = -pQuad->m_Scale.y;
                
                pVertices[2].x = -pQuad->m_Scale.x;
                pVertices[2].y =  pQuad->m_Scale.y;
                
                // Second triangle
                pVertices[3].x =  pQuad->m_Scale.x;
                pVertices[3].y = -pQuad->m_Scale.y;
                
                pVertices[4].x = -pQuad->m_Scale.x;
                pVertices[4].y =  pQuad->m_Scale.y;
                
                pVertices[5].x =  pQuad->m_Scale.x;
                pVertices[5].y =  pQuad->m_Scale.y;
            } // if
        } // if
    } // if
} // setBounds

static void AAPLMetalQuadEncode(id <MTLRenderCommandEncoder> renderEncoder,
                                AAPL::Metal::QuadData *pQuad)
{
    if(renderEncoder)
    {
        [renderEncoder setFragmentSamplerState:pQuad->m_QuadSampler
                                       atIndex:pQuad->m_Index[AAPL::Metal::kQuadIndexKeySampler]];
        
        [renderEncoder setVertexBuffer:pQuad->m_VertexBuffer
                                offset:0
                               atIndex:pQuad->m_Index[AAPL::Metal::kQuadIndexKeyVertex] ];
        
        [renderEncoder setVertexBuffer:pQuad->m_TexCoordBuffer
                                offset:0
                               atIndex:pQuad->m_Index[AAPL::Metal::kQuadIndexKeyTexCoord] ];
    } // if
} // encode

// Constructor
AAPL::Metal::Quad::Quad(id<MTLDevice> device)
{
    mpQuad = AAPLMetalQuadCreate(device);
} // Constructor

// Copy Constructor
AAPL::Metal::Quad::Quad(const AAPL::Metal::Quad& rQuad)
{
    AAPL::Metal::QuadData *pQuad = AAPLMetalQuadCreateCopy(rQuad.mpQuad);
    
    if(pQuad != nullptr)
    {
        AAPLMetalQuadDelete(mpQuad);
        
        mpQuad = pQuad;
    } // if
} // Copy Constructor

// Assignment operator
AAPL::Metal::Quad& AAPL::Metal::Quad::operator=(const AAPL::Metal::Quad& rQuad)
{
    if(this != &rQuad)
    {
        AAPL::Metal::QuadData *pQuad = AAPLMetalQuadCreateCopy(rQuad.mpQuad);
        
        if(pQuad != nullptr)
        {
            AAPLMetalQuadDelete(mpQuad);
            
            mpQuad = pQuad;
        } // if
    } // if
    
    return *this;
} // Assignment operator

// Destructor
AAPL::Metal::Quad::~Quad()
{
    AAPLMetalQuadDelete(mpQuad);
} // Destructor

// Get the texture size
const CGSize AAPL::Metal::Quad::size() const
{
    return (mpQuad != nullptr) ? mpQuad->m_Size : CGSizeMake(0.0, 0.0);
} // size

// Get the bounding view rectangle
const CGRect AAPL::Metal::Quad::bounds() const
{
    return (mpQuad != nullptr) ? mpQuad->m_Bounds : CGRectMake(0.0, 0.0, 0.0, 0.0);
} // bounds

// Get the aspect ratio
const float AAPL::Metal::Quad::aspect() const
{
    return (mpQuad != nullptr) ? mpQuad->mnAspect : 0.0f;
} // aspect

// Get the vertex, texture coordinate or sampler index
const NSUInteger AAPL::Metal::Quad::index(const uint8_t& key) const
{
    return ((mpQuad != nullptr) && (key < AAPL::Metal::kQuadIndexMax)) ? mpQuad->m_Index[key] : 0;
} // index

// Set vertex, texture coordinate, or sample indices.
//
// (1) For the vertex index this is optional. The default
//     for vertex index is 0.
//
// (2) For the texture coordinate index this is optional.
//     The default for texture coordinate is 1.
//
// (3) For the sample index this is optional. The default
//     for samples index is 0.
//
// The key for setting indices are listed above.
void AAPL::Metal::Quad::setIndex(const uint8_t& key,
                                 const NSUInteger& value)
{
    if((mpQuad != nullptr) && (key < AAPL::Metal::kQuadIndexMax))
    {
        mpQuad->m_Index[key] = value;
    } // if
} // setIndex

// Set the quad size
void AAPL::Metal::Quad::setSize(const CGSize& size)
{
    if((mpQuad != nullptr) && (size.width > 0.0) && (size.height > 0.0))
    {
        mpQuad->m_Size = size;
    } // if
} // setSize

// Set the view bounding rectangle
void AAPL::Metal::Quad::setBounds(const CGRect& bounds)
{
    if(mpQuad != nullptr)
    {
        AAPLMetalQuadSetBounds(bounds, mpQuad);
    } // if
} // setBounds

// Encode a quad using a render encoder
void AAPL::Metal::Quad::encode(id<MTLRenderCommandEncoder> renderEncoder)
{
    if(mpQuad != nullptr)
    {
        AAPLMetalQuadEncode(renderEncoder, mpQuad);
    } // if
} // encode
