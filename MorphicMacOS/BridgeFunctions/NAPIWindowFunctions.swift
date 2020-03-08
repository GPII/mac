//
// NAPIWindowFunctions.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

class NAPIWindowFunctions {
    // MARK: - Swift NAPI bridge setup

    static func getFunctionsAsPropertyDescriptors(cNapiEnv: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // getWindowOwnerNameAndProcessIdOfTopmostWindow
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "getWindowOwnerNameAndProcessIdOfTopmostWindow", method: getWindowOwnerNameAndProcessIdOfTopmostWindow).cNapiPropertyDescriptor)

        return result
    }

    // MARK: - Swift NAPI bridge functions
    
    public struct NAPIWindowOwnerNameAndProcessId: NAPIObjectCompatible {
        let windowOwnerName: String
        let processId: Double // Int (Int32/Int64)
 
        public static var NAPIPropertyCodingKeysAndTypes: [(propertyKey: CodingKey, type: NAPIValueType)] =
        [
            (propertyKey: CodingKeys.windowOwnerName, type: .string),
            (propertyKey: CodingKeys.processId, type: .number)
        ]
    }
    
    public static func getWindowOwnerNameAndProcessIdOfTopmostWindow() throws -> NAPIWindowOwnerNameAndProcessId {
        guard let (windowOwnerName, processId) = MorphicWindow.getWindowOwnerNameAndProcessIdOfTopmostWindow() else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not get window owner name and process id for topmost window")
        }

        guard let processIdAsDouble = Double(exactly: processId) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.rangeError(message: "Argument 'processId' cannot be represented as a 64-bit floating point value")
        }
        
        let result = NAPIWindowOwnerNameAndProcessId(windowOwnerName: windowOwnerName, processId: processIdAsDouble)
        return result
    }
}
