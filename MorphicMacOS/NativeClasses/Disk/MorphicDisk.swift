//
// MorphicDisk.swift
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
//import IOKit
import IOKit.usb
//import IOKit.usb.IOUSBLib

// NOTE: the MorphicDisk class contains the functionality used by Obj-C and Swift applications

public class MorphicDisk {
    // MARK - Open Directory functionality
    
    public static func openDirectory(path: String) {
        // open directory path in Finder

        // NOTE: some of the below methods of opening up the drives may prompt the user for permission under Apple's latest (year 2019) OS security requirements; we may want to look at ways to suppress this prompt in applications consuming this library (including after such apps are updated in a way that changes their signature).  One possible option is installing a background helper app which never changes (or runs at a higher permission level that doesn't prompt for permission).
        
        // NOTE: NSWorkspace may not be available from node-ffi and similar, so we want to explore alternative methods too.
        
        // NOTE: some of the below methods of opening up the drives may not give us the finesse and control we want regarding how the Finder opens, if it's in three-pane vs. single-pane mode, etc.  More research and investigation is in order.
        
//        // METHOD 1:
//        // NOTE: we open each folder separately so that we get multiple separate file view
//        let pathsAsUrls: [URL] = [URL(fileURLWithPath: path, isDirectory: true)]
//        NSWorkspace.shared.activateFileViewerSelecting(pathsAsUrls)

//        // METHOD 2:
//        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
//        // ALTERNATIVE METHOD 2:
//        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: path)
//
//        // METHOD 3:
//        // NOTE: this method opens folders with one file in a solo pane (but opens folders with multiple files in the second pane next to the drive name)
//        NSWorkspace.shared.openFile(path, withApplication: "Finder")

        // METHOD 4 (AppleScript):
        let script: NSString = NSString(format: "tell application \"Finder\"\nactivate\nopen folder (\"%@\" as POSIX file)\nend tell\n", path)

        guard let openScript = NSAppleScript(source: script as String) else {
            NSLog("Could not create AppleScript to open folder at path: \(path)")
            // NOTE: in the future, we could provide this information to JavaScript via a callback or promise
            return
        }
        openScript.executeAndReturnError(nil)
    }

    // MARK: - Eject Disk functionality
    
    public enum EjectDiskError: Error {
        case otherError
        case volumeNotFound
    }
    //
    public typealias EjectDiskCallback = (_ mountPath: String, _ success: Bool) -> Void
    //
    private class EjectDiskInternalCallbackData {
        let diskArbitrationSession: DASession
        let mountPath: String
        let callback: EjectDiskCallback

        init(diskArbitrationSession: DASession, mountPath: String, callback: @escaping EjectDiskCallback) {
            self.diskArbitrationSession = diskArbitrationSession
            self.mountPath = mountPath
            self.callback = callback
        }
    }
    //
    // NOTE: this function safely unmounts and ejects the disk at the specified mount path
    public static func ejectDisk(mountPath: String, callback: @escaping EjectDiskCallback) throws {
        // STEP 1: convert mount path to BSD name
        guard let bsdName = convertMountPathToBsdName(mountPath) else {
            throw EjectDiskError.volumeNotFound
        }
        //
        guard var bsdNameAsCString = bsdName.cString(using: String.Encoding.utf8) else {
            throw EjectDiskError.otherError
        }
        
        // create a Disk Arbitration session so that we can unmount and eject the disk
        guard let diskArbitrationSession = DASessionCreate(kCFAllocatorDefault) else {
            // if we cannot create a disk arbitration session, fail
            throw EjectDiskError.otherError
        }
        // NOTE: because our session is retained for callbacks (because we need it to do callbacks on the run loop), we do not release it here because the callbacks will do that instead.
//        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//        var diskArbitrationSessionRequiresCleanup = false
//        defer {
//            if diskArbitrationSessionRequiresCleanup == true {
//                CFRelease(diskArbitrationSession)
//            }
//        }

        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, diskArbitrationSession, &bsdNameAsCString) else {
            // if we cannot get a reference to the disk, fail
            throw EjectDiskError.volumeNotFound
        }
        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//        defer {
//            CFRelease(disk)
//        }
        
