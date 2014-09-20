/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Utility class for creating a Metal quad.
  
 */

#import <Metal/Metal.h>

#ifndef _AAPL_METAL_QUAD_H_
#define _AAPL_METAL_QUAD_H_

#import <Metal/Metal.h>

#ifdef __cplusplus

namespace AAPL
{
    namespace Metal
    {
        // Keys for setting or getting indices
        extern uint8_t kQuadIndexKeyVertex;
        extern uint8_t kQuadIndexKeyTexCoord;
        extern uint8_t kQuadIndexKeySampler;

        class QuadData;

        class Quad
        {
        public:
            // Constructor
            Quad(id<MTLDevice> device);
            
            // Destructor
            virtual ~Quad();
            
            // Copy Constructor
            Quad(const Quad& rQuad);
            
            // Assignment operator
            Quad& operator=(const Quad& rQuad);
            
            // Get the quad size
            const CGSize size() const;
            
            // Get the bounding view rectangle
            const CGRect bounds() const;
            
            // Get the aspect ratio
            const float aspect() const;
            
            // Get the vertex, texture coordinate or sampler index
            const NSUInteger index(const uint8_t& key) const;
            
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
            void setIndex(const uint8_t& key, const NSUInteger& value);

            // Set the quad size
            void setSize(const CGSize& size);
            
            // Set the view bounding rectangle
            void setBounds(const CGRect& bounds);

            // Encode a quad using a render encoder
            void encode(id<MTLRenderCommandEncoder> renderEncoder);
            
        private:
            QuadData *mpQuad;
        }; // Quad
    } // Metal
} // AAPL

#endif

#endif
