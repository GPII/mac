//
// NAPIProcessFunctions.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

class NAPIProcessFunctions {
    // MARK: - Swift NAPI bridge setup

    static func getFunctionsAsPropertyDescriptors(env: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // getAllLaunchDaemonsAndAgentsAsServiceNames
        result.append(NAPIProperty.createMethodProperty(env: env, name: "getAllLaunchDaemonsAndAgentsAsServiceNames", method: getAllLaunchDaemonsAndAgentsAsServiceNames).napiPropertyDescriptor)
        
        // restartServicesViaLaunchctl
        result.append(NAPIProperty.createMethodProperty(env: env, name: "restartServicesViaLaunchctl", method: restartServicesViaLaunchctl).napiPropertyDescriptor)

        return result
    }

    // MARK: - Swift NAPI bridge functions

    public static func getAllLaunchDaemonsAndAgentsAsServiceNames() -> [String] {
        let allLaunchDaemonsAndAgents = MorphicLaunchDaemonsAndAgents.allCases
        
        var serviceNames: [String] = []
        
        for daemonOrAgent in allLaunchDaemonsAndAgents {
            serviceNames.append(daemonOrAgent.serviceName)
        }
        
        return serviceNames
    }
    
    public static func restartServicesViaLaunchctl(serviceNames: [String]) {
        MorphicProcess.restartViaLaunchctl(serviceNames: serviceNames)
    }
}
