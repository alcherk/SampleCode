# MetalEnvironmentMapping

This sample emulates a sci-fi "Space Prison" by combining several textures using Metal. It demonstrates environment map reflection from a cubemap (which is also rendered seperatly as the starfield skybox) combined with a 2D mipmap PVRTC texture (copper metal texture), video captured from the camera as individual metal textures, and some basic lighting equations. Put yourself into the space prison by pointing the front facing camera at yourself.

As in other Metal sample code, AAPLRenderer.mm is the core of the project and where the magic happens. The render is based on Metal and uses AVFoundation capture APIs to obtain video from the camera. Each frame of video is obtained as an individual Metal texture via CVMetalTextureRef and CVMetalTextureCache APIs. The quad spinning in space is renderered by mixing the various textures on the GPU. 


## Requirements

### Build

iOS 8

### Runtime

iOS 8, 64 bit devices

Copyright (C) 2014 Apple Inc. All rights reserved.
