//
// NAPIInputFunctions.swift
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

class NAPIInputFunctions {
    // MARK: - Swift NAPI bridge setup

    static func getFunctionsAsPropertyDescriptors(cNapiEnv: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // sendKey
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "sendKey", method: sendKey).cNapiPropertyDescriptor)
        
        return result
    }

    // MARK: - Swift NAPI bridge functions

    public struct NAPIKeyOptions: NAPIObjectCompatible {
        let withControlKey: Bool
        let withAlternateKey: Bool
        let withCommandKey: Bool

        static var NAPIPropertyCodingKeysAndTypes: [(propertyKey: CodingKey, type: NAPIValueType)] =
        [
            (propertyKey: CodingKeys.withControlKey, type: .boolean),
            (propertyKey: CodingKeys.withAlternateKey, type: .boolean),
            (propertyKey: CodingKeys.withCommandKey, type: .boolean)
        ]
    }

    public static func sendKey(_ keyCode: Double, _ keyOptions: NAPIKeyOptions, _ processId: Double) throws {
        guard let keyCodeAsInt16 = Int16(exactly: keyCode) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.rangeError(message: "Argument 'keyCode' is out of range")
        }

        var keyOptionsRawValue: UInt32 = 0
        //
        // hold down control key (if applicable)
        if keyOptions.withControlKey == true {
            keyOptionsRawValue |= MorphicInput.KeyOptions.withControlKey.rawValue
        }
        //
        // hold down alternate/option key (if applicable)
        if keyOptions.withAlternateKey == true {
            keyOptionsRawValue |= MorphicInput.KeyOptions.withAlternateKey.rawValue
        }
        //
        // hold down command key (if applicable)
        if keyOptions.withCommandKey == true {
            keyOptionsRawValue |= MorphicInput.KeyOptions.withCommandKey.rawValue
        }
        //
        let keyOptionsAsKeyOptions = MorphicInput.KeyOptions(napiKeyOptions: keyOptions)
        
        guard let processIdAsInt = Int(exactly: processId) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.rangeError(message: "Argument 'processId' is out of range")
        }

        // NOTE: key codes may be different on non-EN_US keyboards; we may want to add a mapping capability to choose the proper "local" virtual keycodes based on "universal" metacodes
        let keyCodeACGKeyCode = CGKeyCode(keyCodeAsInt16)

        let sendKeyResult = MorphicInput.sendKey(keyCode: keyCodeACGKeyCode, keyOptions: keyOptionsAsKeyOptions, toProcessId: processIdAsInt)
        if sendKeyResult == false {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not send key code")
        }
    }
}

extension MorphicInput.KeyOptions {
    init(napiKeyOptions: NAPIInputFunctions.NAPIKeyOptions) {
        var keyOptionsRawValue: UInt32 = 0
        //
        // hold down control key (if applicable)
        if napiKeyOptions.withControlKey == true {
            keyOptionsRawValue |= MorphicInput.KeyOptions.withControlKey.rawValue
        }
        //
        // hold down alternate/option key (if applicable)
        if napiKeyOptions.withAlternateKey == true {
            keyOptionsRawValue |= MorphicInput.KeyOptions.withAlternateKey.rawValue
        }
        //
        // hold down command key (if applicable)
        if napiKeyOptions.withCommandKey == true {
            keyOptionsRawValue |= MorphicInput.KeyOptions.withCommandKey.rawValue
        }
        //
        self = MorphicInput.KeyOptions(rawValue: keyOptionsRawValue)
    }
}
