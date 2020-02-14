//
// NAPIValue.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

public class NAPIValue {
    private enum NAPIValueError: Error {
        case typeMismatch
        case otherNapiError
    }
    
    private let env: napi_env
    public let napiValue: napi_value
    public let napiValueType: NAPIValueType
    
    public convenience init(env: napi_env, napiValue: napi_value) {
        let type = NAPIValueType.getNAPIValueType(env: env, value: napiValue)

        self.init(env: env, napiValue: napiValue, napiValueType: type)
    }

    public init(env: napi_env, napiValue: napi_value, napiValueType: NAPIValueType) {
         self.env = env
         self.napiValue = napiValue
         self.napiValueType = napiValueType
     }

    public static func create<T>(env: napi_env, nativeValue: T) -> NAPIValue where T: NAPIValueCompatible {
        return create(env: env, nativeValue: nativeValue, napiValueType: T.napiValueType)
    }
    
    public static func create(env: napi_env, nativeValue: Any, napiValueType: NAPIValueType) -> NAPIValue {
        // convert the array to the NAPIValueCompatible protocol
        guard let _ = nativeValue as? NAPIValueCompatible else {
            fatalError("Argument 'nativeValue' must be be compatible with the NAPIValueCompatible protocol.")
        }
        
        switch napiValueType {
        case .number:
            return createNumber(env: env, nativeValue: nativeValue as! Double)
        case .string:
            return createString(env: env, nativeValue: nativeValue as! String)
        case .array(let napiValueTypeOfElements):
            if let napiValueTypeOfElements = napiValueTypeOfElements {
                return createArray(env: env, nativeArray: nativeValue, napiValueTypeOfElements: napiValueTypeOfElements)
            } else {
                // array is empty; return an empty array
                fatalError("WE NEED TO ADD SUPPORT TO CREATE AN EMPTY ARRAY")
            }
        case .undefined:
            // TODO: throw a JavaScript error instead
            fatalError()
        case .unsupported:
            // TODO: throw a JavaScript error instead
            fatalError()
        }
    }
    
    private static func createNumber(env: napi_env, nativeValue: Double) -> NAPIValue {
        var result: napi_value! = nil
        
        let status = napi_create_double(env, nativeValue, &result)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        return NAPIValue(env: env, napiValue: result)
    }

    private static func createString(env: napi_env, nativeValue: String) -> NAPIValue {
        var result: napi_value! = nil
        
        let status = napi_create_string_utf8(env, nativeValue, nativeValue.utf8.count, &result)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        return NAPIValue(env: env, napiValue: result)
    }

    private static func createArray(env: napi_env, nativeArray: Any, napiValueTypeOfElements: NAPIValueType) -> NAPIValue {
        // convert the array to the NAPIValueCompatible protocol
        guard let napiCompatibleValueArray = nativeArray as? Array<NAPIValueCompatible> else {
            fatalError("Argument 'nativeArray' must be an array of elementscompatible with the NAPIValueCompatible protocol.")
        }

        var subelementsAssNAPIValues: [NAPIValue] = []
        for index in 0..<napiCompatibleValueArray.count {
            let nativeSubelement = napiCompatibleValueArray[index]

            let subelementAsNAPIValue: NAPIValue = create(env: env, nativeValue: nativeSubelement, napiValueType: napiValueTypeOfElements)
            subelementsAssNAPIValues.append(subelementAsNAPIValue)
        }

        return createArray(env: env, napiValues: subelementsAssNAPIValues)
    }
    
    private static func createArray(env: napi_env, napiValues: [NAPIValue]) -> NAPIValue {
        precondition(napiValues.count < UInt32.max, "Argument 'napiValues may not have an element count greater than UInt32.max")
        
        var status: napi_status
        //
        // create the array
        var arrayAsNapiValue: napi_value! = nil
        status = napi_create_array_with_length(env, napiValues.count, &arrayAsNapiValue)
        guard status == napi_ok, arrayAsNapiValue != nil else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }
        //
        // populate the napi array
        for index in 0..<napiValues.count {
            status = napi_set_element(env, arrayAsNapiValue, UInt32(index), napiValues[index].napiValue)
            guard status == napi_ok else {
                // TODO: check for JavaScript errors instead and throw them instead
                fatalError()
            }
        }

        // NOTE: as a future optimization, we could capture the element type (and avoid re-enumerating the array)
//        let elementNapiValuetype = ...
//        let result = NAPIValue(env: env, napiValue: arrayAsNapiValue, elementNapiValuetype: elementNapiValuetype)

