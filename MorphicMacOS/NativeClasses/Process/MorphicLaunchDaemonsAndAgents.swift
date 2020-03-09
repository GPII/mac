//
// MorphicLaunchDaemonsAndAgents.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

public class MorphicLaunchDaemonsAndAgents {
    public struct MorphicLaunchDaemonOrAgentInfo {
        public let name: String
        public let serviceName: String

        public init(name: String, serviceName: String) {
            self.name = name
            self.serviceName = serviceName
        }
    }

    // list of launch (system) daemons and (user) agents
//    public static let controlStrip = MorphicLaunchDaemonOrAgentInfo(
//         name: "Control Strip",
//         serviceName: "com.apple.controlstrip"
//    )
//    //
    public static let dock = MorphicLaunchDaemonOrAgentInfo(
        name: "Dock",
        serviceName: "com.apple.Dock.agent"
    )
    //
    public static let finder = MorphicLaunchDaemonOrAgentInfo(
         name: "Finder",
         serviceName: "com.apple.Finder"
    )
    //
    public static let notificationCenter = MorphicLaunchDaemonOrAgentInfo(
         name: "Notification Center",
         serviceName: "com.apple.notificationcenterui.agent"
    )
    //
    public static let spotlight = MorphicLaunchDaemonOrAgentInfo(
         name: "Spotlight",
         serviceName: "com.apple.Spotlight"
    )
    //
    public static let systemUIServer = MorphicLaunchDaemonOrAgentInfo(
         name: "System UI Server",
         serviceName: "com.apple.SystemUIServer.agent"
    )
    //
    public static let textInputMenuBarExtra = MorphicLaunchDaemonOrAgentInfo(
         name: "Text Input Menubar Extra",
         serviceName: "com.apple.TextInputMenuAgent"
    )

    public static let allCases: [MorphicLaunchDaemonOrAgentInfo] = [
//        LaunchDaemonsAndAgents.controlStrip,
        MorphicLaunchDaemonsAndAgents.dock,
        MorphicLaunchDaemonsAndAgents.finder,
        MorphicLaunchDaemonsAndAgents.notificationCenter,
        MorphicLaunchDaemonsAndAgents.spotlight,
        MorphicLaunchDaemonsAndAgents.systemUIServer,
        MorphicLaunchDaemonsAndAgents.textInputMenuBarExtra
    ]

}
