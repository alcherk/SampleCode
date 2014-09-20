# MetalTexturedQuadCpp

This sample demonstrates how to render a simple textured quad using Metal. The renderer code is written in C++, and the app code in objective-c. Its purpose is to provide a reference for how one might work with Metal, which is objective-C API from a C++ codebase.

The C++ Metal renderer follows a linear flow. The base classes are texture and quad objects. Textured quad is composed of these base classes which in turn is presented to a client through the facade of the renderer class.

A comprehensive pdf is included in the project which details the design patterns used to create this project. Although rendering a textured quad is the content which we render, the goal of the sample is to provide some best practices when working with Metal and Objective-C++ by demostrating some good design patterns for large scale application structure. 

## Requirements

### Build

iOS 8 SDK

### Runtime

iOS 8, 64 bit devices

Copyright (C) 2014 Apple Inc. All rights reserved.
