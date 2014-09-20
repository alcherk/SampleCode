/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Simple Utility class for creating a 2d Metal texture.
  
 */

#ifndef _AAPL_METAL_TEXTURE_H_
#define _AAPL_METAL_TEXTURE_H_

#import <string>

#import <Metal/Metal.h>

#ifdef __cplusplus

namespace AAPL
{
    namespace Metal
    {
        class TextureData;

        class Texture
        {
        public:
            // Constructors
            Texture(const std::string& path);
            Texture(const std::string& name, const std::string& ext);

            // Destructor
            virtual ~Texture();
            
            // Copy Constructor
            Texture(const Texture& rTexture);
            
            // Assignment operator
            Texture& operator=(const Texture& rTexture);

            // Accessors
            const MTLTextureType  target()  const;
            const uint32_t        width()   const;
            const uint32_t        height()  const;
            const uint32_t        depth()   const;
            const uint32_t        format()  const;
            
            // Querey:  Is the image vertically reflected?
            const bool isFlipped() const;
            
            // Optional: Set to vertically reflect the input image.
            // Default is set to true.
            void flip(const bool& doFlip);
            
            // Finalize and acquire texture image
            bool finalize(id <MTLDevice> device);
            
            // Get the Metal texture
            id<MTLTexture>  texture();

        private:
            TextureData* mpTexture;
        }; // texture
    } //  Metal
} // AAPL

#endif

#endif
