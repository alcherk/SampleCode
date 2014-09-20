/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 */

#import <cstdlib>

#import <UIKit/UIKit.h>

#import "AAPLTexture.h"

class AAPL::Metal::TextureData
{
public:
    MTLTextureType  mnTarget;
    uint32_t        mnWidth;
    uint32_t        mnHeight;
    uint32_t        mnDepth;
    uint32_t        mnFormat;
    bool            mbFlip;
    id<MTLTexture>  m_Texture;
    id<MTLDevice>   m_Device;
    NSString       *mpPath;
};

// Create a copy of a c-string
static NSString *NSStringCreateCopy(const std::string& str)
{
    NSString *pString = nil;
    
    if(!str.empty())
    {
        pString = [[NSString alloc] initWithCString:str.c_str() encoding:NSASCIIStringEncoding];
    } // if
    
    return pString;
} // NSStringCreateCopy

// Create a copy of a NSString
static NSString *NSStringCreateCopy(NSString *pStrSrc)
{
    NSString *pStrDst = nil;
    
    if(pStrSrc)
    {
        pStrDst = [[NSString alloc] initWithString:pStrSrc];
    } // if
    
    return pStrDst;
} // NSStringCreateCopy

// Using a name and extension, return a path to an image in an application bundle
static NSString *NSStringCreatePathForImage(const std::string& name,
                                            const std::string& ext)
{
    NSString *pPath = nil;
    
    if(!name.empty())
    {
        NSString *pName = [NSString stringWithCString:name.c_str()
                                             encoding:NSASCIIStringEncoding];
        
        NSString *pExt = [NSString stringWithCString:(!ext.empty() ? ext.c_str() : "jpg")
                                            encoding:NSASCIIStringEncoding];
        
        pPath = [[[NSBundle mainBundle] pathForResource:pName
                                                 ofType:pExt] retain];
    } // if
    
    return pPath;
} // NSStringCreatePathForImage

// Finalize the image by loading an image from a path and create a Metal texture
static bool AAPLMetalTextureFinalize(id<MTLDevice> device,
                                     AAPL::Metal::TextureData *pTexture)
{
    if(pTexture->m_Texture)
    {
        return YES;
    } // if
    
    if(!pTexture)
    {
        return false;
    } // if
    
    if(!device)
    {
        return false;
    } // if
    
    if(pTexture->m_Device)
    {
        [pTexture->m_Device release];
    } // if
    
    pTexture->m_Device = [device retain];
    
    UIImage *pImage = [UIImage imageWithContentsOfFile:pTexture->mpPath];
    
    if(!pImage)
    {
        return false;
    } // if
    
    CGColorSpaceRef pColorSpace = CGColorSpaceCreateDeviceRGB();
    
    if(!pColorSpace)
    {
        return false;
    } // if
    
    pTexture->mnWidth  = uint32_t(CGImageGetWidth(pImage.CGImage));
    pTexture->mnHeight = uint32_t(CGImageGetHeight(pImage.CGImage));
    
    uint32_t width    = pTexture->mnWidth;
    uint32_t height   = pTexture->mnHeight;
    uint32_t rowBytes = width * 4;
    
    CGContextRef pContext = CGBitmapContextCreate(NULL,
                                                  width,
                                                  height,
                                                  8,
                                                  rowBytes,
                                                  pColorSpace,
                                                  CGBitmapInfo(kCGImageAlphaPremultipliedLast));
    
    CGColorSpaceRelease(pColorSpace);
    
    if(!pContext)
    {
        return false;
    } // if
    
    CGRect bounds = CGRectMake(0.0f, 0.0f, width, height);
    
    CGContextClearRect(pContext, bounds);
    
    // Vertical Reflect
    if(pTexture->mbFlip)
    {
        CGContextTranslateCTM(pContext, width, height);
        CGContextScaleCTM(pContext, -1.0, -1.0);
    } // if
    
    CGContextDrawImage(pContext, bounds, pImage.CGImage);
    
    MTLTextureDescriptor *pTexDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                        width:width
                                                                                       height:height
                                                                                    mipmapped:NO];
    if(!pTexDesc)
    {
        CGContextRelease(pContext);
        
        return false;
    } // if
    
    pTexture->mnTarget  = pTexDesc.textureType;
    pTexture->m_Texture = [pTexture->m_Device newTextureWithDescriptor:pTexDesc];
    
    if(!pTexture->m_Texture)
    {
        CGContextRelease(pContext);
        
        return false;
    } // if
    
    const void *pPixels = CGBitmapContextGetData(pContext);
    
    if(pPixels != nullptr)
    {
        MTLRegion region = MTLRegionMake2D(0, 0, width, height);
        
        [pTexture->m_Texture replaceRegion:region
                               mipmapLevel:0
                                 withBytes:pPixels
                               bytesPerRow:rowBytes];
    } // if
    
    CGContextRelease(pContext);
    
    return true;
} // AAPLMetalTextureFinalize