        guard let diskDescription = DADiskCopyDescription(disk) else {
            // if we cannot get a copy of the disk's description, fail
            throw EjectDiskError.otherError
        }
        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//        defer {
//            CFRelease(diskDescription)
//        }

        // determine if the currently-resolved partition is a leaf partition or the whole disk
        let diskDescriptionMediaWholeKey = kDADiskDescriptionMediaWholeKey as CFString
        guard let pointerToMediaWholeKeyValue = CFDictionaryGetValue(diskDescription, unsafeBitCast(diskDescriptionMediaWholeKey, to: UnsafeRawPointer.self)) else {
            // if we cannot get the volume path key for this disk, fail
            throw EjectDiskError.otherError
        }
        // convert the mediaWholeKey's UnsafeRawPointer pointer to a NSNumber instance
        let mediaWholeAsNSNumber = unsafeBitCast(pointerToMediaWholeKeyValue, to: NSNumber.self)
        let diskIsWholeDisk: Bool = (mediaWholeAsNSNumber != 0)

        // NOTE: diskToEject is the specified disk by default; if that disk is a leaf partition we will need to move up to the whole-disk partition instead in a moment (since we need to unmount all partitions on the disk and eject the whole disk)
        var diskToEject = disk
        
        // if the partition is a leaf partition and not the whole-disk partition, get a reference to the whole disk instead
        var wholeDisk: DADisk? = nil
        if diskIsWholeDisk == false {
            // get a reference to the whole-disk partition for this BSD Name (in case we're a leaf partition, we need to eject the whole disk, not just the leaf partition)
            wholeDisk = DADiskCopyWholeDisk(disk)
            if let wholeDisk = wholeDisk {
                // NOTE: we will need to clean up the "whole disk" later as well; see the CFRelease immediately following this block
                diskToEject = wholeDisk
            } else {
                throw EjectDiskError.volumeNotFound
            }
        }
        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//        defer {
//            if wholeDisk != nil {
//                CFRelease(wholeDisk)
//            }
//        }

        // capture all the data we need to use during our callbacks
        let ejectDiskInternalCallbackData = EjectDiskInternalCallbackData(diskArbitrationSession: diskArbitrationSession, mountPath: mountPath, callback: callback)
        
        // manually retain a reference to our callback data; this MUST be manually released by our callback
        let pointerToEjectDiskInternalCallbackData = Unmanaged.passRetained(ejectDiskInternalCallbackData).toOpaque()
        //
        // attach our run loop to our Disk Arbitration session so we can capture the unmount/eject comletion callbacks
        // NOTE: this must be unattached in our unmount/eject callbacks (when the callbacks have either succeeded or failed)
        DASessionScheduleWithRunLoop(diskArbitrationSession, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        // start to unmount all volumes tied to our (whole) disk object; once unmounted our callback will "eject" the drive too
        // NOTE: this unmount operation intentionally does _not_ request force-unmounting--so the operation can be blocked by apps which have open files, etc; if this happens we'll report that failure in our callback.
        DADiskUnmount(diskToEject, DADiskUnmountOptions(kDADiskUnmountOptionWhole), MorphicDisk.unmountDiskCallback, pointerToEjectDiskInternalCallbackData)
        
        // NOTE: at this point, DADiskUnmount will run asynchronously and our callbacks will do the rest of the work
    }
    
