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

import Foundation

class NAPIDiskFunctions {
    // MARK: - Swift NAPI bridge setup

    static func getFunctionsAsPropertyDescriptors(env: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // getAllUsbDriveMountPaths
        result.append(NAPIProperty.createMethodProperty(env: env, name: "getAllUsbDriveMountPaths", method: getAllUsbDriveMountPaths).napiPropertyDescriptor)
        
        // openDirectories
        result.append(NAPIProperty.createMethodProperty(env: env, name: "openDirectories", method: openDirectories).napiPropertyDescriptor)
        
        // safelyEjectUsbDrives
        result.append(NAPIProperty.createMethodProperty(env: env, name: "safelyEjectUsbDrives", method: safelyEjectUsbDrives).napiPropertyDescriptor)

        return result
    }

    // MARK: - Swift NAPI bridge functions

    public static func getAllUsbDriveMountPaths() -> [String] {
        guard let result = MorphicDisk.getAllUsbDriveMountPaths() else {
            // TODO: raise a JavaScript error instead of failing
            fatalError("Could not retrieve paths")
        }
        
        return result
    }
    
    public static func openDirectories(_ paths: [String]) {
        // open directory paths using Finder
        for path in paths {
            MorphicDisk.openDirectory(path: path)
        }
    }
    
    public static func safelyEjectUsbDrives(_ usbDriveMountingPaths: [String]) {
        // unmount and eject disk using disk arbitration
        for mountPath in usbDriveMountingPaths {
            do {
                try MorphicDisk.ejectDisk(mountPath: mountPath) {
                    ejectedDiskPath, success in
                    //
                    if success == true {
                        // we have ejected the disk at mount path: 'ejectedDiskPath'
                        // NOTE: in the future, we could provide this information to JavaScript via a callback or promise
                    } else {
                        // we failed to eject the disk at mount path: 'ejectedDiskPath'
                        NSLog("Failed to eject the disk at mount path: \(ejectedDiskPath)")
                        // NOTE: in the future, we could provide this information to JavaScript via a callback or promise
                    }
                }
            } catch let error {
                // we failed to eject the disk at mount path: 'mountPath'; the specific error is: 'error'
                NSLog("Failed to eject the disk at mount path: \(mountPath); error: \(error)")
                // NOTE: in the future, we could provide this information to JavaScript via a callback or promise
            }
        }
    }
    
}
