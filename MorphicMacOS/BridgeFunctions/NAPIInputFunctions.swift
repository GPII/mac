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

    static func getFunctionsAsPropertyDescriptors(env: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // sendKey
        result.append(NAPIProperty.createMethodProperty(env: env, name: "sendKey", method: sendKey).napiPropertyDescriptor)
        
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

    public static func sendKey(_ keyCode: Double, _ keyOptions: NAPIKeyOptions, _ processId: Double) {
        guard let keyCodeAsInt16 = Int16(exactly: keyCode) else {
            // TODO: consider throwing a JavaScript error, since the provided keyCode could not be converted
            fatalError("Argument 'keyCode' is not valid and could not be converted to the corresponding native type")
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
            // TODO: consider throwing a JavaScript error, since the provided processId could not be converted
            fatalError("Argument 'processId' is not valid and could not be converted to the corresponding native type")
        }

        // NOTE: key codes may be different on non-EN_US keyboards; we may want to add a mapping capability to choose the proper "local" virtual keycodes based on "universal" metacodes
        let keyCodeACGKeyCode = CGKeyCode(keyCodeAsInt16)

        let sendKeyResult = MorphicInput.sendKey(keyCode: keyCodeACGKeyCode, keyOptions: keyOptionsAsKeyOptions, toProcessId: processIdAsInt)
        if sendKeyResult == false {
            // if we could not send the key event, log this error
            // TODO: consider returning a JavaScript error
            NSLog("Could not send key event.")
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
