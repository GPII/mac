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

// MARK: - Bridge function types

// NOTE: NAPISwiftBridgeFunction functions emulate a "Void" return by returning "nil"
// NOTE: NAPISwiftBridgeFunctions are only allowed to throw NAPIJavaScriptErrors (which map to JavaScript Errors)
typealias NAPISwiftBridgeFunction = (_ env: napi_env, _ args: [Any?]) throws -> Any?

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
internal func napiFunctionTrampoline(_ env: napi_env!, _ info: napi_callback_info!) -> napi_value? {
    // NOTE: info should never be nil; this is just a precaution for debug-time sanity
    assert(info != nil, "Argument 'info' may not be nil.")

    var status: napi_status

    let pointerToPointerToNAPIFunctionData = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 1)
    //
    // capture up to the maximum number of arguments allowed in our native functions
    var numberOfArguments: Int = maximumArgumentsInNativeFunctions
    //
    // NOTE: althtough the arguments are returned as optional napi_values, they are indeed non-nil (unless an error occured)
    let pointerToArgumentsAsNapiValues = UnsafeMutablePointer<napi_value?>.allocate(capacity: numberOfArguments)
    //
    var pointerToThisArgumentAsNapiValue: napi_value? = nil

    /* retrieve the callback function info (e.g. indirect pointer to NAPIFunctionData, array of passed-in arguments a,nd the implicit 'this' argument) */
    
    // NOTE: numberOfArguments is an in/out parameter: we pass in the maximum number of arguments we support and it returns the actual number of arguments populated at pointerToArguments
    // NOTE: if the maximum argument count we pass in is not high enough, we will not get all the passed-in arguments; the "maximumNativeFunctionArgumentCount" must therefore be synced with the maximum allowable number of function arguments
    status = napi_get_cb_info(env, info, &numberOfArguments, pointerToArgumentsAsNapiValues, &pointerToThisArgumentAsNapiValue, pointerToPointerToNAPIFunctionData)
    guard status == napi_ok else {
        return nil
    }

    /* capture the NAPIFunctionData we created when we set up this callback (so we know which function to call, the required parameter types and the return type) */
    
    guard let pointerToNapiFunctionData = pointerToPointerToNAPIFunctionData.pointee else {
        // NOTE: we should never _not_ get a pointer to our NAPIFunctionData; this would indicate a shutdown/corruption/programming issue
        // TODO: throw an error
        return nil
    }
    let napiFunctionData = Unmanaged<NAPIFunctionData>.fromOpaque(pointerToNapiFunctionData).takeUnretainedValue()
    
    /* type-check the passed-in arguments and convert them to their respective native-code types */
    
    let argumentsAsNapiValues = Array(UnsafeBufferPointer(start: pointerToArgumentsAsNapiValues, count: numberOfArguments))
    var arguments: [Any?] = []

    guard argumentsAsNapiValues.count >= napiFunctionData.argumentTypes.count else {
        // TODO: consider throwing an error (although it might be better to error out so that the programmer can fix the issue immediately)
        fatalError("Not enough arguments were provided. Received: \(argumentsAsNapiValues.count); Expected: \(napiFunctionData.argumentTypes.count)")
    }

    for index in 0..<napiFunctionData.argumentTypes.count {
        guard let argumentAsNapiValue = argumentsAsNapiValues[index] else {
            // NOTE: arguments should not be nil (as there is a napi_value for "null")
            // TODO: throw an error
            return nil
        }
        let napiValueTypeOfArgument = NAPIValueType.getNAPIValueType(env: env, value: argumentAsNapiValue)
        
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
            switch napiValueTypeOfArgument {
            case .boolean:
                let argumentAsBool = try NAPIValue(env: env, napiValue: argumentAsNapiValue).asBool()!
                arguments.append(argumentAsBool)
            case .number:
                let argumentAsDouble = try NAPIValue(env: env, napiValue: argumentAsNapiValue).asDouble()!
                arguments.append(argumentAsDouble)
            case .string:
                let argumentAsString = try NAPIValue(env: env, napiValue: argumentAsNapiValue).asString()!
                arguments.append(argumentAsString)
            case .nullable(let wrappedType):
                precondition(wrappedType == nil, "Arguments of type .nullable(...) should only be mapped to null itself.")
                arguments.append(nil)
            case .array(_):
                let argumentAsArray = try NAPIValue(env: env, napiValue: argumentAsNapiValue, napiValueType: napiValueTypeOfArgument).asArray()!
                arguments.append(argumentAsArray)
            case .undefined:
                // this is an unsupported type (and should be unreachable code)
                fatalError()
            case .unsupported:
                // this is an unsupported type (and should be unreachable code)
                fatalError()
            }
        } catch {
            // TODO: capture JavaScript error (if one was created by N-API during the conversion process)
        }
    }
    
    /* call the native function (and capture its return value, if any) */
    
    // TODO: how do we want to handle errors thrown from bridge functions?  Do we even want to allow this?
    var result: Any?
    do {
        result = try napiFunctionData.swiftBridgeFunction(env, arguments)
    } catch NAPIJavaScriptError.error {
        // TODO: if a NAPIJavaScriptError was thrown, convert it to the appropriate JavaScript error and throw that instead
        // TODO: be sure to catch ALL NAPIJavaScriptErrors here (including TypeError, RangeError, etc.)
        // NOTE: for now, just return nil in this error scenario
        return nil
    } catch {
        // TODO: otherwise, if any other error was thrown, fail; other errors are not supported
        fatalError()
    }
    
    /* process the return value (if any) and return */
    
    if let returnType = napiFunctionData.returnType, let result = result {
        let resultAsNAPIValue = NAPIValue.create(env: env, nativeValue: result, napiValueType: returnType)
        return resultAsNAPIValue.napiValue
    } else {
        // no return type; return nil (which will effectively return an "undefined" value)
        return nil
    }    
}
