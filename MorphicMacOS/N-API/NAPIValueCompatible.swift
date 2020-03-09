//
// NAPIValueCompatible.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

// NOTE: NAPIValueCompatible designates that a Swift type can be converted directly to and from a napi_value
public protocol NAPIValueCompatible {
    static var napiValueType: NAPIValueType { get }
}

extension Bool: NAPIValueCompatible {
    public static var napiValueType: NAPIValueType {
        return .boolean
    }
}
//
extension Double: NAPIValueCompatible {
    public static var napiValueType: NAPIValueType {
        return .number
    }
}
//
extension String: NAPIValueCompatible {
    public static var napiValueType: NAPIValueType {
        return .string
    }
}

extension Optional: NAPIValueCompatible where Wrapped: NAPIValueCompatible {
    public static var napiValueType: NAPIValueType {
        return .nullable(type: Wrapped.napiValueType)
    }
}

extension Array: NAPIValueCompatible where Element: NAPIValueCompatible {
    public static var napiValueType: NAPIValueType {
        return .array(type: Element.napiValueType)
    }
}
