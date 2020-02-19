//
// MorphicLanguagee.swift
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

// NOTE: the MorphicLanguage class contains the functionality used by Obj-C and Swift applications

public class MorphicLanguage {
    // NOTE: this function gets the property in the global domain (AnyApplication), but only for the current user
    public static func getAppleLanguagesFromGlobalDomain() -> [String]? {
        guard let propertyList = CFPreferencesCopyValue("AppleLanguages" as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) else {
            return nil
        }
        
        let result = propertyList as? [String]
        return result
    }

    // NOTE: this function sets the property in the global domain (AnyApplication), but only for the current user
    public static func setAppleLanguagesInGlobalDomain(_ languages: [String]) -> Bool {
        CFPreferencesSetValue("AppleLanguages" as CFString, languages as CFArray, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        let success = CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        return success
    }
    
    public static func setPrimaryAppleLanguageInGlobalDomain(_ primaryLanguage: String) -> Bool {
        // get our current list of Apple Languages
        guard var appleLanguages = MorphicLanguage.getAppleLanguagesFromGlobalDomain() else {
            return false
        }
//        // alternative approach
//        guard var languages: [String] = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String] else {
//            return
//        }
        
        // verify that the specified 'primaryLanguage' is contained within the list of installed languages
        guard appleLanguages.contains(primaryLanguage) == true else {
            return false
        }
        
        // remove the desired primary language from the list of apple languages (since we want to push it to the top of the list)
        appleLanguages = appleLanguages.filter() { $0 != primaryLanguage }
//        // alternate approach
//        appleLanguages.removeAll(where: { $0 == primaryLanguage })

        // prepend the desired primary language to the full list
        appleLanguages.insert(primaryLanguage, at: 0)

        // re-set the apple languages list (with the desired primary language now at the top of the list)
        let success = MorphicLanguage.setAppleLanguagesInGlobalDomain(appleLanguages)
        return success
    }
}
