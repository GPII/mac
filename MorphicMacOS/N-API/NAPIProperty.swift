//
// NAPIProperty.swift
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

public class NAPIProperty {
    public let napiPropertyDescriptor: napi_property_descriptor

    private init(napiPropertyDescriptor: napi_property_descriptor) {
        self.napiPropertyDescriptor = napiPropertyDescriptor
    }
        
    //
    
    /* createMethodProperty: 0 to 3 parameter varieties (without return type) */
    // NOTE: we MUST support up to 'maximumArgumentsInNativeFunctions' parameters (from NAPIFunctionHelpers)

    public static func createMethodProperty(env: napi_env, name: String, method: @escaping () throws -> Void) -> NAPIProperty {
        let swiftBridgeFunction = createSwiftBridgeFunction(method: method)
        let napiArgumentTypes: [NAPIValueType] = []

        return createMethodProperty(env: env, name: name, swiftBridgeFunction: swiftBridgeFunction, napiArgumentTypes: napiArgumentTypes)
    }
    //
    public static func createMethodProperty<T0: NAPIValueCompatible>(env: napi_env, name: String, method: @escaping (_ arg0: T0) throws -> Void) -> NAPIProperty {
        let swiftBridgeFunction = createSwiftBridgeFunction(method: method)
        let napiArgumentTypes: [NAPIValueType] = [T0.napiValueType]
        
        return createMethodProperty(env: env, name: name, swiftBridgeFunction: swiftBridgeFunction, napiArgumentTypes: napiArgumentTypes)
    }
    //
    public static func createMethodProperty<T0: NAPIValueCompatible, T1: NAPIValueCompatible>(env: napi_env, name: String, method: @escaping (_ arg0: T0, _ arg1: T1) throws -> Void) -> NAPIProperty {
        let swiftBridgeFunction = createSwiftBridgeFunction(method: method)
        let napiArgumentTypes: [NAPIValueType] = [T0.napiValueType, T1.napiValueType]
        
        return createMethodProperty(env: env, name: name, swiftBridgeFunction: swiftBridgeFunction, napiArgumentTypes: napiArgumentTypes)
    }
    //
    public static func createMethodProperty<T0: NAPIValueCompatible, T1: NAPIValueCompatible, T2: NAPIValueCompatible>(env: napi_env, name: String, method: @escaping (_ arg0: T0, _ arg1: T1, _ arg2: T2) throws -> Void) -> NAPIProperty {
        let swiftBridgeFunction = createSwiftBridgeFunction(method: method)
        let napiArgumentTypes: [NAPIValueType] = [T0.napiValueType, T1.napiValueType, T2.napiValueType]

        return createMethodProperty(env: env, name: name, swiftBridgeFunction: swiftBridgeFunction, napiArgumentTypes: napiArgumentTypes)
    }

    /* createMethodProperty: 0 to 3 parameter varieties (with return type) */
    // NOTE: we MUST support up to 'maximumArgumentsInNativeFunctions' parameters (from NAPIFunctionHelpers)

    public static func createMethodProperty<TReturn: NAPIValueCompatible>(env: napi_env, name: String, method: @escaping () throws -> TReturn) -> NAPIProperty {
        let swiftBridgeFunction = createSwiftBridgeFunction(method: method)
        let napiArgumentTypes: [NAPIValueType] = []

        return createMethodProperty(env: env, name: name, swiftBridgeFunction: swiftBridgeFunction, napiArgumentTypes: napiArgumentTypes, napiReturnType: TReturn.napiValueType)
    }
    //
    public static func createMethodProperty<T0: NAPIValueCompatible, TReturn: NAPIValueCompatible>(env: napi_env, name: String, method: @escaping (_ arg0: T0) throws -> TReturn) -> NAPIProperty {
        let swiftBridgeFunction = createSwiftBridgeFunction(method: method)
        let napiArgumentTypes: [NAPIValueType] = [T0.napiValueType]

        return createMethodProperty(env: env, name: name, swiftBridgeFunction: swiftBridgeFunction, napiArgumentTypes: napiArgumentTypes, napiReturnType: TReturn.napiValueType)
    }
    //
    public static func createMethodProperty<T0: NAPIValueCompatible, T1: NAPIValueCompatible, TReturn: NAPIValueCompatible>(env: napi_env, name: String, method: @escaping (_ arg0: T0, _ arg1: T1) throws -> TReturn) -> NAPIProperty {
        let swiftBridgeFunction = createSwiftBridgeFunction(method: method)
        let napiArgumentTypes: [NAPIValueType] = [T0.napiValueType, T1.napiValueType]

        return createMethodProperty(env: env, name: name, swiftBridgeFunction: swiftBridgeFunction, napiArgumentTypes: napiArgumentTypes, napiReturnType: TReturn.napiValueType)
    }
    //
    public static func createMethodProperty<T0: NAPIValueCompatible, T1: NAPIValueCompatible, T2: NAPIValueCompatible, TReturn: NAPIValueCompatible>(env: napi_env, name: String, method: @escaping (_ arg0: T0, _ arg1: T1, _ arg2: T2) throws -> TReturn) -> NAPIProperty {
        let swiftBridgeFunction = createSwiftBridgeFunction(method: method)
        let napiArgumentTypes: [NAPIValueType] = [T0.napiValueType, T1.napiValueType, T2.napiValueType]

        return createMethodProperty(env: env, name: name, swiftBridgeFunction: swiftBridgeFunction, napiArgumentTypes: napiArgumentTypes, napiReturnType: TReturn.napiValueType)
    }

