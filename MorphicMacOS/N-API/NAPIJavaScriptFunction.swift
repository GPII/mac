//
// NAPIJavaScriptFunction.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

public struct NAPIJavaScriptFunction: NAPIValueCompatible {
    public let cNapiEnv: napi_env
    public let cNapiValue: napi_value
    
    public func call(args: [NAPIValueCompatible]) {
        var argsAsCNapiValues: [napi_value?] = []
        for arg in args {
            let argAsNapiValue = NAPIValue.create(cNapiEnv: self.cNapiEnv, nativeValue: arg, napiValueType: type(of: arg).napiValueType)
            argsAsCNapiValues.append(argAsNapiValue.cNapiValue)
        }

        var status: napi_status? = nil

        // capture the JavaScript global object (to pass as "this" to the function)
        var globalAsCNapiValue: napi_value?
        status = napi_get_global(self.cNapiEnv, &globalAsCNapiValue)
        guard status == napi_ok else {
            // todo: throw an error!
            fatalError("Could not get the JavaScript 'global' object")
        }

        // NOTE: this function intentionally ignores any returned values from the JavaScript function; we do this because in testing (even in same-thread environments) that return values which were strings would cause Node (v12.8.1) to crash when we tried to retrieve their contents
        var resultAsCNapiValue: napi_value?

        // TODO: use thread-safe callbacks instead
        // TODO NOTE: in our initial tests, we were unable to retrieve a String from a callback's return value; re-test this scenario with thread-safe callbacks.  If we do allow result values, we must make the caller specify the return type (via a generic-tied argument perhaps) and we must consider how to deal with wrong, .undefined and .unsupported results)
        status = napi_call_function(self.cNapiEnv, globalAsCNapiValue, self.cNapiValue, argsAsCNapiValues.count, argsAsCNapiValues, &resultAsCNapiValue)
        guard status == napi_ok else {
            // TODO: if the status is "napi_pending_exception", the callback threw an error; should we convert it to a NAPISwiftBridgeJavaScriptThrowableError and throw it to the caller?
            // TODO: under all circumstances, we should throw an error (perhaps including a copy of the JavaScript error) instead of using fatalError(...)
            fatalError("Could not call the JavaScript callback")
        }

        // function succeeded; no errors to report
    }
}
extension NAPIJavaScriptFunction {
    public static var napiValueType: NAPIValueType {
        return .function
    }
}
