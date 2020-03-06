//
// MorphicWindow.swift
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

// NOTE: the MorphicWindow class contains the functionality used by Obj-C and Swift applications

public class MorphicWindow {
    
    // MARK: - Window search/enumeration functions

    // NOTE: when calculating which window is topmost, this function ignores the top and also the current process's window(s)
    public static func getWindowOwnerNameAndProcessIdOfTopmostWindow() -> (windowOwnerName: String, processId: Int)? {
        // get a list of window info for all on-screen windows
        // NOTE: these windows will be ordered in top-to-bottom order
        guard var windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: AnyObject]] else {
            return nil
        }
        // NOTE: when porting to languages outside of Swift, determine if "windows" needs to be manually released

        // filter out only windows which have a windowLevel ("kCGWindowLayer") of zero (meaning they are not part of the topbar etc.)
        windows = windows.filter { (window) -> Bool in
            let windowLayer = window[kCGWindowLayer as String] as? NSNumber
            return windowLayer == 0
        }
        
        // capture the process ID of our current process (so that we don't consider ourselves to be in the "topmost windows"
        let applicationProcessId = Int(getpid())
        
        // retrieve the topmost window (which is NOT this application)
        var topmostWindow: [String: AnyObject]! = nil
        for window in windows {
            guard let windowProcessId = window[kCGWindowOwnerPID as String] as? Int else {
                // if we cannot get the process id of the window, skip the window
                continue
            }

            if windowProcessId == applicationProcessId {
                // do not include current process in search for topmost window
                continue
            }
            
            // we have found the topmost window
            topmostWindow = window
            break
        }
        //
        if topmostWindow == nil {
            return nil
        }
        
        // retrieve the window ID and process ID of the topmost window
        guard let topmostWindowOwnerName = topmostWindow[kCGWindowOwnerName as String] as? String else {
            return nil
        }
        guard let topmostWindowProcessId = topmostWindow[kCGWindowOwnerPID as String] as? Int else {
            return nil
        }
        
        return (windowOwnerName: topmostWindowOwnerName, processId: topmostWindowProcessId)
    }
}
