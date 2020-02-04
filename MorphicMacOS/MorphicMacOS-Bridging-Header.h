//
// MorphicMacOS-Bridging-Header.h
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

// dynamic node.js N-API headers (imported for use from Swift)
// NOTE: we specify NAPI_VERSION 4 (for Node.js 10.16 or newer); for Node.js 12.11 or newer, we could use NAPI_VERSION 5 instead
#define NAPI_VERSION 4
#import "node_api.h"
