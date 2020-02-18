//
// main.c
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

// NOTE: we specify NAPI_VERSION 4 (for Node.js 10.16 or newer); for Node.js 12.11 or newer, we could use NAPI_VERSION 5 instead
#define NAPI_VERSION 4
#import "./N-API/include/node_api.h"

// signature prototype for node.js addon's init function; implementation is in Main.swift
napi_value Init(napi_env env, napi_value exports);

// NOTE: the following line must be commented out when importing this library into a non-Node.js application
NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
