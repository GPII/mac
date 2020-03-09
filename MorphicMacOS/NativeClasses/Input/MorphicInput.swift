//
// MorphicInput.swift
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

// NOTE: the MorphicInput class contains the functionality used by Obj-C and Swift applications

public class MorphicInput {

    // MARK: - KeyOptions struct
    
    public struct KeyOptions: OptionSet {
        public typealias RawValue = UInt32
        public let rawValue: RawValue

        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
        
        public static let withControlKey = KeyOptions(rawValue: 1 << 00)
        public static let withAlternateKey = KeyOptions(rawValue: 1 << 01)
        public static let withCommandKey = KeyOptions(rawValue: 1 << 02)
    }
    
    // MARK: - Keyboard virtualization functions
    
    // NOTE: we have no way to know if the key press was successful: sendKey is "fire and forget"
    public static func sendKey(keyCode: CGKeyCode, keyOptions: KeyOptions, toProcessId processId: Int) -> Bool {
        // NOTE: this implementation of sendKey sends the key to a process via CGEvents and using its processId; we might also consider using AppleScript in the future to send keystrokes to apps (potentially by name)
        
        // NOTE: a CGEventSource of "nil" seems to work just as well, but we're following established practices here; realistically it will probably work fine either way
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            NSLog("Could not set event source to .hidSystemState")
            return false
        }

        guard let keyDownEvent: CGEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true),
            let keyUpEvent: CGEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else {
            //
            NSLog("Could not create keyUp/keyDown events")
            return false
        }
        // NOTE: Swift manages Core Foundation memory for us; in other languages, be sure to CFRelease
//        defer {
//            CFRelease(keyUpEvent)
//            CFRelease(keyDownEvent)
//        }

        var keyDownEventFlagsRawValue = keyDownEvent.flags.rawValue
        var keyUpEventFlagsRawValue = keyUpEvent.flags.rawValue
        //
        // hold down control key (if applicable)
        if keyOptions.contains(.withControlKey) {
            keyDownEventFlagsRawValue |= CGEventFlags.maskControl.rawValue
            keyUpEventFlagsRawValue |= CGEventFlags.maskControl.rawValue
        }
        //
        // hold down alternate/option key (if applicable)
        if keyOptions.contains(.withAlternateKey) {
           keyDownEventFlagsRawValue |= CGEventFlags.maskAlternate.rawValue
           keyUpEventFlagsRawValue |= CGEventFlags.maskAlternate.rawValue
        }
        //
        // hold down command key (if applicable)
        if keyOptions.contains(.withCommandKey) {
            keyDownEventFlagsRawValue |= CGEventFlags.maskCommand.rawValue
            keyUpEventFlagsRawValue |= CGEventFlags.maskCommand.rawValue
        }
        //
        keyDownEvent.flags = CGEventFlags(rawValue: keyDownEventFlagsRawValue)
        keyUpEvent.flags = CGEventFlags(rawValue: keyUpEventFlagsRawValue)

        let processIdAsPid = pid_t(processId)

        // press the key
        keyDownEvent.postToPid(processIdAsPid)
        // then release the key
        keyUpEvent.postToPid(processIdAsPid)

        return true
    }
}