    private static let unmountDiskCallback: @convention(c) (DADisk, DADissenter?, UnsafeMutableRawPointer?) -> Void =
    { disk, dissenter, context in
        guard let context = context else {
            fatalError("unmountDiskCallback must always be called with an Unmanaged EjectDiskInternalCallbackData class instance as its context.")
        }

        // convert our context into a EjectDiskInternalCallbackData instance, releasing the retained reference at the same time
        let ejectDiskInternalCallbackData = Unmanaged<EjectDiskInternalCallbackData>.fromOpaque(context).takeRetainedValue()

        if dissenter != nil {
            // first: since our operation is completee, we should unschedule the run loop for our disk arbitration session
            DASessionUnscheduleFromRunLoop(ejectDiskInternalCallbackData.diskArbitrationSession, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            // and we should release the Disk Arbitration session
            // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//            CFRelease(diskArbitrationSession)

            // we could not unmount the volume because we were blocked; report this to our caller

            // return the failure to our caller
            ejectDiskInternalCallbackData.callback(ejectDiskInternalCallbackData.mountPath, false /* success = false */)
        } else {
            // first: since our operation is complete, we should unschedule the run loop for our disk arbitration session
            DASessionUnscheduleFromRunLoop(ejectDiskInternalCallbackData.diskArbitrationSession, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

            // manually retain a reference to our callback data; this MUST be manually released by our callback
            let pointerToEjectDiskInternalCallbackData = Unmanaged.passRetained(ejectDiskInternalCallbackData).toOpaque()
            //
            DADiskEject(disk, DADiskEjectOptions(kDADiskEjectOptionDefault), MorphicDisk.ejectDiskCallback, pointerToEjectDiskInternalCallbackData)
        }
    }

    private static let ejectDiskCallback: @convention(c) (DADisk, DADissenter?, UnsafeMutableRawPointer?) -> Void =
    { disk, dissenter, context in
        guard let context = context else {
            fatalError("ejectDiskCallback must always be called with an Unmanaged EjectDiskInternalCallbackData class instance as its context.")
        }

        // convert our context into a EjectDiskInternalCallbackData instance, releasing the retained reference at the same time
        let ejectDiskInternalCallbackData = Unmanaged<EjectDiskInternalCallbackData>.fromOpaque(context).takeRetainedValue()

        // first: since our operation is complete, we should unschedule the run loop for our disk arbitration session
        DASessionUnscheduleFromRunLoop(ejectDiskInternalCallbackData.diskArbitrationSession, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        // and we should release the Disk Arbitration session
        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//            CFRelease(ejectDiskInternalCallbackData.diskArbitrationSession)

        if dissenter != nil {
            // we could not eject the volume because we were blocked; report this to our caller

            // return the failure to our caller
            ejectDiskInternalCallbackData.callback(ejectDiskInternalCallbackData.mountPath, false /* success = false */)
        } else {
            // return the success to our caller
            ejectDiskInternalCallbackData.callback(ejectDiskInternalCallbackData.mountPath, true /* success = true */)
        }
    }

    // MARK: - Enumerate USB drive functionality

    // NOTE: this function returns nil if it encounters an error; we do this to distinguish an error condition ( nil ) from an empty set ( [] ).
    public static func getAllUsbDriveMountPaths() -> [String]? {
        var result: [String] = []

        /* NOTE: to get our list of all USB Drive mount paths, we
         * - create a matching dictionary so we can filter attached devices/device interfaces (via the I/O registry) to only those who are USB Mass Storage devices.
         * - create an iterator which will iterate through USB interfaces (not devices) which match the matching dictionary
         * - iterate through each matching device, obtaining the BSD Name (e.g. 'disk2') of each USB Mass Storage device
         * - look for children of each device (in case an interface has a child such as one BSD-named 'disk2s1')
         * - use Disk Arbitration to obtain the mount path for each drive (passing in the BSD Name to get disk info)
         */

        // STEP 1: create a matching dictionary which filters on USB interfaces of mass storage devices
        guard let matchingDictionary = MorphicDisk.createMatchingDictionaryForUsbDriveInterfaces() else {
            return nil
        }

        // STEP 2: iterate through each currently-attached USB device's interfaces which match our matching dictionary's filter criteria
        var interfaceIterator: io_iterator_t = 0 // NOTE: must be initialized to a value so that Swift can pass-by-reference
        //
        // STEP 2.1: obtain an iterator (to walk through the list of attached USB Mass Storage interface kernel objects in the I/O Registry)
        // NOTE: the IOServiceGetMatchingServices function automatically releases the matching dictionary (so we do not need to CFRelease in non-Swift languages)
        if IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDictionary, &interfaceIterator) != KERN_SUCCESS {
            // if we could not get an interface iterator, return nil
            return nil
        }
        //
        // iterate through each device interface in the I/O registry which matched, using our interface iterator
        // NOTE: we iterate inside a 'do' block so that we can scope memory management to this singular block using 'defer'
        do {
            // release our iterator when we exit this block
            defer {
                IOObjectRelease(interfaceIterator)
            }

            // itereate through all of our enumerated usb drives, capturing their mount paths
            result.append(contentsOf: MorphicDisk.enumerateUsbDriveMountPaths(interfaceIterator: interfaceIterator))
        }

        return result
    }

    private static func enumerateUsbDriveMountPaths(interfaceIterator: io_service_t) -> [String] {
        var result: [String] = []

        // NOTE: on macOS, it is CRITICAL to completely iterate through the iterator; to this end, we include a defer block here to complete the iteration sequence in any situation where we had to abort early
        // NOTE: technically this may be over-engineering, but it's a good best-practice to use (especially when we're handling notifications, raising callbacks or doing anything else where we need cleanup assurance)
        var currentKernelObject: io_object_t? = nil
        defer {
            if currentKernelObject != nil {
                // complete all iterations of our device iterator
                // NOTE: IOIteratorNext will return a null pointer (i.e. result of zero) when it passes beyond its list
                while case let kernelObject = IOIteratorNext(interfaceIterator), kernelObject != 0 {
                    // clean up each kernel object we just iterated to, as we iterate
                    IOObjectRelease(kernelObject)
                }
            }
        }

        // STEP 1: iterate through the matched device interfaces
        // NOTE: IOIteratorNext will return a null pointer (i.e. result of zero) when it passes beyond its list
        while case let kernelObject = IOIteratorNext(interfaceIterator), kernelObject != 0 {
            defer {
                // clean up each kernel object we just iterated to (after this block is complete)
                IOObjectRelease(kernelObject)
            }

            // capture a copy of the current kernelObject in case we are aborted (so that the appropriate 'defer' block can clean up for us
            currentKernelObject = kernelObject

            var bsdNamesToConvertToMountPaths: [String] = []

            // capture the BSD name for this kernel object
            let ioBsdNameKey = kIOBSDNameKey as CFString
            guard let bsdNameOfWholeDiskAsCFTypeRef = IORegistryEntrySearchCFProperty(kernelObject, kIOServicePlane, ioBsdNameKey, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)) else {
                // if the device does not have a BSD name, skip to the next interface
                continue
            }
            guard let bsdNameOfWholeDisk = MorphicDisk.convertCFTypeRefToString(bsdNameOfWholeDiskAsCFTypeRef) else {
                // if we could not convert the BSD Name to a string, skip to the next interface
                continue
            }

            // get the BSD Names of any leaf partitions of the disk (using the whole-disk's BSD Name as input)
            guard let bsdNamesOfLeafPartitions = MorphicDisk.getBsdNamesOfLeafPartitions(bsdNameOfWholeDisk) else {
                // if we could not get a list of the child BSD names, skip to the next interface
                continue
            }

            if bsdNamesOfLeafPartitions.count > 0 {
                // if the device had children, add those children's names to our list of BSD Names
                bsdNamesToConvertToMountPaths = bsdNamesOfLeafPartitions
            } else {
                // otherwise if the device had no leaf partitions, use the whole disk's name itself as the sole partition in our list of BSD Names
                bsdNamesToConvertToMountPaths = [bsdNameOfWholeDisk]
            }

//                // FOR DEBUG PURPOSES: show the BSD names for the drives
//                for bsdName in bsdNamesToConvertToMountPaths {
//                    print("Drive BSD Name: \(bsdName)")
//                }

            // now convert the BSD names to mount paths
            for bsdNameToConvertToMountPath in bsdNamesToConvertToMountPaths {
                guard let mountPath = MorphicDisk.convertBsdNameToMountPath(bsdNameToConvertToMountPath) else {
                    // if we cannot convert the BSD Name to a mount path, skip to the next BSD Name
                    continue
                }

                // add the mount path to the result array
                result.append(mountPath)
            }
        }

        // set our currentKernelObject to nil since we have completed our iterations (so that the defer block doens't try to clean up)
        currentKernelObject = nil

        return result
    }

    // MARK: - BSD Name to/from Mount Path conversion

    public static func convertBsdNameToMountPath(_ bsdName: String) -> String? {
        // create a Disk Arbitration session so that we can retrieve mounting paths using BSD names
        guard let diskArbitrationSession = DASessionCreate(kCFAllocatorDefault) else {
            // if we cannot create a disk arbitration session, fail
            return nil
        }
        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//        defer {
//            CFRelease(diskArbitrationSession)
//        }
        
        guard var bsdNameAsCString = bsdName.cString(using: String.Encoding.utf8) else {
            return nil
        }
        
        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, diskArbitrationSession, &bsdNameAsCString) else {
            // if we cannot get a reference to the disk, fail
            return nil
        }
        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//        defer {
//            CFRelease(disk)
//        }

        guard let diskDescription = DADiskCopyDescription(disk) else {
            // if we cannot get a copy of the disk's description, fail
            return nil
        }
        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//        defer {
//            CFRelease(diskDescription)
//        }

        let diskDescriptionVolumePathKey = kDADiskDescriptionVolumePathKey as CFString
        guard let pointerToVolumePathKeyValue = CFDictionaryGetValue(diskDescription, unsafeBitCast(diskDescriptionVolumePathKey, to: UnsafeRawPointer.self)) else {
            // if we cannot get the volume path key for this disk, fail
            return nil
        }
        // convert the volumePathKey's UnsafeRawPointer pointer to a CFURL instance
        let volumePathDictionary = unsafeBitCast(pointerToVolumePathKeyValue, to: CFURL.self)
        // convert CFURL to byte array (i.e. CString in byte array form)
        let maxBufferLength = 1024
        var buffer = [UInt8](repeating: 0, count: maxBufferLength)
        if CFURLGetFileSystemRepresentation(volumePathDictionary, false, &buffer, maxBufferLength as CFIndex) == false {
            // if we could not convert the url to a byte buffer, fail
            return nil
        }
        // convert CString buffer to mounting path string
        let mountPath = String(cString: buffer)

        return mountPath
    }
    
