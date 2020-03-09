//
// NAPIFunctionHelpers.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

import Foundation

// MARK: - Bridge function types

// NOTE: NAPISwiftBridgeFunction functions emulate a "Void" return by returning "nil"
// NOTE: NAPISwiftBridgeFunctions are only allowed to throw NAPISwiftBridgeJavaScriptThrowableError (which map to JavaScript Errors)
typealias NAPISwiftBridgeFunction = (_ cNapiEnv: napi_env, _ args: [Any?]) throws -> Any?

// NAPIFunctionData is an internal structure associated with NAPI function callbacks
class NAPIFunctionData {
    let swiftBridgeFunction: NAPISwiftBridgeFunction
    let argumentTypes: [NAPIValueType]
    let returnType: NAPIValueType?

    init(swiftBridgeFunction: @escaping NAPISwiftBridgeFunction, argumentTypes: [NAPIValueType], returnType: NAPIValueType?) {
        self.swiftBridgeFunction = swiftBridgeFunction
        self.argumentTypes = argumentTypes
        self.returnType = returnType
    }
}

let maximumArgumentsInNativeFunctions = 3

// MARK: - Trampoline for native function callbacks

// NOTE: according to N-API documentation, a default handle scope exists when our native function is called from JavaScript,
//       and that scope is tied to the lifespan of the native method call (at which point napi_values are marked for GC)
// NOTE: native functions emulate a "Void" return by returning nil (which will return "undefined" via JavaScript
internal func napiFunctionTrampoline(_ cNapiEnv: napi_env!, _ cNapiCallbackInfo: napi_callback_info!) -> napi_value? {
    // NOTE: info should never be nil; this is just a precaution for debug-time sanity
    assert(cNapiCallbackInfo != nil, "Argument 'cNapiCallbackInfo' may not be nil.")

    var status: napi_status

    let pointerToPointerToNapiFunctionData = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 1)
    //
    // capture up to the maximum number of arguments allowed in our native functions
    var numberOfArguments: Int = maximumArgumentsInNativeFunctions
    //
    // NOTE: althtough the arguments are returned as optional napi_values, they are indeed non-nil (unless an error occured)
    let pointerToArgumentsAsCNapiValues = UnsafeMutablePointer<napi_value?>.allocate(capacity: numberOfArguments)
    //
    var pointerToThisArgumentAsCNapiValue: napi_value? = nil

    /* retrieve the callback function info (e.g. indirect pointer to NAPIFunctionData, array of passed-in arguments a,nd the implicit 'this' argument) */
    
    // NOTE: numberOfArguments is an in/out parameter: we pass in the maximum number of arguments we support and it returns the actual number of arguments populated at pointerToArguments
    // NOTE: if the maximum argument count we pass in is not high enough, we will not get all the passed-in arguments; the "maximumNativeFunctionArgumentCount" must therefore be synced with the maximum allowable number of function arguments
    status = napi_get_cb_info(cNapiEnv, cNapiCallbackInfo, &numberOfArguments, pointerToArgumentsAsCNapiValues, &pointerToThisArgumentAsCNapiValue, pointerToPointerToNapiFunctionData)
    guard status == napi_ok else {
        return nil
    }

    /* capture the NAPIFunctionData we created when we set up this callback (so we know which function to call, the required parameter types and the return type) */
    
    guard let pointerToNapiFunctionData = pointerToPointerToNapiFunctionData.pointee else {
        // NOTE: we should never _not_ get a pointer to our NAPIFunctionData; this would indicate a shutdown/corruption/programming issue
        // TODO: throw an error
        return nil
    }
    let napiFunctionData = Unmanaged<NAPIFunctionData>.fromOpaque(pointerToNapiFunctionData).takeUnretainedValue()
    
    /* type-check the passed-in arguments and convert them to their respective native-code types */
    
    let argumentsAsCNapiValues = Array(UnsafeBufferPointer(start: pointerToArgumentsAsCNapiValues, count: numberOfArguments))
    var arguments: [Any?] = []

    guard argumentsAsCNapiValues.count >= napiFunctionData.argumentTypes.count else {
        // TODO: consider throwing an error (although it might be better to error out so that the programmer can fix the issue immediately)
        fatalError("Not enough arguments were provided. Received: \(argumentsAsCNapiValues.count); Expected: \(napiFunctionData.argumentTypes.count)")
    }

    for index in 0..<napiFunctionData.argumentTypes.count {
        guard let argumentAsCNapiValue = argumentsAsCNapiValues[index] else {
            // NOTE: arguments should not be nil (as there is a napi_value for "null")
            // TODO: throw an error
            return nil
        }
        let napiValueTypeOfArgument = NAPIValueType.getNAPIValueType(cNapiEnv: cNapiEnv, cNapiValue: argumentAsCNapiValue)
        
        // if the napiValueTypeOfArgument of the argument is 'undefined', we have encountered a filler argument (which means
        // that the caller did not provide enough arguments for the function
        if napiValueTypeOfArgument == .undefined {
            // not enough arguments were passed by the caller
            // TODO: throw an error
            return nil
        }
                
        // verify that the type of the passsed-in argument matches the strictly-typed native function argument type
        if napiValueTypeOfArgument == NAPIValueType.array(type: nil) {
            // if the parameter is any typed array, an empty array from JavaScript is valid
            if case .array(_) = napiFunctionData.argumentTypes[index] {
                // an empty JavaScript array matches any typed Swift array
            } else {
                // an empty array does not match any other type
                // TODO: throw a Type Mismatch error
                return nil
            }
        } else {
            // for any argument which is not an empty array, verify the strict typing
            // NOTE: we set disregardRhsOptionals to true so that non-optional incoming values will match argument types which allow nulls
            guard napiValueTypeOfArgument.isCompatible(withRhs: napiFunctionData.argumentTypes[index], disregardRhsOptionals: true) else {
                // TODO: consider throwing an error (although it might be better to error out so that the programmer can fix the issue immediately)
                fatalError("Argument \(index) is the wrong type. Received: \(napiValueTypeOfArgument); Expected: \(napiFunctionData.argumentTypes[index])")
            }
        }
        
        // convert the napi_value to a NAPIValue type (and then use the NAPIValue to convert the napi_value to its corresponding native type respresentation)
        do {
            let argument = try convertCNapiValueToNativeValue(cNapiEnv: cNapiEnv, cNapiValue: argumentAsCNapiValue, targetNapiValueType: napiFunctionData.argumentTypes[index])
            arguments.append(argument)
        } catch {
            // TODO: capture JavaScript error (if one was created by N-API during the conversion process)
        }
    }
    
    /* call the native function (and capture its return value, if any) */
    let napiAutoLengthAsInt = Int(bitPattern: NAPI_AUTO_LENGTH)

    var result: Any?
    do {
        result = try napiFunctionData.swiftBridgeFunction(cNapiEnv, arguments)
    } catch NAPISwiftBridgeJavaScriptThrowableError.value(let napiValueCompatibleToThrow) {
        // thow the provided JavaScript value
        let throwableAsNapiValue = NAPIValue.create(cNapiEnv: cNapiEnv, nativeValue: napiValueCompatibleToThrow, napiValueType: type(of: napiValueCompatibleToThrow).napiValueType)
        status = napi_throw(cNapiEnv, throwableAsNapiValue.cNapiValue)
        guard status == napi_ok else {
            // NOTE: if we cannot create/throw the value, we just log the problem
            NSLog("SwiftNAPIBridge: Could not throw (value: \(napiValueCompatibleToThrow))")
            return nil
        }
        //
        return nil
    } catch NAPISwiftBridgeJavaScriptThrowableError.error(let message, let code) {
        // thow the provided error (message and code)
        status = napi_throw_error(cNapiEnv, code, message)
        guard status == napi_ok else {
            // NOTE: if we cannot create/throw the error, we just log the problem
            NSLog("SwiftNAPIBridge: Could not throw Error (message: \(message), code: \(String(describing: code)))")
            return nil
        }
        //
        return nil
    } catch NAPISwiftBridgeJavaScriptThrowableError.typeError(let message, let code) {
        // thow the provided typeError (message and code)
        status = napi_throw_type_error(cNapiEnv, code, message)
        guard status == napi_ok else {
            // NOTE: if we cannot create/throw the typeError, we just log the problem
            NSLog("SwiftNAPIBridge: Could not throw TypeError (message: \(message), code: \(String(describing: code)))")
            return nil
        }
        //
        return nil
    } catch NAPISwiftBridgeJavaScriptThrowableError.rangeError(let message, let code) {
        // thow the provided rangeError (message and code)
        status = napi_throw_range_error(cNapiEnv, code, message)
        guard status == napi_ok else {
            // NOTE: if we cannot create/throw the rangeError, we just log the problem
            NSLog("SwiftNAPIBridge: Could not throw RangeError (message: \(message), code: \(String(describing: code)))")
            return nil
        }
        //
        return nil
    } catch NAPISwiftBridgeJavaScriptThrowableError.fatalError(let message, let location) {
        // thow the provided fatalError (message and location)
        //
        // NOTE: napi_fatal_error does not return, so no "return" is necessary
        napi_fatal_error(location, location == nil ? 0 : napiAutoLengthAsInt, message, napiAutoLengthAsInt)
    } catch let error {
        // if any other throwable was thrown, this is a programming error
        let message = "Unknown Swift Error: \(error.localizedDescription)"
        // NOTE: napi_fatal_error does not return, so no "return" is necessary
        napi_fatal_error(nil, 0, message, napiAutoLengthAsInt)
    }
    
    // TODO: should we be returning ".undefined" napi_value if there's no return value (instead of nil)?

    /* process the return value (if any) and return */
    
    if let returnType = napiFunctionData.returnType, let result = result {
        let resultAsNapiValue = NAPIValue.create(cNapiEnv: cNapiEnv, nativeValue: result, napiValueType: returnType)
        return resultAsNapiValue.cNapiValue
    } else {
        // no return type; return nil (which will effectively return an "undefined" value)
        return nil
    }    
}

