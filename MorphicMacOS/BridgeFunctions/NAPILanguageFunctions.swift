//
// NAPILanguageFunctions.swift
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

class NAPILanguageFunctions {
    // MARK: - Swift NAPI bridge setup

    static func getFunctionsAsPropertyDescriptors(env: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // getInstalledAppleLanguages
        result.append(NAPIProperty.createMethodProperty(env: env, name: "getInstalledAppleLanguages", method: getInstalledAppleLanguages).napiPropertyDescriptor)

        // setPrimaryAppleLanguage
        result.append(NAPIProperty.createMethodProperty(env: env, name: "setPrimaryAppleLanguage", method: setPrimaryAppleLanguage).napiPropertyDescriptor)

        return result
    }

    // MARK: - Swift NAPI bridge functions

    public static func getInstalledAppleLanguages() -> [String] {
        guard let installedAppleLanguages = MorphicLanguage.getAppleLanguagesFromGlobalDomain() else {
            // TODO: throw a JavaScript error if we cannot get the list of installed languages (instead of failing)
            fatalError("Could not retrieve list of installed languages")
        }
        return installedAppleLanguages
    }
    
    // this function returns true if setting the language was successful
    public static func setPrimaryAppleLanguage(_ primaryLanguage: String) {
        guard MorphicLanguage.setPrimaryAppleLanguageInGlobalDomain(primaryLanguage) == true else {
            // TODO: throw a JavaScript error if we cannot get the list of installed languages (instead of failing)
            fatalError("Could not set primary language")
        }
    }
}