    public static func convertMountPathToBsdName(_ mountPath: String) -> String? {
        // create a Disk Arbitration session so that we can retrieve BSD names using mounting paths
        guard let diskArbitrationSession = DASessionCreate(kCFAllocatorDefault) else {
            // if we cannot create a disk arbitration session, fail
            return nil
        }
        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//        defer {
//            CFRelease(diskArbitrationSession)
//        }
        
        // convert mount path String to CFURL
        guard let bufferAsCCharArray: [CChar] = mountPath.cString(using: String.Encoding.utf8) else {
            // if we could not convert the string to a byte buffer, fail
            return nil
        }
        let bufferLength = bufferAsCCharArray.count
        //
        // convert cchar array to UInt8 array
        var bufferAsUInt8Array: [UInt8] = []
        for cchar in bufferAsCCharArray {
            bufferAsUInt8Array.append(UInt8(bitPattern: cchar))
        }
        //
        // converet mount path to CFURL
        guard let mountPathAsCFURL = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, &bufferAsUInt8Array, bufferLength, true) else {
            // if we could not convert the cchar buffer to a url, fail
            return nil
        }
        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//            defer {
//                CFRelease(mountPathAsCFURL)
//            }
        
        guard let diskDescription = DADiskCreateFromVolumePath(kCFAllocatorDefault, diskArbitrationSession, mountPathAsCFURL) else {
            // if we cannot get a copy of the disk's description, fail
            return nil
        }
        // NOTE: Swift automatically manages Core Foundation references, so this is included here just for porting purposes.
//        defer {
//            CFRelease(diskDescription)
//        }

