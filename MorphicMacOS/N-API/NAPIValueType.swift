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
    
    public init?(napi_valuetype: napi_valuetype) {
        switch napi_valuetype {
        case napi_number:
            self = .number
        case napi_string:
            self = .string
        case napi_undefined:
            self = .undefined
        default:
            return nil 
        }
    }

    public static func ==(lhs: NAPIValueType, rhs: NAPIValueType) -> Bool {
        switch lhs {
        case .number:
            if case .number = rhs {
                return true
            }
        case .string:
            if case .string = rhs {
                return true
            }
        case .undefined:
            if case .undefined = rhs {
                return true
            }
        }
        
        // if no matches were found, return false
        return false
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
