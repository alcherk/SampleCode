/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Metal Renderer for Metal Envinroment mapping sample. Acts as the update and render delegate for the view controller and performs rendering. In Metal environment mapping sample, a cubemap is rendered, and a textured quad is rendered reflecting the cubemap. This demonstrates the use of mipmap pvrtc textures in Metal and cubemap textures in Metal.
  
 */

#import "AAPLRenderer.h"
#import "AAPLViewController.h"
#import "AAPLView.h"
#import "AAPLSharedTypes.h"
#import "AAPLPVRTexture.h"
#import "AAPLTransforms.h"

#import <UIKit/UIDevice.h>
#import <simd/simd.h>
#import <CoreVideo/CVMetalTextureCache.h>

static const long kMaxBufferBytesPerFrame = 1024*1024;
static const long kInFlightCommandBuffers = 3;

static const float kFOVY          = 65.0f;
static const simd::float3 kEye    = {0.0f, 0.0f, 0.0f};
static const simd::float3 kCenter = {0.0f, 0.0f, 1.0f};
static const simd::float3 kUp     = {0.0f, 1.0f, 0.0f};

static const float kQuadWidth  = 1.0f;
static const float kQuadHeight = 1.0f;
static const float kQuadDepth  = 1.0f;

static const float quad[] =
{
    // verticies (xyz), normal (xyz), texCoord (uv)
    kQuadWidth, -kQuadHeight, -kQuadDepth,  0.0,  0.0, -1.0,  1.0, 1.0,
    -kQuadWidth, -kQuadHeight, -kQuadDepth, 0.0,  0.0, -1.0,  0.0, 1.0,
    -kQuadWidth, kQuadHeight, -kQuadDepth,  0.0,  0.0, -1.0,  0.0, 0.0,
    kQuadWidth, kQuadHeight, -kQuadDepth,   0.0,  0.0, -1.0,  1.0, 0.0,
    kQuadWidth, -kQuadHeight, -kQuadDepth,  0.0,  0.0, -1.0,  1.0, 1.0,
    -kQuadWidth, kQuadHeight, -kQuadDepth,  0.0,  0.0, -1.0,  0.0, 0.0
};

static const simd::float4 cubeVertexData[] =
{
    // posx
    { -1.0f,  1.0f,  1.0f, 1.0f },
    { -1.0f, -1.0f,  1.0f, 1.0f },
    { -1.0f,  1.0f, -1.0f, 1.0f },
    { -1.0f, -1.0f, -1.0f, 1.0f },
    
    // negz
    { -1.0f,  1.0f, -1.0f, 1.0f },
    { -1.0f, -1.0f, -1.0f, 1.0f },
    { 1.0f,  1.0f, -1.0f, 1.0f },
    { 1.0f, -1.0f, -1.0f, 1.0f },
    
    // negx
    { 1.0f,  1.0f, -1.0f, 1.0f },
    { 1.0f, -1.0f, -1.0f, 1.0f },
    { 1.0f,  1.0f,  1.0f, 1.0f },
    { 1.0f, -1.0f,  1.0f, 1.0f },
    
    // posz
    { 1.0f,  1.0f,  1.0f, 1.0f },
    { 1.0f, -1.0f,  1.0f, 1.0f },
    { -1.0f,  1.0f,  1.0f, 1.0f },
    { -1.0f, -1.0f,  1.0f, 1.0f },
    
    // posy
    { 1.0f,  1.0f, -1.0f, 1.0f },
    { 1.0f,  1.0f,  1.0f, 1.0f },
    { -1.0f,  1.0f, -1.0f, 1.0f },
    { -1.0f,  1.0f,  1.0f, 1.0f },
    
    // negy
    { 1.0f, -1.0f,  1.0f, 1.0f },
    { 1.0f, -1.0f, -1.0f, 1.0f },
    { -1.0f, -1.0f,  1.0f, 1.0f },
    { -1.0f, -1.0f, -1.0f, 1.0f },
};