        let result = NAPIValue(env: env, napiValue: arrayAsNapiValue)
        return result
    }
    
    public func asNAPIValueCompatible() throws -> NAPIValueCompatible? {
        do {
            switch self.napiValueType {
            case .number:
                let value = try self.asDouble()
                return value
            case .string:
                let value = try self.asString()
                return value
            case .array(_):
                let valueAsNAPIValueCompatible = try self.asArray() as! NAPIValueCompatible
                return valueAsNAPIValueCompatible
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPIJavaScriptError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }

    public func asDouble() throws -> Double? {
        do {
            switch self.napiValueType {
            case .number:
                let valueAsDouble = try self.convertNapiValueToDouble()
                return valueAsDouble
            case .string:
                let valueAsString = try self.convertNapiValueToString()
                return Double(valueAsString)
            case .array(_):
                return nil
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPIJavaScriptError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asString() throws -> String? {
        do {
            switch self.napiValueType {
            case .number:
                let valueAsDouble = try self.convertNapiValueToDouble()
                return String(valueAsDouble)
            case .string:
                let valueAsString = try self.convertNapiValueToString()
                return valueAsString
            case .array(_):
                return nil
            case .undefined:
                return nil
            case .unsupported:
                return nil 
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPIJavaScriptError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asArray() throws -> [NAPIValueCompatible]? {
        do {
            switch self.napiValueType {
            case .number:
                return nil
            case .string:
                return nil
            case .array(_):
                let valueAsArray = try self.convertNapiValueToArray()
                return valueAsArray
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPIJavaScriptError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }

    private func convertNapiValueToDouble() throws -> Double {
        guard self.napiValueType == .number else {
            throw NAPIValueError.typeMismatch
        }

        var status: napi_status
        var valueAsDouble: Double = 0
        //
        status = napi_get_value_double(self.env, self.napiValue, &valueAsDouble)
        guard status == napi_ok else {
            if status == napi_number_expected {
                // type mismatch
                // TODO: we should still check for a JavaScript exception
                throw NAPIValueError.typeMismatch
            } else {
                // TODO: we should check for a JavaScript exception
                throw NAPIValueError.otherNapiError
            }
        }

        return valueAsDouble
    }
    
    private func convertNapiValueToString() throws -> String {
        guard self.napiValueType == .string else {
            throw NAPIValueError.typeMismatch
        }

        var status: napi_status
        
        var bufferSize = 0
        
        // first, get the size of the string; we do this by passing in a nil buffer (and then we get the size from its 'result' parameter)
        var requiredBufferSize: Int = 0
        status = napi_get_value_string_utf8(self.env, self.napiValue, nil, 0, &requiredBufferSize)
        guard status == napi_ok else {
            if status == napi_string_expected {
                // type mismatch
                // TODO: we should still check for a JavaScript exception
                throw NAPIValueError.typeMismatch
            } else {
                // TODO: we should check for a JavaScript exception
                throw NAPIValueError.otherNapiError
            }
        }
        bufferSize = requiredBufferSize + 1 // +1 for the null terminator
        
        // then get the full string; pass in a buffer equal to its size; we do not worry about null terminators since N-API auto-truncates for us
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        var populatedBufferSize: Int = 0
        status = napi_get_value_string_utf8(self.env, self.napiValue, buffer, bufferSize, &populatedBufferSize)
        guard status == napi_ok else {
            // TODO: we should check for a JavaScript exception
            throw NAPIValueError.otherNapiError
        }
        
        return String(cString: buffer)
    }
    
    private func convertNapiValueToArray() throws -> Array<NAPIValueCompatible> {
        guard case .array(_) = self.napiValueType else {
            throw NAPIValueError.typeMismatch
        }
                
        var status: napi_status
        
        var valueAsArray: Array<NAPIValueCompatible> = []
        //
        // capture the array length
        var arrayLength: UInt32 = 0
        status = napi_get_array_length(self.env, self.napiValue, &arrayLength)
        guard status == napi_ok else {
            if status == napi_array_expected {
                // type mismatch
                // TODO: we should still check for a JavaScript exception
                throw NAPIValueError.typeMismatch
            } else {
                // TODO: we should check for a JavaScript exception
                throw NAPIValueError.otherNapiError
            }
        }
        if arrayLength > Int.max {
            fatalError("Array cannot exceed Int.max in length")
        }
        let arrayLengthAsInt = Int(arrayLength)
        //
        valueAsArray.reserveCapacity(arrayLengthAsInt)
        // capture each array element
        for indexAsUInt32 in 0..<arrayLength {
            var elementAsNapiValue: napi_value! = nil
            status = napi_get_element(self.env, self.napiValue, indexAsUInt32, &elementAsNapiValue)
            guard status == napi_ok, elementAsNapiValue != nil else {
                if status == napi_array_expected {
                    // type mismatch
                    // TODO: we should still check for a JavaScript exception
                    throw NAPIValueError.typeMismatch
                } else {
                    // TODO: we should check for a JavaScript exception
                    throw NAPIValueError.otherNapiError
                }
            }

            guard let element = try NAPIValue(env: self.env, napiValue: elementAsNapiValue).asNAPIValueCompatible() else {
                // if we could not convert the value, throw an error
                throw NAPIValueError.otherNapiError
            }
            valueAsArray.append(element)
        }
        
        return valueAsArray
    }
}
