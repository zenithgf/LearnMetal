//
//  shaders.metal
//  LearnMetal
//
//  Created by loyinglin on 2018/6/21.
//  Copyright © 2018年 loyinglin. All rights reserved.
//

#include <metal_stdlib>
#import "LYShaderTypes.h"

using namespace metal;

typedef struct
{
    atomic_uint channel[LY_CHANNEL_NUM][LY_CHANNEL_SIZE]; // rgb三个通道，每个通道有256种可能
} LYColorBuffer;

typedef struct
{
    float4 clipSpacePosition [[position]]; // position的修饰符表示这个是顶点
    float2 textureCoordinate; // 纹理坐标，会做插值处理
    
} RasterizerData;

constant float size = float(LY_CHANNEL_SIZE - 1);

vertex RasterizerData // 返回给片元着色器的结构体
vertexShader(uint vertexID [[ vertex_id ]], // vertex_id是顶点shader每次处理的index，用于定位当前的顶点
             constant LYVertex *vertexArray [[ buffer(LYVertexBufferIndexVertices) ]]) { // buffer表明是缓存数据，LYVertexBufferIndex是索引
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}

fragment float4
samplingShader(RasterizerData input [[stage_in]], // stage_in表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
               texture2d<float> colorTexture [[ texture(LYFragmentTextureIndexTextureSource) ]], // texture表明是纹理数据，LYFragmentTextureIndexTextureSource是索引
               device LYLocalBuffer &localBuffer [[buffer(LYFragmentBufferIndexConvert)]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear); // sampler是采样器
    
    float4 colorSample = colorTexture.sample(textureSampler, input.textureCoordinate); // 得到纹理对应位置的颜色
    int3 rgb = int3(colorSample.rgb * size);
    colorSample.rgb = float3(localBuffer.channel[0][rgb.r], localBuffer.channel[1][rgb.g], localBuffer.channel[2][rgb.b]) / size;
    
    return colorSample;
}


kernel void
grayKernel(texture2d<float, access::read>  sourceTexture  [[texture(LYFragmentTextureIndexTextureSource)]],
           device LYColorBuffer &out [[buffer(LYKernelBufferIndexOutput)]],
           uint2                          grid         [[thread_position_in_grid]])
{
    // 边界保护
    if(grid.x < sourceTexture.get_width() && grid.y < sourceTexture.get_height())
    {
        float4 color  = sourceTexture.read(grid); // 初始颜色
        int3 rgb = int3(color.rgb * size); //
        atomic_fetch_add_explicit(&out.channel[0][rgb.r], 1, memory_order_relaxed);
        atomic_fetch_add_explicit(&out.channel[1][rgb.g], 1, memory_order_relaxed);
        atomic_fetch_add_explicit(&out.channel[2][rgb.b], 1, memory_order_relaxed);
    }
    
}