// Delte the object
static void AAPLMetalTextureDelete(AAPL::Metal::TextureData *pTexture)
{
    if(pTexture != nullptr)
    {
        if(pTexture->m_Texture)
        {
            [pTexture->m_Texture release];
            
            pTexture->m_Texture = nil;
        } // if
        
        if(pTexture->mpPath)
        {
            [pTexture->mpPath release];
            
            pTexture->mpPath = nil;
        } // if
        
        delete pTexture;
        
        pTexture = nullptr;
    } // if
} // AAPLMetalTextureDelete

// Create and initialize with an absolute pathname to an image
static AAPL::Metal::TextureData *AAPLMetalTextureCreate(NSString *pPath)
{
    AAPL::Metal::TextureData *pTexture = nullptr;
    
    try
    {
        // Catch Memory error
        pTexture = new AAPL::Metal::TextureData;
        
        pTexture->mpPath    = pPath;
        pTexture->mnWidth   = 0;
        pTexture->mnHeight  = 0;
        pTexture->mnDepth   = 1;
        pTexture->mnFormat  = MTLPixelFormatInvalid;
        pTexture->mnTarget  = MTLTextureType2D;
        pTexture->mbFlip    = YES;
        pTexture->m_Texture = nil;
        pTexture->m_Device  = nil;
    } // Constructor
    catch(std::bad_alloc& ba)
    {
        NSLog(@">> ERROR: Failed allocating memory for the texture data store: \"%s\"", ba.what());
    } // catch
    
    return pTexture;
} // AAPLMetalTextureCreate

// Create and initialize with an absolute pathname to an image
static AAPL::Metal::TextureData *AAPLMetalTextureCreate(const std::string& path)
{
    NSString* pPath = NSStringCreateCopy(path);
    
    AAPL::Metal::TextureData *pTexture = AAPLMetalTextureCreate(pPath);
    
    if(!pTexture)
    {
        [pPath release];
        
        pPath = nil;
    } // if
    
    return pTexture;
} // AAPLMetalTextureCreate

// Create and initialize with an absolute pathname to an image in application bundle
static AAPL::Metal::TextureData *AAPLMetalTextureCreate(const std::string& name,
                                                        const std::string& ext)
{
    NSString* pPath = NSStringCreatePathForImage(name, ext);
    
    AAPL::Metal::TextureData *pTexture = AAPLMetalTextureCreate(pPath);
    
    if(!pTexture)
    {
        [pPath release];
        
        pPath = nil;
    } // if
    
    return pTexture;
} // AAPLMetalTextureCreate

