/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Functor for computing MVP linear transformation for a Metal quad using simd classes.
  
 */

#ifndef _AAPL_QUAD_TRANSFORM_H_
#define _AAPL_QUAD_TRANSFORM_H_

#import <simd/simd.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus

namespace AAPL
{
    namespace Metal
    {
        static const float kPrespectiveNear = 0.1f;
        static const float kPrespectiveFar  = 100.0f;
        
        class QTransformData;
        
        class QTransform
        {
        public:
            QTransform(const UIInterfaceOrientation& orientation = UIInterfaceOrientationPortrait,
                       const float& near = kPrespectiveNear,
                       const float& far = kPrespectiveFar);
            
            // Copy Constructor
            QTransform(const QTransform& rTranform);
            
            // Assignment operator
            QTransform& operator=(const QTransform& rTranform);
            
            virtual ~QTransform();
            
            void setOrientation(const UIInterfaceOrientation& orientation);
            
            void setNear(const float& near);
            void setFar(const float& far);
            
            void setLookAt(const simd::float3& eye,
                           const simd::float3& center,
                           const simd::float3& up);
            
            void setTranslate(const float& x,
                              const float& y,
                              const float& z);
            
            simd::float4x4 operator()(const float& aspect);
            
        private:
            QTransformData& m_Data;
        }; // QTransform
    } // Metal
} // AAPL

#endif

#endif