@implementation AAPLRenderer
{
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;
    id <MTLLibrary> _defaultLibrary;
    
    dispatch_semaphore_t _inflight_semaphore;
    id <MTLBuffer> _dynamicUniformBuffer[kInFlightCommandBuffers];
    
    // render stage
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLBuffer> _vertexBuffer;
    id <MTLDepthStencilState> _depthState;
    
    // global transform data
    simd::float4x4 _projectionMatrix;
    simd::float4x4 _viewMatrix;
    float _rotation;
    float _skyboxRotation;
    
    // skybox
    AAPLTexture *_skyboxTex;
    id <MTLRenderPipelineState> _skyboxPipelineState;
    id <MTLBuffer> _skyboxVertexBuffer;
    
    // texturedQuad
    AAPLTexture *_quadTex;
    id <MTLRenderPipelineState> _quadPipelineState;
    id <MTLBuffer> _quadVertexBuffer;
    id <MTLBuffer> _quadNormalBuffer;
    id <MTLBuffer> _quadTexCoordBuffer;
    
    // Video texture
    AVCaptureSession *_captureSession;
    CVMetalTextureCacheRef _videoTextureCache;
    id <MTLTexture> _videoTexture[3];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _sampleCount = 4;
        _depthPixelFormat = MTLPixelFormatDepth32Float;
        _stencilPixelFormat = MTLPixelFormatInvalid;
        
        // find a usable Device
        _device = MTLCreateSystemDefaultDevice();
        
        // create a new command queue
        _commandQueue = [_device newCommandQueue];
    
        _defaultLibrary = [_device newDefaultLibrary];
        if(!_defaultLibrary) {
            NSLog(@">> ERROR: Couldnt create a default shader library");
            
            // assert here becuase if the shader libary isnt loading, shaders arent compiling
            assert(0);
        }
        
        _constantDataBufferIndex = 0;
        _inflight_semaphore = dispatch_semaphore_create(kInFlightCommandBuffers);
    }
    return self;
}

#pragma mark RENDER VIEW DELEGATE METHODS

- (void)loadQuadAssets
{
    // read the vertex and fragment shader functions from the library
    id <MTLFunction> vertexProgram = [_defaultLibrary newFunctionWithName:@"reflectQuadVertex"];
    id <MTLFunction> fragmentProgram = [_defaultLibrary newFunctionWithName:@"reflectQuadFragment"];
    
    //  create a pipeline state descriptor for the quad
    MTLRenderPipelineDescriptor *quadPipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    quadPipelineStateDescriptor.label = @"EnvironmentMapPipelineState";
    
    // set pixel formats that match the framebuffer we are drawing into
    quadPipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    quadPipelineStateDescriptor.depthAttachmentPixelFormat      = _depthPixelFormat;
    quadPipelineStateDescriptor.sampleCount                     = _sampleCount;
    
    // set the vertex and fragment programs
    quadPipelineStateDescriptor.vertexFunction   = vertexProgram;
    quadPipelineStateDescriptor.fragmentFunction = fragmentProgram;
    
    // generate the pipeline state
    _quadPipelineState = [_device newRenderPipelineStateWithDescriptor:quadPipelineStateDescriptor error:nil];
    
    // setup the skybox vertex, texCoord and normal buffers
    _quadVertexBuffer = [_device newBufferWithBytes:quad length:sizeof(quad) options:MTLResourceOptionCPUCacheModeDefault];
    _quadVertexBuffer.label = @"EnvironmentMapVertexBuffer";
}

- (void)loadSkyboxAssets
{
    id <MTLFunction> vertexProgram = [_defaultLibrary newFunctionWithName:@"skyboxVertex"];
    id <MTLFunction> fragmentProgram = [_defaultLibrary newFunctionWithName:@"skyboxFragment"];
    
    //  create a pipeline state for the skybox
    MTLRenderPipelineDescriptor *skyboxPipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    skyboxPipelineStateDescriptor.label = @"SkyboxPipelineState";
    
    // the pipeline state must match the drawable framebuffer we are rendering into
    skyboxPipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    skyboxPipelineStateDescriptor.depthAttachmentPixelFormat      = _depthPixelFormat;
    skyboxPipelineStateDescriptor.sampleCount                     = _sampleCount;
    
    // attach the skybox shaders to the pipeline state
    skyboxPipelineStateDescriptor.vertexFunction   = vertexProgram;
    skyboxPipelineStateDescriptor.fragmentFunction = fragmentProgram;
    
    // finally, read out the pipeline state
    _skyboxPipelineState = [_device newRenderPipelineStateWithDescriptor:skyboxPipelineStateDescriptor error:nil];
    if(!_defaultLibrary) {
        NSLog(@">> ERROR: Couldnt create a pipeline");
        assert(0);
    }
    
    // create the skybox vertex buffer
    _skyboxVertexBuffer = [_device newBufferWithBytes:cubeVertexData length:sizeof(cubeVertexData) options:MTLResourceOptionCPUCacheModeDefault];
    _skyboxVertexBuffer.label = @"SkyboxVertexBuffer";
}