    // NOTE: this function is the master "createMethodProperty" function called by all the other "createMethodProperty" functions
    fileprivate static func createMethodProperty(env: napi_env, name: String, swiftBridgeFunction: @escaping NAPISwiftBridgeFunction, napiArgumentTypes: [NAPIValueType], napiReturnType: NAPIValueType? = nil) -> NAPIProperty {
        let nameAsNapiValue = NAPIValue.create(env: env, nativeValue: name)

        let napiFunctionData = NAPIFunctionData(swiftBridgeFunction: swiftBridgeFunction, argumentTypes: napiArgumentTypes, returnType: napiReturnType)
        let pointerToNapiFunctionData = Unmanaged.passRetained(napiFunctionData).toOpaque()

        // TODO: consider setting the attributes (instead of just using the default settings)
        let napiPropertyDescriptor = napi_property_descriptor(utf8name: nil, name: nameAsNapiValue.napiValue, method: napiFunctionTrampoline, getter: nil, setter: nil, value: nil, attributes: napi_default, data: pointerToNapiFunctionData)

        let result = NAPIProperty(napiPropertyDescriptor: napiPropertyDescriptor)
        return result
    }

    //
    
    /* createSwiftBridgeFunction: 0 to 3 parameter varieties (without return type) */
    // NOTE: we MUST support up to 'maximumArgumentsInNativeFunctions' parameters (from NAPIFunctionHelpers)
    
    private static func createSwiftBridgeFunction(method: @escaping () throws -> Void) -> NAPISwiftBridgeFunction {
        let swiftBridgeFunction: NAPISwiftBridgeFunction = { (env, args) throws in
            try method()
            // as we have no actual return value: return nil (to satisfy the Swift bridge function signature)
            return nil
        }
        //
        return swiftBridgeFunction
    }
    //
    private static func createSwiftBridgeFunction<T0: NAPIValueCompatible>(method: @escaping (_ arg0: T0) throws -> Void) -> NAPISwiftBridgeFunction {
        let swiftBridgeFunction: NAPISwiftBridgeFunction = { (env, args) throws in
            let arg0 = args[0] as! T0
            //
            try method(arg0)
            // as we have no actual return value: return nil (to satisfy the Swift bridge function signature)
            return nil
        }
        //
        return swiftBridgeFunction
    }
    //
    private static func createSwiftBridgeFunction<T0: NAPIValueCompatible, T1: NAPIValueCompatible>(method: @escaping (_ arg0: T0, _ arg1: T1) throws -> Void) -> NAPISwiftBridgeFunction {
        let swiftBridgeFunction: NAPISwiftBridgeFunction = { (env, args) throws in
            let arg0 = args[0] as! T0
            let arg1 = args[1] as! T1
            //
            try method(arg0, arg1)
            // as we have no actual return value: return nil (to satisfy the Swift bridge function signature)
            return nil
        }
        //
        return swiftBridgeFunction
    }
    //
    private static func createSwiftBridgeFunction<T0: NAPIValueCompatible, T1: NAPIValueCompatible, T2: NAPIValueCompatible>(method: @escaping (_ arg0: T0, _ arg1: T1, _ arg2: T2) throws -> Void) -> NAPISwiftBridgeFunction {
        let swiftBridgeFunction: NAPISwiftBridgeFunction = { (env, args) throws in
            let arg0 = args[0] as! T0
            let arg1 = args[1] as! T1
            let arg2 = args[2] as! T2
            //
            try method(arg0, arg1, arg2)
            // as we have no actual return value: return nil (to satisfy the Swift bridge function signature)
            return nil
        }
        //
        return swiftBridgeFunction
    }

    /* createSwiftBridgeFunction: 0 to 3 parameter varieties (with return type) */
    // NOTE: we MUST support up to 'maximumArgumentsInNativeFunctions' parameters (from NAPIFunctionHelpers)

    private static func createSwiftBridgeFunction<TReturn: NAPIValueCompatible>(method: @escaping () throws -> TReturn) -> NAPISwiftBridgeFunction {
        let swiftBridgeFunction: NAPISwiftBridgeFunction = { (env, args) throws in
            let result = try method()
            //
            return result
        }
        //
        return swiftBridgeFunction
    }
    //
    private static func createSwiftBridgeFunction<T0: NAPIValueCompatible, TReturn: NAPIValueCompatible>(method: @escaping (_ arg0: T0) throws -> TReturn) -> NAPISwiftBridgeFunction {
        let swiftBridgeFunction: NAPISwiftBridgeFunction = { (env, args) throws in
            let arg0 = args[0] as! T0
            //
            let result = try method(arg0)
            //
            return result
        }
        //
        return swiftBridgeFunction
    }
    //
    private static func createSwiftBridgeFunction<T0: NAPIValueCompatible, T1: NAPIValueCompatible, TReturn: NAPIValueCompatible>(method: @escaping (_ arg0: T0, _ arg1: T1) throws -> TReturn) -> NAPISwiftBridgeFunction {
        let swiftBridgeFunction: NAPISwiftBridgeFunction = { (env, args) throws in
            let arg0 = args[0] as! T0
            let arg1 = args[1] as! T1
            //
            let result = try method(arg0, arg1)
            //
            return result
        }
        //
        return swiftBridgeFunction
    }
    //
    private static func createSwiftBridgeFunction<T0: NAPIValueCompatible, T1: NAPIValueCompatible, T2: NAPIValueCompatible, TReturn: NAPIValueCompatible>(method: @escaping (_ arg0: T0, _ arg1: T1, _ arg2: T2) throws -> TReturn) -> NAPISwiftBridgeFunction {
        let swiftBridgeFunction: NAPISwiftBridgeFunction = { (env, args) throws in
            let arg0 = args[0] as! T0
            let arg1 = args[1] as! T1
            let arg2 = args[2] as! T2
            //
            let result = try method(arg0, arg1, arg2)
            //
            return result
        }
        //
        return swiftBridgeFunction
    }
}
