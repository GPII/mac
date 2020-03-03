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
    // NOTE: a nullable of type 'nil' denotes a JavaScript "null" with no attached type information
    case nullable(type: NAPIValueType?)
    //
    // NOTE: for .object, swiftType will be set to null for incoming napi_values (since the type will be resolved when matching against the function's signature); the swiftType must/will be specified in the Swift struct signatures however (see NAPIObjectCompatible.napiValuetype).
    case object(propertyNamesAndTypes: [String : NAPIValueType], swiftType: NAPIObjectCompatible.Type?)
    //
    // NOTE: an array of type 'nil' denotes an empty array
    case array(type: NAPIValueType?)
    //
    case undefined
    //
    // NOTE: 'unsupported' denotes a type which we do not support
    case unsupported
 
    // NOTE: setting disregardOptionals to true will equate optionally-wrapped types and non-wrapped types as a match (as long as the optional's wrapped type is the same as the non-wrapped type); this will be done recursively, ignoring any sub-optionals
    public func isCompatible(withRhs rhs: NAPIValueType, disregardRhsOptionals: Bool = false) -> Bool {
        switch self {
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
        case .nullable(let selfType):
            if case let .nullable(rhsType) = rhs {
                if selfType == nil || rhsType == nil {
                    // if one nullable contains no type (i.e. 'nil' type), its type always matches any other nullable (since a nullable of type nil is a JavaScript "null" and can therefore satisfy any nullable type)
                    return true
                } else {
                    return selfType!.isCompatible(withRhs: rhsType!, disregardRhsOptionals: disregardRhsOptionals)
                }
            }
        case .object(let selfPropertyNamesAndTypes, let selfSwiftType):
            var objectPropertyNamesAndTypesMatch = true 

            if case let .object(rhsPropertyNamesAndTypes, rhsSwiftType) = rhs {
                // make sure that the object types match (or that one is nil)
                if (selfSwiftType == nil && rhsSwiftType != nil) ||
                    (selfSwiftType != nil && rhsSwiftType == nil) {
                    // if one swiftType is nil, then we consider them a match; this is allowable because incoming napi_values which are objects do not actually have a SwiftType (yet the parameters to which they are passed _do_)
                } else {
                    // if both swiftTypes are non-nil, they _must_ be the same type (i.e. we do not do type coersion for objects)
                    if selfSwiftType.self != rhsSwiftType.self {
                        objectPropertyNamesAndTypesMatch = false 
                        break 
                    }
                }

                // check that the objects contain the same number of properties (and then compare the property names/types)
                if selfPropertyNamesAndTypes.count == rhsPropertyNamesAndTypes.count {
                    // objects contain the same number of properties
                    
                    // check that all properties in self are compatible with the same-named properties in rhs (and that the same-named properties exist in rhs)
                    for selfPropertyNameAndType in selfPropertyNamesAndTypes {
                        let propertyName = selfPropertyNameAndType.key
                        if rhsPropertyNamesAndTypes.keys.contains(propertyName) {
                            if selfPropertyNamesAndTypes[propertyName]!.isCompatible(withRhs: rhsPropertyNamesAndTypes[propertyName]!, disregardRhsOptionals: disregardRhsOptionals) == false {
                                objectPropertyNamesAndTypesMatch = false 
                                break
                            }
                        } else {
                            // property does not exist on rhs
                            objectPropertyNamesAndTypesMatch = false 
                            break 
                        }
                    }                    
                } else {
                    // if the numbere of properties don't match, the object types are not a match
                    objectPropertyNamesAndTypesMatch = false
                    break 
                }

                // if the object swiftType matched (or one was nil)--and if all the property names/types matched--then the types are compatible
                if objectPropertyNamesAndTypesMatch == true {
                    return true
                }
            }
        case .array(let selfType):
            if case let .array(rhsType) = rhs {
                if selfType == nil || rhsType == nil {
                    // if one array contains no elements (i.e. 'nil' type), its type matches any other array (since JavaScript arrays with no elements "contain no type information"; likewise, two empty ('nil' type) arrays always match
                    return true
                } else {
                    return selfType!.isCompatible(withRhs: rhsType!, disregardRhsOptionals: disregardRhsOptionals)
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
        
        // if no direct matches were found...but the user allows us to disregard optionals on the right-hand side...and if the right-side is an optional...then try that comparison now too
        if disregardRhsOptionals == true {
            if case let .nullable(rhsWrapped) = rhs {
                if let rhsWrapped = rhsWrapped {
                    return self.isCompatible(withRhs: rhsWrapped, disregardRhsOptionals: disregardRhsOptionals)
                }
            }
        }
        
        // otherwise, if no matches were found, return false
        return false
    }
    //
    public static func ==(lhs: NAPIValueType, rhs: NAPIValueType) -> Bool {
        return lhs.isCompatible(withRhs: rhs, disregardRhsOptionals: false)
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
        case napi_null:
            return .nullable(type: nil)
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
                // napiValue is an object (an un-specialized object, not a specific object type which we already handle); create its type by enumerating the names/types of its properties
                return getNAPIValueTypeOfObject(env: env, object: value)
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
    
    private static func getNAPIValueTypeOfObject(env: napi_env, object: napi_value) -> NAPIValueType {
        var status: napi_status

        // make sure that the napi_value is an object
        var cNapiValuetype: napi_valuetype = napi_undefined
        status = napi_typeof(env, object, &cNapiValuetype)
        guard status == napi_ok else {
            fatalError("Could not determine if argument 'object' represents an object")
        }
        
        precondition(cNapiValuetype == napi_object, "Argument 'object' must represent an object")

        // enumerate the properties of the object
        var propertyNamesAsCNapiValues: napi_value!
        status = napi_get_property_names(env, object, &propertyNamesAsCNapiValues)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError("Could not get object's properties' names")
        }
        //
        // convert the property names napi_value to an array of NAPIValues
        let propertyNamesAsNapiValue = NAPIValue(env: env, napiValue: propertyNamesAsCNapiValues, napiValueType: NAPIValueType.array(type: .string))
        let propertyNamesAsArrayOfNapiValues: [NAPIValue]
        do {
            guard let propertyNamesAsArrayOfNapiValuesAsNonOptional = try propertyNamesAsNapiValue.asArrayOfNapiValues() else {
                fatalError("Failed to enumerate array of object's property names")
            }
            propertyNamesAsArrayOfNapiValues = propertyNamesAsArrayOfNapiValuesAsNonOptional
        } catch {
            fatalError("Failed to enumerate array of object's property names")
        }
        //
        // capture the properties' names and NAPIValueTypes and store them in a dictionary
        var propertyNamesAndNapiValueTypes: [String : NAPIValueType] = [:]
        for propertyNameAsNapiValue in propertyNamesAsArrayOfNapiValues {
            // capture the property name
            let propertyName: String
            do {
                guard let propertyNameAsNonOptional = try propertyNameAsNapiValue.asString() else {
                    fatalError("Could not convert object property name into String")
                }
                propertyName = propertyNameAsNonOptional
            } catch {
                fatalError("Could not convert object property name into String")
            }
         
            // capture the property value's type
            var propertyValueAsCNapiValue: napi_value! = nil
            status = napi_get_property(env, object, propertyNameAsNapiValue.napiValue, &propertyValueAsCNapiValue)
            guard status == napi_ok else {
                fatalError("Could not determine if argument 'object' represents an object")
            }
            let propertyNapiValueType = NAPIValue(env: env, napiValue: propertyValueAsCNapiValue).napiValueType
            
            // add the property name and value type to our array
            propertyNamesAndNapiValueTypes[propertyName] = propertyNapiValueType
        }

        // NOTE: because object napi_values are typeless, we set the swiftType to nil; when this object is matched against an actual Swift function definition or Swift struct, we will verify that the types match (by comparing the number, names and types of properties)
        return .object(propertyNamesAndTypes: propertyNamesAndNapiValueTypes, swiftType: nil)
    }
}
