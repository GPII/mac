//
// NAPIJavaScriptError.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

public struct NAPIJavaScriptError: NAPIValueCompatible {
    public enum NameOption: String {
        case Error
        case RangeError
        case TypeError
    }
    
    public let name: NameOption
    public let message: String
    public let code: String?
    
    public init(name: NameOption, message: String, code: String? = nil) {
        self.name = name
        self.message = message
        self.code = code
    }
}
extension NAPIJavaScriptError {
    public static var napiValueType: NAPIValueType {
        return .error
    }
}