- (void)setupVideoQuadTexture
{
    CVMetalTextureCacheFlush(_videoTextureCache, 0);
    CVReturn textureCacheError = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, _device, NULL, &_videoTextureCache);
    
    if (textureCacheError)
    {
        NSLog(@">> ERROR: Couldnt create a texture cache");
        assert(0);
    }
    
    // Make and initialize a capture session
    _captureSession = [[AVCaptureSession alloc] init];
    
    if (!_captureSession) {
        NSLog(@">> ERROR: Couldnt create a capture session");
        assert(0);
    }
    
    [_captureSession beginConfiguration];
    [_captureSession setSessionPreset:AVCaptureSessionPresetLow];
    
    // Get the a video device with preference to the front facing camera
    AVCaptureDevice* videoDevice = nil;
    NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice* device in devices)
    {
        if ([device position] == AVCaptureDevicePositionFront)
        {
            videoDevice = device;
        }
    }
    
    if(videoDevice == nil)
    {
        videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    if(videoDevice == nil)
    {
        NSLog(@">> ERROR: Couldnt create a AVCaptureDevice");
        assert(0);
    }
    
    NSError *error;
    
    // Device input
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    
    if (error)
    {
        NSLog(@">> ERROR: Couldnt create AVCaptureDeviceInput");
        assert(0);
    }
    
    [_captureSession addInput:deviceInput];
    
    // Create the output for the capture session.
    AVCaptureVideoDataOutput * dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [dataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    // Set the color space.
    [dataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                             forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    // Set dispatch to be on the main thread so OpenGL can do things with the data
    [dataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    [_captureSession addOutput:dataOutput];
    [_captureSession commitConfiguration];
    
    [_captureSession startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVReturn error;
    
    CVImageBufferRef sourceImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width = CVPixelBufferGetWidth(sourceImageBuffer);
    size_t height = CVPixelBufferGetHeight(sourceImageBuffer);
    
    CVMetalTextureRef textureRef;
    error = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _videoTextureCache, sourceImageBuffer, NULL, MTLPixelFormatBGRA8Unorm, width, height, 0, &textureRef);
    
    if (error)
    {
        NSLog(@">> ERROR: Couldnt create texture from image");
        assert(0);
    }
    
    _videoTexture[_constantDataBufferIndex] = CVMetalTextureGetTexture(textureRef);
    if (!_videoTexture[_constantDataBufferIndex]) {
        NSLog(@">> ERROR: Couldn't get texture from texture ref");
        assert(0);
    }
    
    CVBufferRelease(textureRef);
}

- (void)configure:(AAPLView *)view
{
    view.depthPixelFormat   = _depthPixelFormat;
    view.stencilPixelFormat = _stencilPixelFormat;
    view.sampleCount        = _sampleCount;
    
    // allocate one region of memory for the constant buffer
    for (int i = 0; i < kInFlightCommandBuffers; i++)
    {
        _dynamicUniformBuffer[i] = [_device newBufferWithLength:kMaxBufferBytesPerFrame options:0];
        _dynamicUniformBuffer[i].label = [NSString stringWithFormat:@"ConstantBuffer%i", i];
    }
    
    // load the quad's pipeline state and buffer data
    [self loadQuadAssets];
    
    // load the skybox pipeline state and buffer data
    [self loadSkyboxAssets];
    
    // read a mipmapped pvrtc encoded texture
    _quadTex = [[AAPLPVRTexture alloc] initWithResourceName:@"copper_mipmap_4" extension:@"pvr"];
    BOOL loaded = [_quadTex loadIntoTextureWithDevice:_device];
    if (!loaded)
        NSLog(@"failed to load PVRTC Texture for quad");
    
    // load the skybox
    _skyboxTex = [[AAPLTextureCubeMap alloc] initWithResourceName:@"skybox" extension:@"png"];
    loaded = [_skyboxTex loadIntoTextureWithDevice:_device];
    if (!loaded)
        NSLog(@"failed to load skybox texture");
    
    // setup the depth state
    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionAlways;
    depthStateDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
    
    // initialize and load all necessary data for video quad texture
    [self setupVideoQuadTexture];
}

- (void)renderSkybox:(id <MTLRenderCommandEncoder>)renderEncoder view:(AAPLView *)view name:(NSString *)name
{
    // setup for GPU debugger
    [renderEncoder pushDebugGroup:name];
    
    // set the pipeline state object for the quad which contains its precompiled shaders
    [renderEncoder setRenderPipelineState:_skyboxPipelineState];
    
    // set the vertex buffers for the skybox at both indicies 0 and 1 since we are using its vertices as texCoords in the shader
    [renderEncoder setVertexBuffer:_skyboxVertexBuffer offset:0 atIndex:SKYBOX_VERTEX_BUFFER];
    [renderEncoder setVertexBuffer:_skyboxVertexBuffer offset:0 atIndex:SKYBOX_TEXCOORD_BUFFER];
    
    // set the model view projection matrix for the skybox
    [renderEncoder setVertexBuffer:_dynamicUniformBuffer[_constantDataBufferIndex] offset:0 atIndex:SKYBOX_CONSTANT_BUFFER];
    
    // set the fragment shader's texture and sampler
    [renderEncoder setFragmentTexture:_skyboxTex.texture atIndex:SKYBOX_IMAGE_TEXTURE];
    
    [renderEncoder drawPrimitives: MTLPrimitiveTypeTriangleStrip vertexStart: 0 vertexCount: 24];
    
    [renderEncoder popDebugGroup];
}

- (void)renderTexturedQuad:(id <MTLRenderCommandEncoder>)renderEncoder view:(AAPLView *)view name:(NSString *)name
{
    // setup for GPU debugger
    [renderEncoder pushDebugGroup:name];
    
    // set the pipeline state object for the skybox which contains its precompiled shaders
    [renderEncoder setRenderPipelineState:_quadPipelineState];
    
    // set the static vertex buffers
    [renderEncoder setVertexBuffer:_quadVertexBuffer offset:0 atIndex:QUAD_VERTEX_BUFFER];
    
    // read the model view project matrix data from the constant buffer
    [renderEncoder setVertexBuffer:_dynamicUniformBuffer[_constantDataBufferIndex] offset:0 atIndex:QUAD_VERTEX_CONSTANT_BUFFER];
    
    // fragment texture for environment
    [renderEncoder setFragmentTexture:_skyboxTex.texture atIndex:QUAD_ENVMAP_TEXTURE];
    
    // fragment texture for image to be mixed with reflection
    if (!_videoTexture[_constantDataBufferIndex])
    {
        [renderEncoder setFragmentTexture:_quadTex.texture atIndex:QUAD_IMAGE_TEXTURE];
    }
    else
    {
        [renderEncoder setFragmentTexture:_videoTexture[_constantDataBufferIndex] atIndex:QUAD_IMAGE_TEXTURE];
    }
    
    // inverted view matrix fragment buffer for environment mapping
    [renderEncoder setFragmentBuffer:_dynamicUniformBuffer[_constantDataBufferIndex] offset:0 atIndex:QUAD_FRAGMENT_CONSTANT_BUFFER];
    
    // tell the render context we want to draw our primitives
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
    
    [renderEncoder popDebugGroup];
}

- (void)render:(AAPLView *)view
{
    dispatch_semaphore_wait(_inflight_semaphore, DISPATCH_TIME_FOREVER);
    
    [self update];
    
    // create a new command buffer for each renderpass to the current drawable
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    // create a render command encoder so we can render into something
    MTLRenderPassDescriptor *renderPassDescriptor = view.renderPassDescriptor;
    if (renderPassDescriptor)
    {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder setDepthStencilState:_depthState];
        
        // render the skybox and the quad
        [self renderSkybox:renderEncoder view:view name:@"skybox"];
        [self renderTexturedQuad:renderEncoder view:view name:@"envmapQuadMix"];
        
        [renderEncoder endEncoding];
        
        // call the view's completion handler which is required by the view since it will signal its semaphore and set up the next buffer
        __block dispatch_semaphore_t block_sema = _inflight_semaphore;
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
            dispatch_semaphore_signal(block_sema);
        }];
        
        // schedule a present once the framebuffer is complete
        [commandBuffer presentDrawable:view.currentDrawable];
        
        // finalize rendering here. this will push the command buffer to the GPU
        [commandBuffer commit];
    }
    else
    {
        // release the semaphore to keep things synchronized even if we couldnt render
        dispatch_semaphore_signal(_inflight_semaphore);
    }
    
    // the renderview assumes it can now increment the buffer index and that the previous index wont be touched
    // until we cycle back around to the same index
    _constantDataBufferIndex = (_constantDataBufferIndex + 1) % kInFlightCommandBuffers;
}

