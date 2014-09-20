/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
 A mediator object for managing a Metal textured quad.
  
 */

#ifndef _AAPL_TEXTURED_QUAD_H_
#define _AAPL_TEXTURED_QUAD_H_

#import <string>

#import <Metal/Metal.h>

#ifdef __cplusplus

namespace AAPL
{
    namespace Metal
    {
        class TexturedQuadData;
        
        class TexturedQuad
        {
        public:
            // Construct a textured quad with an image at application boundle.
            // Use "Default" the image name  and "jpg" as the file's extension.
            TexturedQuad(id <MTLDevice> device);
            
            // Construct a textured quad with an image at an absolute path.
            // If the path is an empty string finalize will fail.
            TexturedQuad(const std::string& path,
                         id <MTLDevice> device);
            
            // Construct a textured quad with an image at application boundle.
            // If name is an empty string use "Default" as name.  If the ext
            // is an empty string use "jpg" as the file's extension.
            TexturedQuad(const std::string& name,
                         const std::string& ext,
                         id <MTLDevice> device);
            
            // Destructor
            virtual ~TexturedQuad();
            
            // Copy Constructor
            TexturedQuad(const TexturedQuad& rTexturedQuad);
            
            // Assignment operator
            TexturedQuad& operator=(const TexturedQuad& rTexturedQuad);
            
            // Texture accessors
            const MTLTextureType  target()  const;
            const uint32_t        width()   const;
            const uint32_t        height()  const;
            const uint32_t        depth()   const;
            const uint32_t        format()  const;
            
            // Quad accessors
            const CGSize size()   const;
            const CGRect bounds() const;
            const float  aspect() const;

            // Set the view bounding rectangle
            void setBounds(const CGRect& bounds);

            // Querey:  Is the image vertically reflected?
            const bool isFlipped() const;

            // Update the linear transformations of a textured quad
            void update(const CGRect& frame);
            
            // Encode a textured quad
            void encode(id <MTLRenderCommandEncoder> renderEncoder);
            
        private:
            TexturedQuadData *mpTexturedQuad;
        }; // TexturedQuad
    } // Metal
} // AAPL

#endif

#endif

