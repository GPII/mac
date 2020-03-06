//
// Main.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

// NOTE: Node.JS's N-API documentation is located at: https://nodejs.org/api/n-api.html

@_cdecl("Init")
public func Init(env: napi_env!, exports: napi_value!) -> napi_value? {
    guard env != nil else {
        return nil
    }
    guard exports != nil else {
        return nil
    }

    var status: napi_status? = nil
    
    var napiPropertyDescriptors: [napi_property_descriptor] = []

    // NAPIAudioFunctions (MorphicAudio)
    napiPropertyDescriptors.append(contentsOf: NAPIAudioFunctions.getFunctionsAsPropertyDescriptors(env: env))

    // NAPIDiskFunctions (MorphicDisk)
    napiPropertyDescriptors.append(contentsOf: NAPIDiskFunctions.getFunctionsAsPropertyDescriptors(env: env))

    // NAPIDisplayFunctions (MorphicDisplay)
    napiPropertyDescriptors.append(contentsOf: NAPIDisplayFunctions.getFunctionsAsPropertyDescriptors(env: env))

    // NAPIInputFunctions (MorphicInput)
    napiPropertyDescriptors.append(contentsOf: NAPIInputFunctions.getFunctionsAsPropertyDescriptors(env: env))

    // NAPILanguageFunctions (MorphicLanguage)
    napiPropertyDescriptors.append(contentsOf: NAPILanguageFunctions.getFunctionsAsPropertyDescriptors(env: env))

    // NAPIProcessFunctions (MorphicProcess)
    napiPropertyDescriptors.append(contentsOf: NAPIProcessFunctions.getFunctionsAsPropertyDescriptors(env: env))

    // NAPIWindowFunctions (MorphicWindow)
    napiPropertyDescriptors.append(contentsOf: NAPIWindowFunctions.getFunctionsAsPropertyDescriptors(env: env))

    status = napi_define_properties(env, exports, napiPropertyDescriptors.count, &napiPropertyDescriptors)
    guard status == napi_ok else {
        return nil
    }
    
    return exports
}