- (void)reshape:(AAPLView *)view
{
    // when reshape is called, update the view and projection matricies since this means the view orientation or size changed
    float aspect = fabsf(view.bounds.size.width / view.bounds.size.height);
    _projectionMatrix = AAPL::perspective_fov(kFOVY, aspect, 0.1f, 100.0f);
    _viewMatrix = AAPL::lookAt(kEye, kCenter, kUp);
}

#pragma mark VIEW CONTROLLER DELEGATE METHODS

- (void)update:(AAPLViewController *)controller
{
    _rotation += controller.timeSinceLastDraw * 20.0f;
    _skyboxRotation += controller.timeSinceLastDraw * 1.0f;
}

- (void)update
{
    simd::float4x4 base_model = AAPL::translate(0.0f, 0.0f, 5.0f) * AAPL::rotate(_rotation, 0.0f, 1.0f, 0.0f);
    simd::float4x4 quad_mv = _viewMatrix * base_model;
    
    AAPL::uniforms_t *uniforms = (AAPL::uniforms_t *)[_dynamicUniformBuffer[_constantDataBufferIndex] contents];
    uniforms->modelview_matrix = quad_mv;
    uniforms->normal_matrix = simd::inverse(simd::transpose(quad_mv));
    uniforms->modelview_projection_matrix = _projectionMatrix * quad_mv;
    uniforms->inverted_view_matrix = simd::inverse(_viewMatrix);

    // calculate the model view projection data for the skybox
    simd::float4x4 skyboxModelMatrix = AAPL::scale(10.0f) * AAPL::rotate(_skyboxRotation, 0.0f, 1.0f, 0.0f);
    simd::float4x4 skyboxModelViewMatrix = _viewMatrix * skyboxModelMatrix;
    
    // write the skybox transformation data into the current constant buffer
    uniforms->skybox_modelview_projection_matrix = _projectionMatrix * skyboxModelViewMatrix;
    
    // Set the device orientation
    switch ([UIApplication sharedApplication].statusBarOrientation)
    {
        case UIDeviceOrientationUnknown:
            uniforms->orientation = AAPL::Unknown;
            break;
        case UIDeviceOrientationPortrait:
            uniforms->orientation = AAPL::Portrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            uniforms->orientation = AAPL::PortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeRight:
            uniforms->orientation = AAPL::LandscapeRight;
            break;
        case UIDeviceOrientationLandscapeLeft:
            uniforms->orientation = AAPL::LandscapeLeft;
            break;
        default:
            uniforms->orientation = AAPL::Portrait;
            break;
    }
}

- (void)viewController:(AAPLViewController *)controller willPause:(BOOL)pause
{
    // timer is suspended/resumed
    // Can do any non-rendering related background work here when suspended
    if (pause)
        [_captureSession stopRunning];
    else
        [_captureSession startRunning];
    
}


@end
