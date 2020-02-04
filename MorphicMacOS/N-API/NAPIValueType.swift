//
// NAPIValueType.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

public enum NAPIValueType {
    case number
    case string
    //
    case undefined
}

extension NAPIValueType {
    static func getNAPIValueCompatibleTypeFor<T>(nativeType: T.Type) -> NAPIValueType? {
        if T.self == Double.self {
            return .number
        } else if T.self == String.self {
            return .string
        } else {
            // unsupported type
            return nil
        }
    }
}

extension NAPIValueType {
    public static func getNAPIValueTypeOf(env: napi_env, napiValue: napi_value) -> NAPIValueType {
        var status: napi_status
        var result: napi_valuetype = napi_undefined
        
        status = napi_typeof(env, napiValue, &result)
        guard status == napi_ok else {
            fatalError("Could not get type of napi value")
        }

        switch result {
        case napi_number:
            return .number
        case napi_string:
            return .string
        case napi_undefined:
            return .undefined
        default:
            fatalError("The type specified by 'napiValue' is not yet supported.")
        }
    }

}
