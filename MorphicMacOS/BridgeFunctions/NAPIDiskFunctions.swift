//
// NAPIDiskFunctions.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

class NAPIDiskFunctions {
    // MARK: - Swift NAPI bridge setup

    static func getFunctionsAsPropertyDescriptors(cNapiEnv: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // getAllUsbDriveMountPaths
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "getAllUsbDriveMountPaths", method: getAllUsbDriveMountPaths).cNapiPropertyDescriptor)
        
        // openDirectories
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "openDirectories", method: openDirectories).cNapiPropertyDescriptor)
        
        // safelyEjectUsbDrives
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "safelyEjectUsbDrives", method: safelyEjectUsbDrives).cNapiPropertyDescriptor)

        return result
    }

    // MARK: - Swift NAPI bridge functions

    public static func getAllUsbDriveMountPaths() throws -> [String] {
        guard let result = MorphicDisk.getAllUsbDriveMountPaths() else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not retrieve a list of all USB drive mount paths")
        }
        
        return result
    }
    
    public static func openDirectories(_ paths: [String]) {
        // open directory paths using Finder
        for path in paths {
            MorphicDisk.openDirectory(path: path)
        }
    }
    
    public static func safelyEjectUsbDrives(_ usbDriveMountingPaths: [String], _ callback: NAPIJavaScriptFunction?) throws {
        let numberOfDisks = usbDriveMountingPaths.count
        var numberOfDiskEjectsAttempted = 0
        var failedMountPaths: [String] = []
        
        // unmount and eject disk using disk arbitration
        for mountPath in usbDriveMountingPaths {
            do {
                try MorphicDisk.ejectDisk(mountPath: mountPath) {
                    ejectedDiskPath, success in
                    //
                    numberOfDiskEjectsAttempted += 1
                    //
                    if success == true {
                        // we have ejected the disk at mount path: 'ejectedDiskPath'
                    } else {
                        // we failed to eject the disk at mount path: 'ejectedDiskPath'
                        failedMountPaths.append(mountPath)
                    }
                    
                    if numberOfDiskEjectsAttempted == numberOfDisks {
                        // if a callback was provided, call it with success/failure (and an array of all mounting paths which failed)
                        if failedMountPaths.count == 0 {
                            callback?.call(args: [true, Array<String>?(nil)])
                        } else {
                            callback?.call(args: [false, failedMountPaths])
                        }
                    }
                }
            } catch MorphicDisk.EjectDiskError.volumeNotFound {
                throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Failed to eject the disk at mount path: \(mountPath); volume was not found")
            } catch MorphicDisk.EjectDiskError.otherError {
                throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Failed to eject the disk at mount path: \(mountPath); misc. error encountered")
            }
        }
    }
}
