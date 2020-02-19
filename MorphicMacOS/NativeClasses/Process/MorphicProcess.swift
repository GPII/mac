//
// MorphicProcess.swift
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

// NOTE: the MorphicProcess class contains the functionality used by Obj-C and Swift applications

public class MorphicProcess {
    // MARK: - Process/service restarting functionality
    
    public static func restartViaLaunchctl(serviceNames: [String]) {
        // get the current user's ID
        // NOTE: in future releases of macOS we may need to consider using SCDynamicStoreCopyConsoleUser or other methods
        let userId = getuid()

        for serviceName in serviceNames {
            let domainTarget = "gui/" + String(userId) + "/" + serviceName
            MorphicProcess.restartViaLaunchctl(domainTarget: domainTarget)
        }
    }
    
    public static func restartViaLaunchctl(domainTarget: String) {
         let launchctlProcess = Process()
         launchctlProcess.launchPath = "/bin/launchctl"
         launchctlProcess.arguments = ["kickstart", "-k", domainTarget]
         launchctlProcess.launch()
     }
}
