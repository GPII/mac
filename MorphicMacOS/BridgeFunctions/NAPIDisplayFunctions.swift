//
// NAPIDiplayFunctions.swift
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

class NAPIDisplayFunctions {
    // MARK: - Swift NAPI bridge setup

    static func getFunctionsAsPropertyDescriptors(env: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // getDisplayModes
        result.append(NAPIProperty.createMethodProperty(env: env, name: "getAllDisplayModes", method: getAllDisplayModes).napiPropertyDescriptor)

        // getCurrentDisplayMode
        result.append(NAPIProperty.createMethodProperty(env: env, name: "getCurrentDisplayMode", method: getCurrentDisplayMode).napiPropertyDescriptor)

        // setCurrentDisplayMode
        result.append(NAPIProperty.createMethodProperty(env: env, name: "setCurrentDisplayMode", method: setCurrentDisplayMode).napiPropertyDescriptor)

        return result
    }

    // MARK: - Swift NAPI bridge functions

    public struct NAPIDisplayMode: NAPIObjectCompatible {
        let ioDisplayModeId: Double // Int32
        let widthInPixels: Double // Int (Int32/Int64)
        let heightInPixels: Double // Int (Int32/Int64)
        let widthInVirtualPixels: Double // Int (Int32/Int64)
        let heightInVirtualPixels: Double // Int (Int32/Int64)
        let refreshRateInHertz: Double?
        let isUsableForDesktopGui: Bool // NOTE: we can use this flag, in theory, to limit the resolutions we provide to user

        static var NAPIPropertyCodingKeysAndTypes: [(propertyKey: CodingKey, type: NAPIValueType)] =
        [
            (propertyKey: CodingKeys.ioDisplayModeId, type: .number),
            (propertyKey: CodingKeys.widthInPixels, type: .number),
            (propertyKey: CodingKeys.heightInPixels, type: .number),
            (propertyKey: CodingKeys.widthInVirtualPixels, type: .number),
            (propertyKey: CodingKeys.heightInVirtualPixels, type: .number),
            // TODO: we should probably change "type" to "wrappedType" (in the .nullable definition) and then maybe make it optional to write
            (propertyKey: CodingKeys.refreshRateInHertz, type: .nullable(type: .number)),
            (propertyKey: CodingKeys.isUsableForDesktopGui, type: .boolean)
        ]
        
        init(displayMode: MorphicDisplay.DisplayMode) {
            self.ioDisplayModeId = Double(exactly: displayMode.ioDisplayModeId)!
            //
            guard let widthInPixelsAsDouble = Double(exactly: displayMode.widthInPixels) else {
                fatalError("widthInPixels cannot be represented as a 64-bit floating point value")
            }
            self.widthInPixels = widthInPixelsAsDouble
            //
            guard let heightInPixelsAsDouble = Double(exactly: displayMode.heightInPixels) else {
                fatalError("heightInPixels cannot be represented as a 64-bit floating point value")
            }
            self.heightInPixels = heightInPixelsAsDouble
            //
            guard let widthInVirtualPixelsAsDouble = Double(exactly: displayMode.widthInVirtualPixels) else {
                fatalError("widthInVirtualPixels cannot be represented as a 64-bit floating point value")
            }
            self.widthInVirtualPixels = widthInVirtualPixelsAsDouble
            //
            guard let heightInVirtualPixelsAsDouble = Double(exactly: displayMode.heightInVirtualPixels) else {
                fatalError("heightInVirtualPixels cannot be represented as a 64-bit floating point value")
            }
            self.heightInVirtualPixels = heightInVirtualPixelsAsDouble
            //
            self.refreshRateInHertz = displayMode.refreshRateInHertz
            //
            self.isUsableForDesktopGui = displayMode.isUsableForDesktopGui
        }
    }

