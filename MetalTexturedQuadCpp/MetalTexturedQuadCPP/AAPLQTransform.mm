/*
 <codex>
 <import>AAPLQTransform.h</import>
 </codex>
 */

#import <cmath>

#import "AAPLTransforms.h"
#import "AAPLQTransform.h"

class AAPL::Metal::QTransformData
{
public:
    QTransformData(const float&          near,
                   const float&          far,
                   const float&          angle,
                   const simd::float4x4& lookAt,
                   const simd::float4x4& translate)
    {
        mnNear      = near;
        mnFar       = far;
        mnAngle     = angle;
        m_LootAt    = lookAt;
        m_Translate = translate;
    } // Constructor
    
    virtual ~QTransformData()
    {
        mnNear      = 0.0f;
        mnFar       = 0.0f;
        mnAngle     = 0.0f;
        m_LootAt    = 0.0f;
        m_Translate = 0.0f;
    } // Destructor
    
    QTransformData(const QTransformData& rTranform)
    {
        mnNear      = rTranform.mnNear;
        mnFar       = rTranform.mnFar;
        mnAngle     = rTranform.mnAngle;
        m_LootAt    = rTranform.m_LootAt;
        m_Translate = rTranform.m_Translate;
    } // Copy Constructor
    
    QTransformData& operator=(const QTransformData& rTranform)
    {
        if(this != &rTranform)
        {
            mnNear      = rTranform.mnNear;
            mnFar       = rTranform.mnFar;
            mnAngle     = rTranform.mnAngle;
            m_LootAt    = rTranform.m_LootAt;
            m_Translate = rTranform.m_Translate;
        } // if
        
        return *this;
    } // Assignment Operator
    
public:
    float  mnNear;
    float  mnFar;
    float  mnAngle;
    
    simd::float4x4  m_LootAt;
    simd::float4x4  m_Translate;
}; // QTransformData

static AAPL::Metal::QTransformData kTQTDefaultData  = AAPL::Metal::QTransformData(AAPL::Metal::kPrespectiveNear,
                                                                                  AAPL::Metal::kPrespectiveFar,
                                                                                  0.0f,
                                                                                  0.0f,
                                                                                  0.0f);

static const float kUIInterfaceOrientationLandscapeAngle = 35.0f;
static const float kUIInterfaceOrientationPortraitAngle  = 50.0f;

static float AAPLMetalQTransformGetAngle(const UIInterfaceOrientation& orientation)
{
    // Based on the device orientation, set the angle in degrees
    // between a plane which passes through the camera position
    // and the top of your screen and another plane which passes
    // through the camera position and the bottom of your screen.
    float dangle = 0.0f;
    
    switch(orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            dangle = kUIInterfaceOrientationLandscapeAngle;
            break;
            
        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationPortraitUpsideDown:
        default:
            dangle = kUIInterfaceOrientationPortraitAngle;
            break;
    } // switch
    
    float radians = AAPL::Math::radians(dangle);
    
    return radians;
} // AAPLMetalQTransformGetAngle

AAPL::Metal::QTransform::QTransform(const UIInterfaceOrientation& orientation,
                                    const float& near,
                                    const float& far)
: m_Data(kTQTDefaultData)
{
    // Create a viewing matrix derived from an eye point, a reference point
    // indicating the center of the scene, and an up vector.
    simd::float3 eye    = {0.0, 0.0, 0.0};
    simd::float3 center = {0.0, 0.0, 1.0};
    simd::float3 up     = {0.0, 1.0, 0.0};
    
    m_Data.m_LootAt = AAPL::Math::lookAt(eye, center, up);
    
    // Translate the object in (x,y,z) space.
    m_Data.m_Translate = AAPL::Math::translate(0.0f, -0.25f, 2.0f);
    
    // Describes a tranformation matrix that produces a perspective projection
    m_Data.mnNear  = near;
    m_Data.mnFar   = far;
    m_Data.mnAngle = AAPLMetalQTransformGetAngle(orientation);
} // Constructor


AAPL::Metal::QTransform::QTransform(const QTransform& rTranform)
: m_Data(rTranform.m_Data)
{
} // Copy Constructor

AAPL::Metal::QTransform& AAPL::Metal::QTransform::operator=(const QTransform& rTranform)
{
    if(this != &rTranform)
    {
        m_Data = rTranform.m_Data;
    } // if
    
    return *this;
} // Assignment operator

AAPL::Metal::QTransform::~QTransform()
{
    m_Data.m_LootAt    = 0.0f;
    m_Data.m_Translate = 0.0f;
    m_Data.mnNear      = 0.0f;
    m_Data.mnFar       = 0.0f;
    m_Data.mnAngle     = 0.0f;
} // Destructor

void AAPL::Metal::QTransform::setOrientation(const UIInterfaceOrientation& orientation)
{
    m_Data.mnAngle = AAPLMetalQTransformGetAngle(orientation);
} // setOrientation

void AAPL::Metal::QTransform::setNear(const float& near)
{
    m_Data.mnNear = near;
} // setNear

void AAPL::Metal::QTransform::setFar(const float& far)
{
    m_Data.mnFar = far;
} // setFar

void AAPL::Metal::QTransform::setLookAt(const simd::float3& eye,
                                        const simd::float3& center,
                                        const simd::float3& up)
{
    m_Data.m_LootAt = AAPL::Math::lookAt(eye, center, up);
} // setLookAt

void AAPL::Metal::QTransform::setTranslate(const float& x,
                                           const float& y,
                                           const float& z)
{
    m_Data.m_Translate = AAPL::Math::translate(x, y, z);
} // setTranslate

simd::float4x4 AAPL::Metal::QTransform::operator()(const float& aspect)
{
    // Compute the perspective linear transformation
    const float length = m_Data.mnNear * std::tan(m_Data.mnAngle);
    
    float right   = length/aspect;
    float left    = -right;
    float top     = length;
    float bottom  = -top;
    
    simd::float4x4 perspective = AAPL::Math::frustum_oc(left, right, bottom, top, m_Data.mnNear, m_Data.mnFar);
    
    // Create a viewing matrix derived from an eye point, a reference point
    // indicating the center of the scene, and an up vector. Then, coalesce
    // to create a linear transformation matrix.
    return perspective * m_Data.m_LootAt * m_Data.m_Translate;
} // Operator ()
