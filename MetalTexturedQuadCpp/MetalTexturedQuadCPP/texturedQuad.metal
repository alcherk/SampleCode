/*
 <samplecode>
 <abstract>
 Textured quad shader.
 </abstract>
 </samplecode>
 */

#include <metal_graphics>
#include <metal_matrix>
#include <metal_geometric>
#include <metal_math>
#include <metal_texture>

using namespace metal;

struct VertexOutput
{
    float4 m_Position [[position]];
    float2 m_TexCoord [[user(texturecoord)]];
};

struct FragmentInput
{
    float4 m_Position [[position]];
    float2 m_TexCoord [[user(texturecoord)]];
};

vertex VertexOutput texturedQuadVertex(constant float4         *pPosition   [[ buffer(0) ]],
                                       constant packed_float2  *pTexCoords  [[ buffer(1) ]],
                                       constant float4x4       *pMVP        [[ buffer(2) ]],
                                       uint                     vid         [[ vertex_id ]])
{
    VertexOutput outVertices;
    
    outVertices.m_Position = *pMVP * pPosition[vid];
    outVertices.m_TexCoord = pTexCoords[vid];
    
    return outVertices;
}

fragment half4 texturedQuadFragment(FragmentInput     inFrag    [[ stage_in ]],
                                    texture2d<float>  tex2D     [[ texture(0) ]],
                                    sampler           sampler2D [[ sampler(0) ]])
{
    float4 color = tex2D.sample(sampler2D, inFrag.m_TexCoord);
    
    return half4(color.r, color.g, color.b, color.a);
}
