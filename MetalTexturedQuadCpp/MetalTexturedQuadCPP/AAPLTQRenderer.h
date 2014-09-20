/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A facade for managing and rendering a Metal textured quad.
  
 */

#ifndef _AAPL_TEXTURED_QUAD_RENDERER_H_
#define _AAPL_TEXTURED_QUAD_RENDERER_H_

#import <string>

#import <Metal/Metal.h>

#ifdef __cplusplus

namespace AAPL
{
    namespace Metal
    {
        class TQRendererData;
        
        class TQRenderer
        {
        public:
            // Construct a render from an application view
            TQRenderer(AAPLView *pRenderView);

            // Copy Constructor
            TQRenderer(const TQRenderer& rTQRenderer);
            
            // Assignment operator
            TQRenderer& operator=(const TQRenderer& rTQRenderer);

            // Destructor
            virtual ~TQRenderer();
            
            // Texture accessors
            const MTLTextureType  target()  const;
            const uint32_t        width()   const;
            const uint32_t        height()  const;
            const uint32_t        depth()   const;
            const uint32_t        format()  const;
            
            // Quad accessors
            const CGSize  size()    const;
            const CGRect  bounds()  const;
            const float   aspect()  const;
            
            // Set the view bounding rectangle
            void setBounds(const CGRect& bounds);
            
            // Querey:  Is the image vertically reflected?
            const bool isFlipped() const;

            // Add a textured quad constructed from an image at a path.
            // If the path is an empty string finalize will fail.
            bool finalize(const std::string& path);
            
            // Add a textured quad constructed from an image in app bundle.
            // If name is an empty string use "Default" as name.  If the
            // ext is an empty string use "jpg" as the file's extension.
            bool finalize(const std::string& name = "Default", const std::string& ext = "jpg");
            
            // Present the rendered textured quad
            void present();
            
        private:
            TQRendererData *mpRenderer;
        }; // TQRenderer
    } // Metal
} // AAPL

#endif

#endif