// TODO: consider refactoring all of this into the type extensions themselves (or into a cleaner function that's INSIDE NAPIValuee.swift, etc.)
// TODO: make sure this function is not called with .undefined or .unsupported values
//       [although if we create a "NAPIUndefined", then it's probably find to call with that...and perhaps we should create a "NAPIUnsupported" too]
// TODO: should we sanity-check (or enforce) that the napiValueTypeOfArgument is compatible with the targetNapiValueType?
internal func convertCNapiValueToNativeValue(cNapiEnv: napi_env, cNapiValue: napi_value, targetNapiValueType: NAPIValueType? = nil) throws -> Any? {
    let napiValueTypeOfArgument = NAPIValueType.getNAPIValueType(cNapiEnv: cNapiEnv, cNapiValue: cNapiValue)

    // convert the napi_value to a NAPIValue type (and then use the NAPIValue to convert the napi_value to its corresponding native type respresentation)
    do {
        switch napiValueTypeOfArgument {
        case .boolean:
            let argumentAsBool = try NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: cNapiValue).asBool()!
            return argumentAsBool
        case .number:
            let argumentAsDouble = try NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: cNapiValue).asDouble()!
            return argumentAsDouble
        case .string:
            let argumentAsString = try NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: cNapiValue).asString()!
            return argumentAsString
        case .nullable(let wrappedType):
            precondition(wrappedType == nil, "Arguments of type .nullable(...) should only be mapped to null itself.")
            return nil
        case .object(_, _):
            if targetNapiValueType == nil {
                fatalError("Cannot create object without target type")
            }
            
            if case let .object(_ , swiftType) = targetNapiValueType! {
                guard let swiftType = swiftType else {
                    fatalError("NAPI value has no associated Swift type")
                }
                let argumentAsObject = try NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: cNapiValue, napiValueType: napiValueTypeOfArgument).asObject(ofType: swiftType)
                return argumentAsObject
            } else {
                // unreachable code: swiftType must always be (auto-)populated in napiFunctionData
                fatalError()
            }
        case .array(let elementNapiValueType):
            if let elementNapiValueType = elementNapiValueType {
                let argumentAsArray = try NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: cNapiValue, napiValueType: napiValueTypeOfArgument).asArray(elementNapiValueType: elementNapiValueType)!
                return argumentAsArray
            } else {
                return []
            }
        case .function:
            let argumentAsJavaScriptFunction = try NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: cNapiValue).asJavaScriptFunction()!
            return argumentAsJavaScriptFunction
        case .error:
            let argumentAsJavaScriptError = try NAPIValue(cNapiEnv: cNapiEnv, cNapiValue: cNapiValue).asJavaScriptError()!
            return argumentAsJavaScriptError
        case .undefined:
            // this is an unsupported type (and should be unreachable code)
            fatalError()
        case .unsupported:
            // this is an unsupported type (and should be unreachable code)
            fatalError()
        }
    } catch let error {
        throw error
    }
}