        guard let bsdNameAsCCharArray = DADiskGetBSDName(diskDescription) else {
            // if we cannot resolve the disk's BSD name, return nil
            return nil
        }
        
        // convert CString buffer to mounting path string
        let bsdName = String(cString: bsdNameAsCCharArray)
        
        return bsdName
    }
    
    // MARK: - Helper functions for USB drive enumeration and detection
    
    // NOTE: the CFMutableDictionary returned by this function MUST be released by the consumer (if not using a platform like Swift where this is done automatically), either directly (CFRelease) or indirectly (IOServiceGetMatchingServices)
    private static func createMatchingDictionaryForUsbDriveInterfaces() -> CFMutableDictionary? {
        // NOTE: normally in Swift we would simply cast the result from IOServiceMatching to an NSMatchingDictionary? -- at which point we could simply populate the matching dictionary using key-value syntax (i.e. dictionary[key] = value).  However this test mule is designed to illustrate the necessary API calls on macOS with an eye towards porting the implementation to another non-Foundation-based language, so we illustrate use of the APIs in the most language-portable manner possible (including dealing with CFMutableDictionaries via CF* function calls.
        //
        // example of the "traditional" simplified Swift pattern of using toll-free bridged CFDictionaries follows:
        //        guard var matchingDictionary = IOServiceMatching(kIOUSBInterfaceClassName) as NSMutableDictionary? else {
        //            return nil
        //        }
        //        // ...
        //        // ...
        //        // ...
        //        matchingDictionary[kUSBInterfaceClass] = kUSBMassStorageInterfaceClass
        //        matchingDictionary[kUSBInterfaceSubClass] = kUSBMassStorageSCSISubClass
        
        // STEP 1: create a matching dictionary which filters on USB interfaces (not on USB devices); we do not want to match on non-USB storage devices' interfaces
        guard let matchingDictionary = IOServiceMatching(kIOUSBInterfaceClassName) else {
            return nil
        }
        // NOTE: our call to IOServiceGetMatchingServices (farther below) will release the matching dictionary for us; but if we do not successfully get that far then the dictionary traditionally needs to be released by CFRelease
        // NOTE: Swift automatically manages Core Foundation references, so CFRelease usage is described here just for porting purposes.
        var matchingDictionaryRequiresRelease = true
        defer {
            if matchingDictionaryRequiresRelease == true {
//                CFRelease(matchingDictionary)
            }
        }
        
        // STEP 2: filter the matching dictionary on USB Mass Storage device interfaces only; note that we must use pointers to numbers here when creating CFNumbers.
        //
        // add the device class (USB Mass Storage Interface) to the matching dictionary
        var deviceClass: Int32 = Int32(kUSBMassStorageInterfaceClass)
        let referenceToDeviceClass = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &deviceClass)
        if referenceToDeviceClass == nil {
            return nil
        }
        let usbInterfaceClass = kUSBInterfaceClass as CFString
        CFDictionaryAddValue(matchingDictionary, unsafeBitCast(usbInterfaceClass, to: UnsafeRawPointer.self), unsafeBitCast(referenceToDeviceClass, to: UnsafeRawPointer.self))
        // NOTE: Swift manages Core Foundation memory for us; in other languages, be sure to CFRelease
        //      CFRelease(referenceToDeviceClass)
        //
        // add the device subclass (USB Mass Storage SCSI) to the matching dictionary
        var deviceSubClass: Int32 = Int32(kUSBMassStorageSCSISubClass)
        let referenceToDeviceSubClass = CFNumberCreate(kCFAllocatorDefault, CFNumberType.sInt32Type, &deviceSubClass)
        if referenceToDeviceSubClass == nil {
            return nil
        }
        let usbInterfaceSubClass = kUSBInterfaceSubClass as CFString
        CFDictionaryAddValue(matchingDictionary, unsafeBitCast(usbInterfaceSubClass, to: UnsafeRawPointer.self), unsafeBitCast(referenceToDeviceSubClass, to: UnsafeRawPointer.self))
        // NOTE: Swift manages Core Foundation memory for us; in other languages, be sure to CFRelease
        //      CFRelease(referenceToDeviceSubClass)
        
        // NOTE: we need to return the successfully-built matching dictionary to the caller now, so make sure we mark the matching dictionary as "does not need to be released" at this point
        matchingDictionaryRequiresRelease = false
        
        return matchingDictionary
    }

    // MARK: - BSD Name search functions
    
    // NOTE: this function returns nil if it encounters an error; we do this to distinguish an error condition ( nil ) from an empty set ( [] ).
    private static func getBsdNamesOfLeafPartitions(_ bsdNameOfWholeDisk: String) -> [String]? {
        var result: [String] = []
        
        // STEP 1: create a matching dictionary for the passed-in bsdName
        guard var bsdNameOfWholeDiskAsCString = bsdNameOfWholeDisk.cString(using: String.Encoding.utf8) else {
            return nil
        }
        //
        // NOTE: the second parameter in the following function (the number 0) is passed in for 'options' since no options are defined for this function under macOS
        guard let matchingDictionary = IOBSDNameMatching(kIOMasterPortDefault, 0, &bsdNameOfWholeDiskAsCString) else {
            return nil
        }
        
        // STEP 3: iterate through each service which matches our matching dictionary's filter criteria
        var serviceIterator: io_iterator_t = 0 // NOTE: must be initialized to a value so that Swift can pass-by-reference
        //
        // STEP 3.1: obtain an iterator (to walk through the list of service kernel objects in the I/O Registry)
        // NOTE: the IOServiceGetMatchingServices function automatically releases the matching dictionary, so we do not need to clean it up manually (unless we create code which produces an exit path between where it was created and here)
        if IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDictionary, &serviceIterator) != KERN_SUCCESS {
            // if we could not get a service iterator, return nil
            return nil
        }
        //
        // iterate through each service in the I/O registry which matched, using our service iterator
        // NOTE: we iterate in a 'do' block so that we can scope memory management to this singular block using 'defer'
        do {
            // release our iterator when we exit this block
            defer {
                IOObjectRelease(serviceIterator)
            }
            
            // STEP 3.2: iterate through the matched services
            // NOTE: IOIteratorNext will return a null pointer (i.e. result of zero) when it passes beyond its list
            while case let kernelObject = IOIteratorNext(serviceIterator), kernelObject != 0 {
                defer {
                    // clean up each kernel object we just iterated to (after this block is complete)
                    IOObjectRelease(kernelObject)
                }
                
                // get the children of this service
                var childServiceIterator: io_iterator_t = 0 // NOTE: must be initialized to a value so that Swift can pass-by-reference
                if IORegistryEntryGetChildIterator(kernelObject, kIOServicePlane, &childServiceIterator) != KERN_SUCCESS {
                    // if we could not get children for this service, continue to the next service
                    continue
                }
                //
                do {
                    // release our iterator when we exit this block
                    defer {
                        IOObjectRelease(childServiceIterator)
                    }
                    
                    while case let childKernelObject = IOIteratorNext(childServiceIterator), childKernelObject != 0 {
                        defer {
                            // clean up each child kernel object we just iterated to (after this block is complete)
                            IOObjectRelease(childKernelObject)
                        }
                        
                        // capture the BSD name for this child
                        let ioBSDNameKey = kIOBSDNameKey as CFString
                        guard let bsdNameOfLeafPartitionAsCFType = IORegistryEntrySearchCFProperty(childKernelObject, kIOServicePlane, ioBSDNameKey, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)) else {
                            // if the device does not have a BSD name, skip to the next device
                            continue
                        }
                        guard let bsdNameOfLeafPartition = MorphicDisk.convertCFTypeRefToString(bsdNameOfLeafPartitionAsCFType) else {
                            // if we cannot convert the BSD Name to a string, skip to the next device
                            continue
                        }
                        
                        // save the child's BSD name in our result
                        result.append(bsdNameOfLeafPartition)
                    }
                }
            }
        }
        
        return result
    }
    
    // MARK: - Utility functions
    
    private static func convertCFTypeRefToString(_ value: CFTypeRef) -> String? {
        guard let valueAsString = value as? String else {
            return nil
        }

        return valueAsString
    }
    
    private static func convertCFTypeRefToCString(_ value: CFTypeRef) -> [CChar]? {
        guard let valueAsString = convertCFTypeRefToString(value) else {
            return nil
        }
        guard let valueAsCString = valueAsString.cString(using: String.Encoding.utf8) else {
            return nil
        }
        
        return valueAsCString
    }

}