    public static func getAllDisplayModes() -> [NAPIDisplayMode] {
        guard let mainDisplayId = MorphicDisplay.getMainDisplayId() else {
            // TODO: consider throwing a JavaScript error, since we couldn't get the main display ID
            return []
        }
        
        guard let allDisplayModes = MorphicDisplay.getAllDisplayModes(for: mainDisplayId) else {
            // TODO: consider throwing a JavaScript error, since we couldn't get the display modes
            return []
        }
        
        var napiDisplayModes: [NAPIDisplayMode] = []
        napiDisplayModes.reserveCapacity(allDisplayModes.count)
        for displayMode in allDisplayModes {
            let napiDisplayMode = NAPIDisplayMode(displayMode: displayMode)
            napiDisplayModes.append(napiDisplayMode)
        }
        
        return napiDisplayModes
    }
    
    public static func getCurrentDisplayMode() -> NAPIDisplayMode {
        guard let mainDisplayId = MorphicDisplay.getMainDisplayId() else {
            // TODO: consider throwing a JavaScript error, since we couldn't get the main display ID
            fatalError("Could not retrieve the ID of the main display")
        }

        guard let currentDisplayMode = MorphicDisplay.getCurrentDisplayMode(for: mainDisplayId) else {
            // TODO: consider throwing a JavaScript error, since we couldn't get the current display ID
            fatalError("Could not retrieve the main display's current display mode")
        }

        let currentNapiDisplayMode = NAPIDisplayMode(displayMode: currentDisplayMode)
        return currentNapiDisplayMode
    }
    
    public static func setCurrentDisplayMode(_ newNapiDisplayMode: NAPIDisplayMode) {
        guard let mainDisplayId = MorphicDisplay.getMainDisplayId() else {
            // TODO: consider throwing a JavaScript error, since we couldn't get the main display ID
            fatalError("Could not retrieve the ID of the main display")
        }

        guard let newDisplayMode = MorphicDisplay.DisplayMode(napiDisplayMode: newNapiDisplayMode) else {
            // TODO: consider throwing a JavaScript error, since the provided display mode could not be converted
            fatalError("Argument 'newNapiDisplayMode' is not valid and could not be converted to the corresponding native type")
        }
        
        do {
            try MorphicDisplay.setCurrentDisplayMode(for: mainDisplayId, to: newDisplayMode)
        } catch MorphicDisplay.SetCurrentDisplayModeError.invalidDisplayMode {
            // TODO: consider throwing a JavaScript error
            fatalError("Display mode (in argument 'newNapiDisplayMode' is invalid")
        } catch MorphicDisplay.SetCurrentDisplayModeError.otherError {
            // TODO: consider throwing a JavaScript error
            return
        } catch {
            // TODO: consider throwing a JavaScript error
            return
        }
    }
}

extension MorphicDisplay.DisplayMode {
    init?(napiDisplayMode: NAPIDisplayFunctions.NAPIDisplayMode) {
        guard let ioDisplayModeId = Int32(exactly: napiDisplayMode.ioDisplayModeId) else {
            return nil
        }
        self.ioDisplayModeId = ioDisplayModeId
        //
        guard let widthInPixelsAsInt = Int(exactly: napiDisplayMode.widthInPixels) else {
            return nil
        }
        self.widthInPixels = widthInPixelsAsInt
        //
        guard let heightInPixelsAsInt = Int(exactly: napiDisplayMode.heightInPixels) else {
            return nil
        }
        self.heightInPixels = heightInPixelsAsInt
        //
        guard let widthInVirtualPixelsAsInt = Int(exactly: napiDisplayMode.widthInVirtualPixels) else {
            return nil
        }
        self.widthInVirtualPixels = widthInVirtualPixelsAsInt
        //
        guard let heightInVirtualPixelsAsInt = Int(exactly: napiDisplayMode.heightInVirtualPixels) else {
            return nil
        }
        self.heightInVirtualPixels = heightInVirtualPixelsAsInt
        //
        self.refreshRateInHertz = napiDisplayMode.refreshRateInHertz
        //
        self.isUsableForDesktopGui = napiDisplayMode.isUsableForDesktopGui
    }
}
