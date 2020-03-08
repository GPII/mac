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
    
    private let cNapiEnv: napi_env
    public let cNapiValue: napi_value
    public let napiValueType: NAPIValueType
    
    public convenience init(cNapiEnv: napi_env, cNapiValue: napi_value) {
        let napiValueType = NAPIValueType.getNAPIValueType(cNapiEnv: cNapiEnv, cNapiValue: cNapiValue)

        self.init(cNapiEnv: cNapiEnv, cNapiValue: cNapiValue, napiValueType: napiValueType)
    }

    public init(cNapiEnv: napi_env, cNapiValue: napi_value, napiValueType: NAPIValueType) {
         self.cNapiEnv = cNapiEnv
         self.cNapiValue = cNapiValue
         self.napiValueType = napiValueType
     }

    public static func create<T>(cNapiEnv: napi_env, nativeValue: T) -> NAPIValue where T: NAPIValueCompatible {
        return create(cNapiEnv: cNapiEnv, nativeValue: nativeValue, napiValueType: T.napiValueType)
    }
    
    // NOTE: if a napiValueType of .nullable(...) is provided the function will either return a ".nullable(nil)" or a NAPIValue of the wrapped type
    public static func create(cNapiEnv: napi_env, nativeValue: Any, napiValueType: NAPIValueType) -> NAPIValue {
        // convert the array to the NAPIValueCompatible protocol
        guard let _ = nativeValue as? NAPIValueCompatible else {
            fatalError("Argument 'nativeValue' must be be compatible with the NAPIValueCompatible protocol.")
        }

        if case .nullable(_) = napiValueType {
            // if napiValueType is nullable, the nativeValue may be nil: proceed
        } else {
            // if napiValueType is not optional, make sure that nativeValue is not nil
            if case Optional<Any>.none = nativeValue {
                fatalError("Argument 'nativeValue' cannot be nil if its type is not optional.")
            }
        }
        
        switch napiValueType {
        case .boolean:
            return createBoolean(cNapiEnv: cNapiEnv, nativeValue: nativeValue as! Bool)
        case .number:
            return createNumber(cNapiEnv: cNapiEnv, nativeValue: nativeValue as! Double)
        case .string:
            return createString(cNapiEnv: cNapiEnv, nativeValue: nativeValue as! String)
        case .nullable(let napiValueTypeOfWrapped):
            if napiValueTypeOfWrapped != nil {
                if case Optional<Any>.none = nativeValue {
                    // if we have a wrapped type but the value is nil, return a JavaScript null
                    return createNull(cNapiEnv: cNapiEnv)
                } else {
                    // if the value is non-nil, return the appropriate JavaScript type
                    return create(cNapiEnv: cNapiEnv, nativeValue: nativeValue, napiValueType: napiValueTypeOfWrapped!)
                }
            } else {
                // if we don't have a type then return null
                return createNull(cNapiEnv: cNapiEnv)
            }
        case .object(_, let swiftType):
            // NOTE: all NAPIValues which we create from Swift types must have an associated swiftType
            guard let swiftType = swiftType else {
                fatalError("Argument 'nativeValueType' is an object but has no associated Swift type")
            }
            guard swiftType.self == type(of: nativeValue).self else {
                fatalError("Argument 'nativeValueType' specified an object with a different Swift type than argument 'nativeValue'")
            }
            guard let nativeValueAsNapiObjectCompatible = nativeValue as? NAPIObjectCompatible else {
                fatalError("Argument 'nativeValue' does not conform to the NAPIObjectCompatible protocol")
            }
            return createObject(cNapiEnv: cNapiEnv, nativeValue: nativeValueAsNapiObjectCompatible, ofType: swiftType)
        case .array(let napiValueTypeOfElements):
            if let napiValueTypeOfElements = napiValueTypeOfElements {
                return createArray(cNapiEnv: cNapiEnv, nativeArray: nativeValue, napiValueTypeOfElements: napiValueTypeOfElements)
            } else {
                // array is empty; return an empty array
                fatalError("WE NEED TO ADD SUPPORT TO CREATE AN EMPTY ARRAY")
            }
        case .function:
            return createFunction(cNapiEnv: cNapiEnv, nativeValue: nativeValue as! NAPIJavaScriptFunction)
        case .error:
            return createError(cNapiEnv: cNapiEnv, nativeValue: nativeValue as! NAPIJavaScriptError)
        case .undefined:
            // TODO: throw a JavaScript error instead
            fatalError()
        case .unsupported:
            // TODO: throw a JavaScript error instead
            fatalError()
        }
    }

    private static func createBoolean(cNapiEnv: napi_env, nativeValue: Bool) -> NAPIValue {
        var resultAsCNapiValue: napi_value! = nil
        
        // NOTE: napi_get_boolean gets the JavaScript boolean singleton (true or false)
        let status = napi_get_boolean(cNapiEnv, nativeValue, &resultAsCNapiValue)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        return NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: resultAsCNapiValue)
    }

    private static func createNumber(cNapiEnv: napi_env, nativeValue: Double) -> NAPIValue {
        var resultAsCNapiValue: napi_value! = nil
        
        let status = napi_create_double(cNapiEnv, nativeValue, &resultAsCNapiValue)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        return NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: resultAsCNapiValue)
    }

    private static func createString(cNapiEnv: napi_env, nativeValue: String) -> NAPIValue {
        var resultAsCNapiValue: napi_value! = nil
        
        let status = napi_create_string_utf8(cNapiEnv, nativeValue, nativeValue.utf8.count, &resultAsCNapiValue)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        return NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: resultAsCNapiValue)
    }

    private static func createNull(cNapiEnv: napi_env) -> NAPIValue {
        var resultAsCNapiValue: napi_value! = nil
        
        // NOTE: napi_get_boolean gets the JavaScript null singleton
        let status = napi_get_null(cNapiEnv, &resultAsCNapiValue)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        return NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: resultAsCNapiValue)
    }
    
    private static func createObject(cNapiEnv: napi_env, nativeValue: NAPIObjectCompatible, ofType targetType: NAPIObjectCompatible.Type) -> NAPIValue {
        var resultAsCNapiValue: napi_value! = nil
        
        var status = napi_create_object(cNapiEnv, &resultAsCNapiValue)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        // create a NAPI value by reflecting on the properties of the provided object
        let mirror = Mirror(reflecting: nativeValue)
        for child in mirror.children {
            guard let propertyName = child.label else {
                fatalError("Mirror reflection failed: could not retrieve property name")
            }
            let propertyValue = child.value
            
            let propertyNameAsNapiValue = NAPIValue.create(cNapiEnv: cNapiEnv, nativeValue: propertyName, napiValueType: .string)

            let propertyAsCNapiValue: napi_value
            if case Optional<Any>.none = propertyValue {
                propertyAsCNapiValue = createNull(cNapiEnv: cNapiEnv).cNapiValue
            } else {
                guard let propertyValueAsNapiValueCompatible = propertyValue as? NAPIValueCompatible else {
                    fatalError("Property \(propertyName) is not a NAPIValueCompatible type")
                }
                let napiValueTypeOfPropertyValue = type(of: propertyValueAsNapiValueCompatible).napiValueType
                propertyAsCNapiValue = NAPIValue.create(cNapiEnv: cNapiEnv, nativeValue: propertyValueAsNapiValueCompatible, napiValueType: napiValueTypeOfPropertyValue).cNapiValue
            }

            status = napi_set_property(cNapiEnv, resultAsCNapiValue, propertyNameAsNapiValue.cNapiValue, propertyAsCNapiValue)
            guard status == napi_ok else {
                // TODO: check for JavaScript errors instead and throw them instead
                fatalError()
            }
        }
        
        return NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: resultAsCNapiValue)
    }

    private static func createArray(cNapiEnv: napi_env, nativeArray: Any, napiValueTypeOfElements: NAPIValueType) -> NAPIValue {
        // convert the array to the NAPIValueCompatible protocol
        guard let napiCompatibleValueArray = nativeArray as? Array<NAPIValueCompatible> else {
            fatalError("Argument 'nativeArray' must be an array of elementscompatible with the NAPIValueCompatible protocol.")
        }

        var subelementsAsNapiValues: [NAPIValue] = []
        for index in 0..<napiCompatibleValueArray.count {
            let nativeSubelement = napiCompatibleValueArray[index]

            let subelementAsNapiValue: NAPIValue = create(cNapiEnv: cNapiEnv, nativeValue: nativeSubelement, napiValueType: napiValueTypeOfElements)
            subelementsAsNapiValues.append(subelementAsNapiValue)
        }

        return createArray(cNapiEnv: cNapiEnv, napiValues: subelementsAsNapiValues)
    }
    
    private static func createArray(cNapiEnv: napi_env, napiValues: [NAPIValue]) -> NAPIValue {
        precondition(napiValues.count < UInt32.max, "Argument 'napiValues may not have an element count greater than UInt32.max")
        
        var status: napi_status
        //
        // create the array
        var arrayAsCNapiValue: napi_value! = nil
        status = napi_create_array_with_length(cNapiEnv, napiValues.count, &arrayAsCNapiValue)
        guard status == napi_ok, arrayAsCNapiValue != nil else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }
        //
        // populate the napi array
        for index in 0..<napiValues.count {
            status = napi_set_element(cNapiEnv, arrayAsCNapiValue, UInt32(index), napiValues[index].cNapiValue)
            guard status == napi_ok else {
                // TODO: check for JavaScript errors instead and throw them instead
                fatalError()
            }
        }

        // NOTE: as a future optimization, we could capture the element type (and avoid re-enumerating the array)
