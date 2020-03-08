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

    static func getFunctionsAsPropertyDescriptors(cNapiEnv: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // getAllLaunchDaemonsAndAgentsAsServiceNames
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "getAllLaunchDaemonsAndAgentsAsServiceNames", method: getAllLaunchDaemonsAndAgentsAsServiceNames).cNapiPropertyDescriptor)
        
        // restartServicesViaLaunchctl
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "restartServicesViaLaunchctl", method: restartServicesViaLaunchctl).cNapiPropertyDescriptor)

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
