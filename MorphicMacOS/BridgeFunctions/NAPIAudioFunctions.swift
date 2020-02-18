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

import Foundation

class NAPIAudioFunctions {
    // MARK: - Swift NAPI bridge setup

    static func getFunctionsAsPropertyDescriptors(env: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // getAudioVolume
        result.append(NAPIProperty.createMethodProperty(env: env, name: "getAudioVolume", method: getAudioVolume).napiPropertyDescriptor)

        // setAudioVolume
        result.append(NAPIProperty.createMethodProperty(env: env, name: "setAudioVolume", method: setAudioVolume).napiPropertyDescriptor)

        // getAudioMuteState
        result.append(NAPIProperty.createMethodProperty(env: env, name: "getAudioMuteState", method: getAudioMuteState).napiPropertyDescriptor)

        // setAudioMuteState
        result.append(NAPIProperty.createMethodProperty(env: env, name: "setAudioMuteState", method: setAudioMuteState).napiPropertyDescriptor)

        return result
    }

    // MARK: - Swift NAPI bridge functions

    public static func getAudioVolume() -> Double {
        guard let defaultAudioOutputDeviceId = MorphicAudio.getDefaultAudioDeviceId() else {
            // TODO: throw a JavaScript error if we cannot get the default audio device (instead of returning 0.5)
            NSLog("Could not find default audio output device")
            return 0.5
        }

        // get the current volume
        guard let volume = MorphicAudio.getVolume(for: defaultAudioOutputDeviceId) else {
            // TODO: throw a JavaScript error instead
            NSLog("Could not get volume of output device")
            return 0.5
        }

        return Double(volume)
    }
    
    public static func getAudioMuteState() -> Bool {
        guard let defaultAudioOutputDeviceId = MorphicAudio.getDefaultAudioDeviceId() else {
            // TODO: throw a JavaScript error if we cannot get the default audio device (instead of returning 0.5)
            return false
        }

        // also get the mute state
        guard let muteState = MorphicAudio.getMuteState(for: defaultAudioOutputDeviceId) else {
            // TODO: throw a JavaScript error instead
            fatalError("Could not get mute state of output device")
            return false
        }

        return muteState
    }
    
    public static func setAudioVolume(value: Double) {
        guard let defaultAudioOutputDeviceId = MorphicAudio.getDefaultAudioDeviceId() else {
            // TODO: throw a JavaScript error if we cannot get the default audio device (instead of returning 0.5)
            NSLog("Could not find default audio output device")
            return
        }

        do {
            try MorphicAudio.setVolume(for: defaultAudioOutputDeviceId, volume: Float(value))
        } catch let error {
            // TODO: throw a JavaScript error instead
            NSLog("Could not set volume of output device; error: \(error)")
        }
    }
    
    public static func setAudioMuteState(muteState: Bool) {
        guard let defaultAudioOutputDeviceId = MorphicAudio.getDefaultAudioDeviceId() else {
            // TODO: throw a JavaScript error if we cannot get the default audio device (instead of returning 0.5)
            NSLog("Could not find default audio output device")
            return
        }

        do {
            try MorphicAudio.setMuteState(for: defaultAudioOutputDeviceId, muteState: muteState)
        } catch let error {
            // TODO: throw a JavaScript error instead
            NSLog("Could not set mute state of output device; error: \(error)")
        }
    }
}
