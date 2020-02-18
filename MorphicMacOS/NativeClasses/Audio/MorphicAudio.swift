//
// MorphicAudio.swift
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
import AudioToolbox
//import CoreAudio

// NOTE: the MorphicAudio class contains the functionality used by Obj-C and Swift applications

public class MorphicAudio {
    // MARK: Custom errors
    public enum MorphicAudioError: Error {
        case propertyUnavailable
        case cannotSetProperty
        case coreAudioError(error: OSStatus)
    }

    // MARK: - Audio device enumeration
    
    // NOTE: this function returns nil if it encounters an error; we do this to distinguish an error condition ( nil ) from an empty set ( [] ).
    // Apple docs: https://developer.apple.com/library/archive/technotes/tn2223/_index.html
    public static func getDefaultAudioDeviceId() -> UInt32? {
        var outputDeviceId: AudioDeviceID = 0
        var sizeOfAudioDeviceID = UInt32(MemoryLayout<AudioDeviceID>.size)

        // option 1: kAudioHardwarePropertyDefaultOutputDevice
        var outputDevicePropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
//        // option 2: kAudioHardwarePropertyDefaultSystemOutputDevice
//        var outputDevicePropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)

        let getPropertyError = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &outputDevicePropertyAddress, 0, nil, &sizeOfAudioDeviceID, &outputDeviceId)
        if getPropertyError != noErr {
            // if we cannot retrieve the default output device's id, return nil
            return nil
        }
        
        return outputDeviceId as UInt32
    }
    
    // MARK: - Get/set volume (and mute state)
    
    public static func getVolume(for audioDeviceId: UInt32) -> Float? {
        var volume: Float = 0
        var sizeOfFloat = UInt32(MemoryLayout<Float>.size)

        var volumePropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMasterVolume, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)

        // verify that the output device has a volume property to get
        if AudioObjectHasProperty(AudioObjectID(audioDeviceId), &volumePropertyAddress) == false {
            // if there is no volume property to get, return nil
            return nil
        }
        
        let getPropertyError = AudioObjectGetPropertyData(AudioObjectID(audioDeviceId), &volumePropertyAddress, 0, nil, &sizeOfFloat, &volume)
        if getPropertyError != noErr {
            // if we cannot retrieve the volume, return nil
            return nil
        }
        
        // sanity-check: force the volume into the range 0.0 through 1.0
        if volume < 0.0 {
            volume = 0.0
        } else if volume > 1.0 {
            volume = 1.0
        }
        
        return volume
    }
    
    public static func setVolume(for audioDeviceId: UInt32, volume: Float) throws {
        var newVolume = volume
        let sizeOfFloat = UInt32(MemoryLayout<Float>.size)
        
        var volumePropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMasterVolume, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)

        // verify that the output device has a volume property
        if AudioObjectHasProperty(AudioObjectID(audioDeviceId), &volumePropertyAddress) == false {
            // if there is no volume property, throw an error
            throw MorphicAudioError.propertyUnavailable
        }
        
        // verify that we can set the volume property
        var canSetVolume: DarwinBoolean = true
        let checkSettableError = AudioObjectIsPropertySettable(AudioObjectID(audioDeviceId), &volumePropertyAddress, &canSetVolume)
        if checkSettableError != noErr {
            // if we cannot determine if volume is settable, throw an error
            throw MorphicAudioError.coreAudioError(error: checkSettableError)
        }
        
        if canSetVolume == false {
            // if we cannot set the volume, throw an error
            throw MorphicAudioError.cannotSetProperty
        }
        
        let setPropertyError = AudioObjectSetPropertyData(audioDeviceId, &volumePropertyAddress, 0, nil, sizeOfFloat, &newVolume)
        //
        if setPropertyError != noErr {
            // if we cannot set the volume, throw an error
            throw MorphicAudioError.coreAudioError(error: setPropertyError)
        }
    }
    
    public static func getMuteState(for audioDeviceId: UInt32) -> Bool? {
        var muteState: UInt32 = 0
        var sizeOfUInt32 = UInt32(MemoryLayout<UInt32>.size)
        
        var mutePropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)
        
        // verify that the output device has a mute state to get
        if AudioObjectHasProperty(AudioObjectID(audioDeviceId), &mutePropertyAddress) == false {
            // if there is no mute state to get, return nil
            return nil
        }
        
        let getPropertyError = AudioObjectGetPropertyData(AudioObjectID(audioDeviceId), &mutePropertyAddress, 0, nil, &sizeOfUInt32, &muteState)
        if getPropertyError != noErr {
            // if we cannot retrieve the mute state, return nil
            return nil
        }
        
        return (muteState != 0) ? true : false
    }
    
    // NOTE: to mute, set value to true; to unmute, set value to false.
    public static func setMuteState(for audioDeviceId: UInt32, muteState: Bool) throws {
        var newValue = muteState ? UInt32(1) : UInt32(0)
        let sizeOfUInt32 = UInt32(MemoryLayout<UInt32>.size)
        
        var mutePropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)
        
        // verify that the output device has a mute property
        if AudioObjectHasProperty(AudioObjectID(audioDeviceId), &mutePropertyAddress) == false {
            // if there is no mute state property, throw an error
            throw MorphicAudioError.propertyUnavailable
        }
        
        // verify that we can set the mute property
        var canMute: DarwinBoolean = true
        let checkSettableError = AudioObjectIsPropertySettable(AudioObjectID(audioDeviceId), &mutePropertyAddress, &canMute)
        if checkSettableError != noErr {
            // if we cannot determine if mute is settable, throw an error
            throw MorphicAudioError.coreAudioError(error: checkSettableError)
        }
        
        if canMute == false {
            // if we cannot mute/unmute the audio output device, throw an error
            throw MorphicAudioError.cannotSetProperty
        }
        
        let setPropertyError = AudioObjectSetPropertyData(audioDeviceId, &mutePropertyAddress, 0, nil, sizeOfUInt32, &newValue)
        //
        if setPropertyError != noErr {
            // if we cannot set the mute state, throw an error
            throw MorphicAudioError.coreAudioError(error: setPropertyError)
        }
    }
}