// Create a copy of the texture opaque data reference
static AAPL::Metal::TextureData* AAPLMetalTextureCreateCopy(const AAPL::Metal::TextureData * const pTexSrc)
{
    AAPL::Metal::TextureData *pTexDst = nullptr;
    
    try
    {
        // Catch Memory error
        pTexDst = new AAPL::Metal::TextureData;
        
        pTexDst->mpPath    = NSStringCreateCopy(pTexSrc->mpPath);
        pTexDst->mnWidth   = 0;
        pTexDst->mnHeight  = 0;
        pTexDst->mnDepth   = 1;
        pTexDst->mnFormat  = MTLPixelFormatInvalid;
        pTexDst->mnTarget  = MTLTextureType2D;
        pTexDst->mbFlip    = pTexSrc->mbFlip;
        pTexDst->m_Texture = nil;
        pTexDst->m_Device  = nil;
        
        AAPLMetalTextureFinalize(pTexSrc->m_Device, pTexDst);
    } // try
    catch(std::bad_alloc& ba)
    {
        NSLog(@">> ERROR: Failed allocating memory for the texture copy data store: \"%s\"", ba.what());
    } // catch
    
    return pTexDst;
} // AAPLMetalTextureCreateCopy

// Constructor and initialize with an absolute pathname to an image
AAPL::Metal::Texture::Texture(const std::string& path)
{
    mpTexture = AAPLMetalTextureCreate(path);
} // Constructor

// Constructor and initialize with an image name and extension in application bundle
AAPL::Metal::Texture::Texture(const std::string& name,
                              const std::string& ext)
{
    mpTexture = AAPLMetalTextureCreate(name, ext);
} // Constructor

// Copy Constructor
AAPL::Metal::Texture::Texture(const AAPL::Metal::Texture& rTexture)
{
    AAPL::Metal::TextureData *pTexture = AAPLMetalTextureCreateCopy(rTexture.mpTexture);
    
    if(pTexture != nullptr)
    {
        AAPLMetalTextureDelete(mpTexture);
        
        mpTexture = pTexture;
    } // if
} // Copy Constructor

// Assignment operator
AAPL::Metal::Texture& AAPL::Metal::Texture::operator=(const AAPL::Metal::Texture& rTexture)
{
    if(this != &rTexture)
    {
        AAPL::Metal::TextureData *pTexture = AAPLMetalTextureCreateCopy(rTexture.mpTexture);
        
        if(pTexture != nullptr)
        {
            AAPLMetalTextureDelete(mpTexture);
            
            mpTexture = pTexture;
        } // if
    } // if
    
    return *this;
} // Assignment operator

// Delete the object
AAPL::Metal::Texture::~Texture()
{
    AAPLMetalTextureDelete(mpTexture);
} // Destructor

// Set to vertically reflect the input image
void AAPL::Metal::Texture::flip(const bool& doFlip)
{
    if(mpTexture != nullptr)
    {
        mpTexture->mbFlip = doFlip;
    } // if
} // flip

// Get the metal texture
id<MTLTexture>  AAPL::Metal::Texture::texture()
{
    return (mpTexture != nullptr) ? mpTexture->m_Texture : nil;
} // texture

// Get the texture target
const MTLTextureType AAPL::Metal::Texture::target() const
{
    return (mpTexture != nullptr) ? mpTexture->mnTarget : MTLTextureType(0);
} // target

// Get the texture width
const uint32_t AAPL::Metal::Texture::width() const
{
    return (mpTexture != nullptr) ? mpTexture->mnWidth : 0;
} // width

// Get the texture height
const uint32_t AAPL::Metal::Texture::height() const
{
    return (mpTexture != nullptr) ? mpTexture->mnHeight : 0;
} // height

// Get the texture depth
const uint32_t AAPL::Metal::Texture::depth() const
{
    return (mpTexture != nullptr) ? mpTexture->mnDepth : 0;
} // depth

// Get the texture format
const uint32_t AAPL::Metal::Texture::format() const
{
    return (mpTexture != nullptr) ? mpTexture->mnFormat : MTLPixelFormatInvalid;
} // format

// Is the texture vertical reflected
const bool AAPL::Metal::Texture::isFlipped() const
{
    return (mpTexture != nullptr) ? mpTexture->mbFlip : false;
} // isFlipped

bool AAPL::Metal::Texture::finalize(id <MTLDevice> device)
{
    return AAPLMetalTextureFinalize(device, mpTexture);
} // finalize