//        let elementNapiValuetype = ...
//        let result = NAPIValue(env: env, napiValue: arrayAsNapiValue, elementNapiValuetype: elementNapiValuetype)

        let result = NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: arrayAsCNapiValue)
        return result
    }
    
    private static func createFunction(cNapiEnv: napi_env, nativeValue: NAPIJavaScriptFunction) -> NAPIValue {
        return NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: nativeValue.cNapiValue)
    }
    
    private static func createError(cNapiEnv: napi_env, nativeValue: NAPIJavaScriptError) -> NAPIValue {
        var status: napi_status

        // create a napi_value representing the error's message
        let messageAsCNapiValue = NAPIValue.createString(cNapiEnv: cNapiEnv, nativeValue: nativeValue.message).cNapiValue
        
        // create a napi_value representing the error's code (optional)
        let codeAsCNapiValue: napi_value?
        if let code = nativeValue.code {
            codeAsCNapiValue = NAPIValue.createString(cNapiEnv: cNapiEnv, nativeValue: code).cNapiValue
        } else {
            codeAsCNapiValue = nil
        }
        
        // create an error napi_value
        var errorAsCNapiValue: napi_value! = nil
        switch nativeValue.name {
        case .Error:
            status = napi_create_error(cNapiEnv, codeAsCNapiValue, messageAsCNapiValue, &errorAsCNapiValue)
            guard status == napi_ok, errorAsCNapiValue != nil else {
                // TODO: check for JavaScript errors instead and throw them instead
                fatalError()
            }
        case .TypeError:
            status = napi_create_type_error(cNapiEnv, codeAsCNapiValue, messageAsCNapiValue, &errorAsCNapiValue)
            guard status == napi_ok, errorAsCNapiValue != nil else {
                // TODO: check for JavaScript errors instead and throw them instead
                fatalError()
            }
        case .RangeError:
            status = napi_create_range_error(cNapiEnv, codeAsCNapiValue, messageAsCNapiValue, &errorAsCNapiValue)
            guard status == napi_ok, errorAsCNapiValue != nil else {
                // TODO: check for JavaScript errors instead and throw them instead
                fatalError()
            }
        }
        //
        return NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: errorAsCNapiValue)
    }
    
    public func asNAPIValueCompatible() throws -> NAPIValueCompatible? {
        do {
            switch self.napiValueType {
            case .boolean:
                let value = try self.asBool()
                return value
            case .number:
                let value = try self.asDouble()
                return value
            case .string:
                let value = try self.asString()
                return value
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                fatalError("This function should not be called for object NAPIValueTypes; call .asNAPIValueCompatibleObject(...) instead")
            case .array(_):
                fatalError("This function should not be called for array NAPIValueTypes; call .asArrayOfNAPIValueCompatible(...) instead")
            case .function:
                let value = try self.asJavaScriptFunction()
                return value
            case .error:
                let value = try self.asJavaScriptError()
                return value
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asNAPIValueCompatibleObject(ofType targetType: NAPIObjectCompatible.Type) throws -> NAPIValueCompatible? {
        do {
            if case .object(_) = self.napiValueType {
                let value = try self.asObject(ofType: targetType)
                return value
            } else {
                // not an object
                fatalError("This funciton should not be called for non-object NAPIValueTypes")
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asArrayOfNAPIValueCompatible(elementNapiValueType: NAPIValueType) throws -> [Any]? {
        do {
            // TODO: use this same "case" and "let" combo (case before ".", let in the parens) EVERYWHERE in our code...for consistency
            if case .array(_) = self.napiValueType {
                if let valueAsNAPIValueCompatible = try self.asArray(elementNapiValueType: elementNapiValueType) {
                    return valueAsNAPIValueCompatible
                } else {
                    return nil
                }
            } else {
                // not an array
                fatalError("This funciton should not be called for non-array NAPIValueTypes")
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asBool() throws -> Bool? {
        do {
            switch self.napiValueType {
            case .boolean:
                let valueAsBool = try self.convertCNapiValueToBool()
                return valueAsBool
            case .number:
                return nil
            case .string:
                return nil
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                return nil
            case .array(_):
                return nil
            case .function:
                return nil
            case .error:
                return nil 
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asDouble() throws -> Double? {
        do {
            switch self.napiValueType {
            case .boolean:
                let valueAsBool = try self.convertCNapiValueToBool()
                return valueAsBool ? 1.0 : 0.0
            case .number:
                let valueAsDouble = try self.convertCNapiValueToDouble()
                return valueAsDouble
            case .string:
                let valueAsString = try self.convertCNapiValueToString()
                return Double(valueAsString)
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                return nil
            case .array(_):
                return nil
            case .function:
                return nil
            case .error:
                return nil
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asString() throws -> String? {
        do {
            switch self.napiValueType {
            case .boolean:
                let valueAsBool = try self.convertCNapiValueToBool()
                return String(valueAsBool)
            case .number:
                let valueAsDouble = try self.convertCNapiValueToDouble()
                return String(valueAsDouble)
            case .string:
                let valueAsString = try self.convertCNapiValueToString()
                return valueAsString
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                return nil
            case .array(_):
                return nil
            case .function:
                return nil
            case .error:
                return nil
            case .undefined:
                return nil
            case .unsupported:
                return nil 
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asArray(elementNapiValueType: NAPIValueType) throws -> [Any]? {
        do {
            switch self.napiValueType {
            case .boolean:
                return nil
            case .number:
                return nil
            case .string:
                return nil
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                return nil
            case .array(let elementNAPIValueType):
                if let elementNAPIValueType = elementNAPIValueType {
                    let valueAsArray = try self.convertCNapiValueToArray(elementNapiValueType: elementNAPIValueType)
                    return valueAsArray
                } else {
                    return []
                }
            case .function:
                return nil 
            case .error:
                return nil
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asArrayOfNapiValues() throws -> [NAPIValue]? {
        do {
            switch self.napiValueType {
            case .boolean:
                return nil
            case .number:
                return nil
            case .string:
                return nil
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                return nil
            case .array(_):
                let valueAsArrayOrNapiValues = try self.convertCNapiValueToArrayOfNapiValues()
                return valueAsArrayOrNapiValues
            case .function:
                return nil
            case .error:
                return nil
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asObject(ofType targetType: NAPIObjectCompatible.Type) throws -> NAPIValueCompatible? {
        do {
            switch self.napiValueType {
            case .boolean:
                return nil
            case .number:
                return nil
            case .string:
                return nil
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                let valueAsObject = try self.convertCNapiValueToObject(ofType: targetType)
                return valueAsObject
            case .array(_):
                return nil
            case .function:
                return nil
            case .error:
                return nil
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asJavaScriptFunction() throws -> NAPIValueCompatible? {
        do {
            switch self.napiValueType {
            case .boolean:
                return nil
            case .number:
                return nil
            case .string:
                return nil
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                return nil
            case .array(_):
                return nil
            case .function:
                let valueAsFunction = try self.convertCNapiValueToFunction()
                return valueAsFunction
            case .error:
                return nil 
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asJavaScriptError() throws -> NAPIValueCompatible? {
        do {
            switch self.napiValueType {
            case .boolean:
                return nil
            case .number:
                return nil
            case .string:
                return nil
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                return nil
            case .array(_):
                return nil
            case .function:
                return nil
            case .error:
                let valueAsError = try self.convertCNapiValueToError()
                return valueAsError
            case .undefined:
                return nil
            case .unsupported:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPISwiftBridgeJavaScriptThrowableError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    // MARK: Conversion functions

    private func convertCNapiValueToBool() throws -> Bool {
        guard self.napiValueType == .boolean else {
            throw NAPIValueError.typeMismatch
        }

        var status: napi_status
        var valueAsBoolean: Bool = false
        //
        status = napi_get_value_bool(self.cNapiEnv, self.cNapiValue, &valueAsBoolean)
        guard status == napi_ok else {
            if status == napi_boolean_expected {
                // type mismatch
                // TODO: we should still check for a JavaScript exception
                throw NAPIValueError.typeMismatch
            } else {
                // TODO: we should check for a JavaScript exception
                throw NAPIValueError.otherNapiError
            }
        }

        return valueAsBoolean
    }

    private func convertCNapiValueToDouble() throws -> Double {
        guard self.napiValueType == .number else {
            throw NAPIValueError.typeMismatch
        }

        var status: napi_status
        var valueAsDouble: Double = 0
        //
        status = napi_get_value_double(self.cNapiEnv, self.cNapiValue, &valueAsDouble)
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
    
    private func convertCNapiValueToString() throws -> String {
        guard self.napiValueType == .string else {
            throw NAPIValueError.typeMismatch
        }

        var status: napi_status
        
        var bufferSize = 0
        
        // first, get the size of the string; we do this by passing in a nil buffer (and then we get the size from its 'result' parameter)
        var requiredBufferSize: Int = 0
        status = napi_get_value_string_utf8(self.cNapiEnv, self.cNapiValue, nil, 0, &requiredBufferSize)
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
        status = napi_get_value_string_utf8(self.cNapiEnv, self.cNapiValue, buffer, bufferSize, &populatedBufferSize)
        guard status == napi_ok else {
            // TODO: we should check for a JavaScript exception
            throw NAPIValueError.otherNapiError
        }
        
        return String(cString: buffer)
    }
    
    private func convertCNapiValueToObject(ofType targetType: NAPIObjectCompatible.Type) throws -> NAPIValueCompatible {
        // verify that our napiValueType is an object type
        guard case .object(let napiPropertyNamesAndTypes, let swiftType) = self.napiValueType else {
            throw NAPIValueError.typeMismatch
        }
        // verify that our napiValueType's swiftType (if one is provided) matches the provided targetType
        if let swiftType = swiftType {
            guard swiftType.self == type(of: targetType).self else {
                throw NAPIValueError.typeMismatch
            }
        }

        let swiftPropertyNamesAndTypes = targetType.NAPIPropertyNamesAndTypes
        
        // verify that our NAPIValue's properties and the target swift type's properties are compatible
        if napiPropertyNamesAndTypes.count != swiftPropertyNamesAndTypes.count {
            fatalError("NAPI argument count \(napiPropertyNamesAndTypes.count) does not match native argument count \(napiPropertyNamesAndTypes.count)")
        }
        for napiPropertyNameAndType in napiPropertyNamesAndTypes {
            let napiPropertyName = napiPropertyNameAndType.key
            let napiPropertyNapiValueType = napiPropertyNameAndType.value

            if swiftPropertyNamesAndTypes.keys.contains(napiPropertyName) == false {
                fatalError("NAPI property \(napiPropertyName) does not exist in Swift object.")
            }
            let swiftPropertyNapiValueType = swiftPropertyNamesAndTypes[napiPropertyName]!
            
            if napiPropertyNapiValueType.isCompatible(withRhs: swiftPropertyNapiValueType, disregardRhsOptionals: true) == false {
                fatalError("Type mismatch: NAPI property type is incompatible with Swift property type for property \(napiPropertyNameAndType.key).")
            }
        }
        
        // build up a set of property names (with their associated values) as we deecode the underlying napi_value
        var propertyNamesAndValues: [String: Any] = [:]
        
        var status: napi_status
        
        for propertyNameAndType in napiPropertyNamesAndTypes {
            // get the property name
            let propertyName = propertyNameAndType.key
            // NOTE: we do not retrieve the propertyNameAndType's value (i.e. the property's NAPIValueType) because the decoder validates that the property types match instead; this is necessary because of type comformance limitations in Swift.  We could choose to verify against non-array types, but using the decoder provides a single path for type match validation
//            // retrieve the property's NAPIValueType (to verify for compatibility against the actual property's NAPIValueType)
//            let propertyNapiValueType = propertyNameAndType.value
            
            let propertyNameAsNapiValue = NAPIValue.create(cNapiEnv: cNapiEnv, nativeValue: propertyName)
            
            // get the property's associated value (initially as a napi_value but then converted into a Swift type)
            var propertyValueAsCNapiValue: napi_value! = nil
            status = napi_get_property(cNapiEnv, self.cNapiValue, propertyNameAsNapiValue.cNapiValue, &propertyValueAsCNapiValue)
            guard status == napi_ok else {
                // TODO: check for JavaScript errors instead and throw them instead
                fatalError()
            }
            // NOTE: we use "Any" as our type here because .asArrayOfNAPIValueCompatible(...) must return a result of type Any because Swift cannot return an array of NAPIValueCompatible-conformant objects via cast to NAPIValueCompatible
            var propertyValueAsOptionalNapiValueCompatible: Any
            do {
                switch swiftPropertyNamesAndTypes[propertyName] {
                case .object(_, let propertySwiftType):
                    // object type
                    if let propertySwiftType = propertySwiftType {
                        propertyValueAsOptionalNapiValueCompatible = try NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: propertyValueAsCNapiValue).asNAPIValueCompatibleObject(ofType: propertySwiftType) as Any
                    } else {
                        fatalError("Swift type must be specified for Swift property \(propertyName); found: nil")
                    }
                case .array(let elementNapiValueType):
                    // array type
                    if let elementNapiValueType = elementNapiValueType {
                        propertyValueAsOptionalNapiValueCompatible = try NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: propertyValueAsCNapiValue).asArrayOfNAPIValueCompatible(elementNapiValueType: elementNapiValueType) as Any
                    } else {
                        // if elementNapiValueType is nil, then the array is empty
                        propertyValueAsOptionalNapiValueCompatible = []
                    }
                default:
                    propertyValueAsOptionalNapiValueCompatible = try NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: propertyValueAsCNapiValue).asNAPIValueCompatible() as Any
                }
            } catch (let error) {
                throw error
            }
            // TODO: does this really test for nil?  Or do we need to do "== nil" check, etc?
            if case Optional<Any>.none = propertyValueAsOptionalNapiValueCompatible {
                // value is nil
                propertyNamesAndValues[propertyName] = nil 
            } else {
                propertyNamesAndValues[propertyName] = propertyValueAsOptionalNapiValueCompatible
            }
        }

        // create an instance of the target type by using our NAPIBridgingDecoder combined with Decodable's auto-compiler-generated "init" function
        // NOTE: in the future, if Swift allows us to dynamically generate our own class properties in compiled code on the fly (as it does for Encodable), we can remove the need for Swift struct creators to manually describe their struct's properties' types
        let decoder = NAPIBridgingDecoder(propertyNamesAndValues: propertyNamesAndValues)
        do {
            let result = try targetType.init(from: decoder)
            return result
        } catch let error {
            // TODO: catch the actual Decodable error and pass it along (or at least log/display it properly)
            fatalError("Type mismatch or other error \(error)")
        }
    }
    
    private func convertCNapiValueToArray(elementNapiValueType: NAPIValueType) throws -> [Any] {
        let selfAsArrayOfNapiValues: [NAPIValue]
        do {
            selfAsArrayOfNapiValues = try self.convertCNapiValueToArrayOfNapiValues()
        } catch (let error) {
            throw error
        }
        
        var selfAsArray: [Any] = []
        selfAsArray.reserveCapacity(selfAsArrayOfNapiValues.count)
        //
        for napiValue in selfAsArrayOfNapiValues {
            let element: Any?
            switch elementNapiValueType {
            case .object(_, let propertySwiftType):
                // object type
                if let propertySwiftType = propertySwiftType {
                    element = try napiValue.asNAPIValueCompatibleObject(ofType: propertySwiftType)
                } else {
                    fatalError("Swift type must be specified for array elements' native objects; found: nil")
                }
            case .array(let elementNapiValueType):
                // array type
                if let elementNapiValueType = elementNapiValueType {
                    element = try napiValue.asArrayOfNAPIValueCompatible(elementNapiValueType: elementNapiValueType)
                } else {
                    // if elementNapiValueType is nil, then the array is empty
                    element = []
                }
            default:
                element = try napiValue.asNAPIValueCompatible()
            }

            if let element = element {
                selfAsArray.append(element)
            } else {
                // if we could not convert the value, throw an error
                throw NAPIValueError.otherNapiError
            }
        }
        
        return selfAsArray
    }
    
    private func convertCNapiValueToArrayOfNapiValues() throws -> Array<NAPIValue> {
        guard case .array(_) = self.napiValueType else {
            throw NAPIValueError.typeMismatch
        }
                
        var status: napi_status
        
        var valueAsArrayOfNapiValues: Array<NAPIValue> = []
        //
        // capture the array length
        var arrayLength: UInt32 = 0
        status = napi_get_array_length(self.cNapiEnv, self.cNapiValue, &arrayLength)
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
        valueAsArrayOfNapiValues.reserveCapacity(arrayLengthAsInt)
        // capture each array element
        for indexAsUInt32 in 0..<arrayLength {
            var elementAsCNapiValue: napi_value! = nil
            status = napi_get_element(self.cNapiEnv, self.cNapiValue, indexAsUInt32, &elementAsCNapiValue)
            guard status == napi_ok, elementAsCNapiValue != nil else {
                if status == napi_array_expected {
                    // type mismatch
                    // TODO: we should still check for a JavaScript exception
                    throw NAPIValueError.typeMismatch
                } else {
                    // TODO: we should check for a JavaScript exception
                    throw NAPIValueError.otherNapiError
                }
            }

            let element = NAPIValue(cNapiEnv: self.cNapiEnv, cNapiValue: elementAsCNapiValue)
            valueAsArrayOfNapiValues.append(element)
        }
        
        return valueAsArrayOfNapiValues
    }
    
    private func convertCNapiValueToFunction() throws -> NAPIJavaScriptFunction {
        guard case .function = self.napiValueType else {
            throw NAPIValueError.typeMismatch
        }

        return NAPIJavaScriptFunction(cNapiEnv: self.cNapiEnv, cNapiValue: self.cNapiValue)
    }
    
    private func convertCNapiValueToError() throws -> NAPIJavaScriptError {
        guard case .error = self.napiValueType else {
            throw NAPIValueError.typeMismatch
        }

        var status: napi_status

        // capture the error name
        let namePropertyKeyAsCNapiValue = NAPIValue.create(cNapiEnv: self.cNapiEnv, nativeValue: "name").cNapiValue
        //
        var namePropertyValueAsOptionalCNapiValue: napi_value?
        status = napi_get_property(self.cNapiEnv, self.cNapiValue, namePropertyKeyAsCNapiValue, &namePropertyValueAsOptionalCNapiValue)
        guard status == napi_ok else {
            fatalError("Could not get value of property 'name' of argument 'errorAsCNapiValue'")
        }
        guard let namePropertyValueAsOptional = try? NAPIValue(cNapiEnv: self.cNapiEnv, cNapiValue: namePropertyValueAsOptionalCNapiValue!).asString() else {
            fatalError("Could not get value of property 'name' of argument 'errorAsCNapiValue'")
        }
        guard let namePropertyValue = namePropertyValueAsOptional else {
            fatalError("Could not get value of property 'name' of argument 'errorAsCNapiValue'")
        }

        switch namePropertyValue {
        case "Error",
             "TypeError",
             "RangeError":
            //
            guard let namePropertyValueAsNameOption = NAPIJavaScriptError.NameOption(rawValue: namePropertyValue) else {
                fatalError("Invalid code path: all namePropertyValue options should have satisfied this test")
            }
            
            // capture the error message
            let messagePropertyKeyAsCNapiValue = NAPIValue.create(cNapiEnv: self.cNapiEnv, nativeValue: "message").cNapiValue
            //
            var errorHasMessageProperty: Bool = false
            status = napi_has_property(self.cNapiEnv, self.cNapiValue, messagePropertyKeyAsCNapiValue, &errorHasMessageProperty)
            guard status == napi_ok else {
                fatalError("Could not determine if argument 'errorAsCNapiValue' has property 'message'")
            }
            guard errorHasMessageProperty == true else {
                fatalError("Argument 'errorAsCNapiValue' is missing required property 'message'")
            }
            //
            var messagePropertyValueAsOptionalCNapiValue: napi_value?
            status = napi_get_property(self.cNapiEnv, self.cNapiValue, messagePropertyKeyAsCNapiValue, &messagePropertyValueAsOptionalCNapiValue)
            guard status == napi_ok else {
                fatalError("Could not get value of property 'message' of argument 'errorAsCNapiValue'")
            }
            guard let messagePropertyValueAsOptional = try? NAPIValue(cNapiEnv: self.cNapiEnv, cNapiValue: messagePropertyValueAsOptionalCNapiValue!).asString() else {
                fatalError("Could not get value of property 'message' of argument 'errorAsCNapiValue'")
            }
            guard let messagePropertyValue = messagePropertyValueAsOptional else {
                fatalError("Could not get value of property 'message' of argument 'errorAsCNapiValue'")
            }

            // capture the (optional) error code (optionally used by N-API)
            let codePropertyKeyAsCNapiValue = NAPIValue.create(cNapiEnv: self.cNapiEnv, nativeValue: "code").cNapiValue
            //
            var errorHasCodeProperty: Bool = false
            status = napi_has_property(self.cNapiEnv, self.cNapiValue, codePropertyKeyAsCNapiValue, &errorHasCodeProperty)
            guard status == napi_ok else {
                fatalError("Could not determine if argument 'errorAsCNapiValue' has property 'code'")
            }
            //
            var codePropertyValueAsOptional: String? = nil
            if errorHasCodeProperty == true {
                var codePropertyValueAsOptionalCNapiValue: napi_value?
                status = napi_get_property(self.cNapiEnv, self.cNapiValue, codePropertyKeyAsCNapiValue, &codePropertyValueAsOptionalCNapiValue)
                guard status == napi_ok else {
                    fatalError("Could not get value of property 'code' of argument 'errorAsCNapiValue'")
                }
                guard let codePropertyValueAsNonOptional = try? NAPIValue(cNapiEnv: self.cNapiEnv, cNapiValue: codePropertyValueAsOptionalCNapiValue!).asString() else {
                    fatalError("Could not get value of property 'code' of argument 'errorAsCNapiValue'")
                }
                codePropertyValueAsOptional = codePropertyValueAsNonOptional
            }
            
            return NAPIJavaScriptError(name: namePropertyValueAsNameOption, message: messagePropertyValue, code: codePropertyValueAsOptional)
        default:
            // TODO: throw "rangeError" indicating that we cannot handle this type of error
            fatalError("Unknown error type")
        }
    }
}
