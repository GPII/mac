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

#include "node_api.h"

// signature prototype for node.js addon's init function; implementation is in Main.swift
napi_value Init(napi_env env, napi_value exports);

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
