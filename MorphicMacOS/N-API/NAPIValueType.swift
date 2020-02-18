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

public indirect enum NAPIValueType {
    case boolean
    case number
    case string
    //
    // NOTE: an array of type 'nil' denotes an empty array
    case array(type: NAPIValueType?)
    //
    case undefined
    //
    // NOTE: 'unsupported' denotes a type which we do not support
    case unsupported
 
    public static func ==(lhs: NAPIValueType, rhs: NAPIValueType) -> Bool {
        switch lhs {
        case .boolean:
            if case .boolean = rhs {
                return true
            }
        case .number:
            if case .number = rhs {
                return true
            }
        case .string:
            if case .string = rhs {
                return true
            }
        case .array(let lhsType):
            if case let .array(rhsType) = rhs {
                if lhsType == nil || rhsType == nil {
                    // if one array contains no elements (i.e. 'nil' type), its type matches any other array (since JavaScript arrays with no elements "contain no type information"; likewise, two empty ('nil' type) arrays always match
                    return true
                } else {
                    return lhsType! == rhsType!
                }
            }
        case .undefined:
            if case .undefined = rhs {
                return true
            }
        case .unsupported:
            if case .unsupported = rhs {
                return true
            }
        }
        
        // if no matches were found, return false
        return false
    }
    //
    public static func !=(lhs: NAPIValueType, rhs: NAPIValueType) -> Bool {
        return !(lhs == rhs)
    }
}

extension NAPIValueType {
    public static func getNAPIValueType(env: napi_env, value: napi_value) -> NAPIValueType {
        var valuetype: napi_valuetype = napi_undefined

        var status: napi_status

        status = napi_typeof(env, value, &valuetype)
        guard status == napi_ok else {
            fatalError("Could not get type of napi value")
        }

        switch valuetype {
        case napi_boolean:
            return .boolean
        case napi_number:
            return .number
        case napi_string:
            return .string
        case napi_object:
            // determine if this object is an array
            var napiValueIsArray: Bool = false
            status = napi_is_array(env, value, &napiValueIsArray)
            guard status == napi_ok else {
                fatalError("Could not get type of napi value")
            }
            //
            if napiValueIsArray == true {
                return getNAPIValueTypeOfArray(env: env, array: value)
            } else {
                // non-array objects are unsupported
                return .unsupported
            }
        case napi_undefined:
            return .undefined
        default:
            // other types are unsupported
            return .unsupported
        }
    }

    // NOTE: this function returns nil if it does not know the napi_valuetype of the element
    private static func getNAPIValueTypeOfArray(env: napi_env, array: napi_value) -> NAPIValueType {
        var status: napi_status

        // make sure that the napi_value is an array
        var isArray: Bool = false
        status = napi_is_array(env, array, &isArray)
        guard status == napi_ok else {
            fatalError("Could not determine if array represents an array")
        }
        
        precondition(isArray == true, "Argument 'array_of_values' must represent an array")

        // make sure that the array contains elements
        var lengthOfArray : UInt32 = 0
        status = napi_get_array_length(env, array, &lengthOfArray)
        guard status == napi_ok else {
            fatalError("Could not get element count of array")
        }
        
        if lengthOfArray == 0 {
            // if our array is empty, its type is effectively "undefined"
            return .undefined
        }
        precondition(lengthOfArray <= Int.max, "Arrays may not have a length greater than Int.max")

        // get type of first element
        let napiValueTypeOfFirstElement = getNAPIValueTypeOfArrayElement(env: env, array: array, index: 0)
        if napiValueTypeOfFirstElement == .unsupported {
            // if the first element is an unsupported type, the array itself is an unsupported type
            // NOTE: we do not return ".array(unsupported)" since we do not know if the array's elements are of the same unsupported type
            return .unsupported
        }
        // capture the type of the first element as the type of "all" elements (which is true so far, since we have only explored one element)
        var napiValueTypeOfAllElements = napiValueTypeOfFirstElement

        // get types of all subsequent elements (to ensure that they are all the same type...as we do not support mixed types in arrays)
        for index in 1..<lengthOfArray {
            let napiValueTypeOfElement = getNAPIValueTypeOfArrayElement(env: env, array: array, index: index)
            if napiValueTypeOfElement != napiValueTypeOfAllElements {
                // if the element types are not the same, the array itself is an unsupported type
                // NOTE: we do not return ".array(unsupported)" since we do not know if the array's elements are of the same unsupported type
                return .unsupported
            }
            
            // if both the current element and all previous elements were arrays, determine if this is the first subarray which contains type information
            if case let .array(elementType) = napiValueTypeOfElement {
                if case let .array(allElementsType) = napiValueTypeOfAllElements {
                    if allElementsType == nil && elementType != nil {
                        // this is the first subarray with type information; record that as the "type of all elements" now so that we make sure all further elements are of the same type and also so that we know which array type to return to our caller
                        napiValueTypeOfAllElements = napiValueTypeOfElement
                    }
                }
            }
        }

        return .array(type: napiValueTypeOfAllElements)
    }
    
    private static func getNAPIValueTypeOfArrayElement(env: napi_env, array: napi_value, index: UInt32) -> NAPIValueType {
        var status: napi_status

        var value: napi_value! = nil
        status = napi_get_element(env, array, index, &value)
        guard status == napi_ok, value != nil else {
            fatalError("Could not get type of napi array element at specified index")
        }

        return getNAPIValueType(env: env, value: value)
    }
}
