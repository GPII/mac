//
// NAPISwiftBridgeJavaScriptThrowableError.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

public enum NAPISwiftBridgeJavaScriptThrowableError: Error {
    case value(_ value: NAPIValueCompatible)
    //
    // NOTE: we have intentionally broken these base error types out into separate entities for ease of use; if the developer would like to raise a NAPIJavaScriptError, simply pass it to the value(...) case
    case error(message: String, code: String? = nil)
    case typeError(message: String, code: String? = nil)
    case rangeError(message: String, code: String? = nil)
    //
    case fatalError(message: String, location: String? = nil)
}
