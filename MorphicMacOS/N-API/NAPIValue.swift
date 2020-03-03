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
    
    // NOTE: if a napiValueType of .nullable(...) is provided the function will either return a ".nullable(nil)" or a NAPIValue of the wrapped type
    public static func create(env: napi_env, nativeValue: Any, napiValueType: NAPIValueType) -> NAPIValue {
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
            return createBoolean(env: env, nativeValue: nativeValue as! Bool)
        case .number:
            return createNumber(env: env, nativeValue: nativeValue as! Double)
        case .string:
            return createString(env: env, nativeValue: nativeValue as! String)
        case .nullable(let napiValueTypeOfWrapped):
            if napiValueTypeOfWrapped != nil {
                if case Optional<Any>.none = nativeValue {
                    // if we have a wrapped type but the value is nil, return a JavaScript null
                    return createNull(env: env)
                } else {
                    // if the value is non-nil, return the appropriate JavaScript type
                    return create(env: env, nativeValue: nativeValue, napiValueType: napiValueTypeOfWrapped!)
                }
            } else {
                // if we don't have a type then return null
                return createNull(env: env)
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
            return createObject(env: env, nativeValue: nativeValueAsNapiObjectCompatible, ofType: swiftType)
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

    private static func createBoolean(env: napi_env, nativeValue: Bool) -> NAPIValue {
        var result: napi_value! = nil
        
        // NOTE: napi_get_boolean gets the JavaScript boolean singleton (true or false)
        let status = napi_get_boolean(env, nativeValue, &result)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        return NAPIValue(env: env, napiValue: result)
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

    private static func createNull(env: napi_env) -> NAPIValue {
        var result: napi_value! = nil
        
        // NOTE: napi_get_boolean gets the JavaScript null singleton
        let status = napi_get_null(env, &result)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        return NAPIValue(env: env, napiValue: result)
    }
    
    private static func createObject(env: napi_env, nativeValue: NAPIObjectCompatible, ofType targetType: NAPIObjectCompatible.Type) -> NAPIValue {
        var result: napi_value! = nil
        
        var status = napi_create_object(env, &result)
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
            
            let propertyNameAsNapiValue = NAPIValue.create(env: env, nativeValue: propertyName, napiValueType: .string)

            let propertyAsCNapiValue: napi_value
            if case Optional<Any>.none = propertyValue {
                propertyAsCNapiValue = createNull(env: env).napiValue
            } else {
                guard let propertyValueAsNapiValueCompatible = propertyValue as? NAPIValueCompatible else {
                    fatalError("Property \(propertyName) is not a NAPIValueCompatible type")
                }
                let napiValueTypeOfPropertyValue = type(of: propertyValueAsNapiValueCompatible).napiValueType
                propertyAsCNapiValue = NAPIValue.create(env: env, nativeValue: propertyValueAsNapiValueCompatible, napiValueType: napiValueTypeOfPropertyValue).napiValue
            }

            status = napi_set_property(env, result, propertyNameAsNapiValue.napiValue, propertyAsCNapiValue)
            guard status == napi_ok else {
                // TODO: check for JavaScript errors instead and throw them instead
                fatalError()
            }
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
            // TODO: handle this error...or convert it into a NAPIJavaScriptError and throw it instead
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
            // TODO: handle this error...or convert it into a NAPIJavaScriptError and throw it instead
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
                let valueAsBool = try self.convertNapiValueToBool()
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
            case .boolean:
                let valueAsBool = try self.convertNapiValueToBool()
                return valueAsBool ? 1.0 : 0.0
            case .number:
                let valueAsDouble = try self.convertNapiValueToDouble()
                return valueAsDouble
            case .string:
                let valueAsString = try self.convertNapiValueToString()
                return Double(valueAsString)
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                return nil
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
            case .boolean:
                let valueAsBool = try self.convertNapiValueToBool()
                return String(valueAsBool)
            case .number:
                let valueAsDouble = try self.convertNapiValueToDouble()
                return String(valueAsDouble)
            case .string:
                let valueAsString = try self.convertNapiValueToString()
                return valueAsString
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "NAPIValues of type .nullable(...) should only be mapped to null itself.")
                return nil
            case .object:
                return nil
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
                    let valueAsArray = try self.convertNapiValueToArray(elementNapiValueType: elementNAPIValueType)
                    return valueAsArray
                } else {
                    return []
                }
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
                let valueAsArrayOrNapiValues = try self.convertNapiValueToArrayOfNapiValues()
                return valueAsArrayOrNapiValues
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
                let valueAsObject = try self.convertNapiValueToObject(ofType: targetType)
                return valueAsObject
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
    
    // MARK: Conversion functions

    private func convertNapiValueToBool() throws -> Bool {
        guard self.napiValueType == .boolean else {
            throw NAPIValueError.typeMismatch
        }

        var status: napi_status
        var valueAsBoolean: Bool = false
        //
        status = napi_get_value_bool(self.env, self.napiValue, &valueAsBoolean)
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
    
    private func convertNapiValueToObject(ofType targetType: NAPIObjectCompatible.Type) throws -> NAPIValueCompatible {
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
            
            let propertyNameAsNapiValue = NAPIValue.create(env: env, nativeValue: propertyName)
            
            // get the property's associated value (initially as a napi_value but then converted into a Swift type)
            var propertyValueAsCNapiValue: napi_value! = nil
            status = napi_get_property(env, self.napiValue, propertyNameAsNapiValue.napiValue, &propertyValueAsCNapiValue)
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
                        propertyValueAsOptionalNapiValueCompatible = try NAPIValue(env: env, napiValue: propertyValueAsCNapiValue).asNAPIValueCompatibleObject(ofType: propertySwiftType)
                    } else {
                        fatalError("Swift type must be specified for Swift property \(propertyName); found: nil")
                    }
                case .array(let elementNapiValueType):
                    // array type
                    if let elementNapiValueType = elementNapiValueType {
                        propertyValueAsOptionalNapiValueCompatible = try NAPIValue(env: env, napiValue: propertyValueAsCNapiValue).asArrayOfNAPIValueCompatible(elementNapiValueType: elementNapiValueType)
                    } else {
                        // if elementNapiValueType is nil, then the array is empty
                        propertyValueAsOptionalNapiValueCompatible = []
                    }
                default:
                    propertyValueAsOptionalNapiValueCompatible = try NAPIValue(env: env, napiValue: propertyValueAsCNapiValue).asNAPIValueCompatible()
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
    
    private func convertNapiValueToArray(elementNapiValueType: NAPIValueType) throws -> [Any] {
        let selfAsArrayOfNapiValues: [NAPIValue]
        do {
            selfAsArrayOfNapiValues = try self.convertNapiValueToArrayOfNapiValues()
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
    
    private func convertNapiValueToArrayOfNapiValues() throws -> Array<NAPIValue> {
        guard case .array(_) = self.napiValueType else {
            throw NAPIValueError.typeMismatch
        }
                
        var status: napi_status
        
        var valueAsArrayOfNapiValues: Array<NAPIValue> = []
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
        valueAsArrayOfNapiValues.reserveCapacity(arrayLengthAsInt)
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

            let element = NAPIValue(env: self.env, napiValue: elementAsNapiValue)
            valueAsArrayOfNapiValues.append(element)
        }
        
        return valueAsArrayOfNapiValues
    }
    
    // MARK: Object bridging protocols/functions

    private struct NAPIBridgingKeyedDecodingContainerProtocol<Key: CodingKey>: KeyedDecodingContainerProtocol {
        var codingPath: [CodingKey] = []
        
        var allKeys: [Key] = []
        
        let propertyNamesAndValues: [String: Any]
        
        init(propertyNamesAndValues: [String: Any]) {
            self.propertyNamesAndValues = propertyNamesAndValues
        }
        
        func contains(_ key: Key) -> Bool {
            return self.propertyNamesAndValues.keys.contains(key.stringValue)
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            let keyAsString = key.stringValue

            // capture the value (if the property exists)
            if self.propertyNamesAndValues.keys.contains(keyAsString) == false {
                throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "Property \(keyAsString) cannot be initialized because it was not provided."))
            }
            let value = self.propertyNamesAndValues[keyAsString]

            if case Optional<Any>.none = value {
                // value is nil
                return true
            } else {
                // value is not nil
                return false
            }
        }
        
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            return try innerDecode(nativeType: type, napiValueType: .boolean, forKey: key) as! Bool
        }
        
        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            return try innerDecode(nativeType: type, napiValueType: .string, forKey: key) as! String
        }
        
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            return try innerDecode(nativeType: type, napiValueType: .number, forKey: key) as! Double
        }
        
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            fatalError("NOT SUPPORTED")
        }
        
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            fatalError("NOT SUPPORTED")
        }
        
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            fatalError("NOT SUPPORTED")
        }
        
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            fatalError("NOT SUPPORTED")
        }
        
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            fatalError("NOT SUPPORTED")
        }
        
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            fatalError("NOT SUPPORTED")
        }
        
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            fatalError("NOT SUPPORTED")
        }
        
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            fatalError("NOT SUPPORTED")
        }
        
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            fatalError("NOT SUPPORTED")
        }
        
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            fatalError("NOT SUPPORTED")
        }
        
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            fatalError("NOT SUPPORTED")
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            guard let typeAsNapiValueType = (type as? NAPIValueCompatible.Type)?.napiValueType else {
                throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Property \(key.stringValue) cannot be initialized with a value of type \(T.Type.self)"))
            }
            
            return try innerDecode(nativeType: type, napiValueType: typeAsNapiValueType, forKey: key) as! T
        }
        
        // NOTE: this function returns the requested type (or throws an error if the property is missing or the type is mismatched
        private func innerDecode(nativeType: Any.Type, napiValueType: NAPIValueType, forKey key: Key) throws -> Any? {
            let keyAsString = key.stringValue

            // capture the value (if the property exists)
            if self.propertyNamesAndValues.keys.contains(keyAsString) == false {
                throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Property \(keyAsString) cannot be initialized because it is missing."))
            }
            let value = self.propertyNamesAndValues[keyAsString]

            let nativeTypeAsNapiValueType: NAPIValueType
            // verify that the type is a NAPIValueCompatible type
            guard let nativeTypeAsNapiValueCompatibleType = nativeType as? NAPIValueCompatible.Type else {
                throw DecodingError.typeMismatch(nativeType, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Property \(keyAsString) cannot be initialized with a value of type \(nativeType.self)"))
            }
            nativeTypeAsNapiValueType = nativeTypeAsNapiValueCompatibleType.napiValueType
            
            if nativeTypeAsNapiValueType.isCompatible(withRhs: napiValueType, disregardRhsOptionals: true) {
                return value
            } else {
                throw DecodingError.typeMismatch(nativeType, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Property \(keyAsString) cannot be initialized with a value of type \(nativeType.self)"))
            }
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError("NOT IMPLEMENTED")
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            fatalError("NOT IMPLEMENTED")
        }
        
        func superDecoder() throws -> Decoder {
            fatalError("NOT IMPLEMENTED")
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            fatalError("NOT IMPLEMENTED")
        }
    }

    private struct NAPIBridgingDecoder: Decoder {
        var codingPath: [CodingKey] = []
        
        var userInfo: [CodingUserInfoKey : Any] = [:]
        
        let propertyNamesAndValues: [String: Any]
        
        init(propertyNamesAndValues: [String: Any]) {
            self.propertyNamesAndValues = propertyNamesAndValues
        }
        
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
            return KeyedDecodingContainer(NAPIBridgingKeyedDecodingContainerProtocol(propertyNamesAndValues: propertyNamesAndValues))
        }
        
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            fatalError("NOT IMPLEMENTED")
        }
        
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            fatalError("NOT IMPLEMENTED")
        }
    }
}
