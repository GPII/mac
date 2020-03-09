//
// NAPIAudioFunctions.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

class NAPIAudioFunctions {
    // MARK: - Swift NAPI bridge setup

    static func getFunctionsAsPropertyDescriptors(cNapiEnv: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // getAudioVolume
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "getAudioVolume", method: getAudioVolume).cNapiPropertyDescriptor)

        // setAudioVolume
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "setAudioVolume", method: setAudioVolume).cNapiPropertyDescriptor)

        // getAudioMuteState
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "getAudioMuteState", method: getAudioMuteState).cNapiPropertyDescriptor)

        // setAudioMuteState
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "setAudioMuteState", method: setAudioMuteState).cNapiPropertyDescriptor)

        return result
    }

    // MARK: - Swift NAPI bridge functions

    public static func getAudioVolume() throws -> Double {
        guard let defaultAudioOutputDeviceId = MorphicAudio.getDefaultAudioDeviceId() else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not get default audio device id")
        }

        // get the current volume
        guard let volume = MorphicAudio.getVolume(for: defaultAudioOutputDeviceId) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not get volume of default audio device")
        }

        return Double(volume)
    }
    
    public static func getAudioMuteState() throws -> Bool {
        guard let defaultAudioOutputDeviceId = MorphicAudio.getDefaultAudioDeviceId() else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not get default audio device id")
        }

        // also get the mute state
        guard let muteState = MorphicAudio.getMuteState(for: defaultAudioOutputDeviceId) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not get mute state of default audio device")
        }

        return muteState
    }
    
    public static func setAudioVolume(value: Double) throws {
        guard let defaultAudioOutputDeviceId = MorphicAudio.getDefaultAudioDeviceId() else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not get default audio device id")
        }

        do {
            try MorphicAudio.setVolume(for: defaultAudioOutputDeviceId, volume: Float(value))
        } catch MorphicAudio.MorphicAudioError.propertyUnavailable {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not find 'volume' property")
        } catch MorphicAudio.MorphicAudioError.cannotSetProperty {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not set 'volume' property")
        } catch MorphicAudio.MorphicAudioError.coreAudioError(let error) {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "CoreAudio error: OSStatus(\(error))")
        }
    }
    
    public static func setAudioMuteState(muteState: Bool) throws {
        guard let defaultAudioOutputDeviceId = MorphicAudio.getDefaultAudioDeviceId() else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not get default audio device id")
        }

        do {
            try MorphicAudio.setMuteState(for: defaultAudioOutputDeviceId, muteState: muteState)
        } catch MorphicAudio.MorphicAudioError.propertyUnavailable {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not find 'mute state' property")
        } catch MorphicAudio.MorphicAudioError.cannotSetProperty {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not set 'mute state' property")
        } catch MorphicAudio.MorphicAudioError.coreAudioError(let error) {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "CoreAudio error: OSStatus(\(error))")
        }
    }
}
