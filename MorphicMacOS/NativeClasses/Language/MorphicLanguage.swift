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
    // MARK: - Functions to get/set the preferred languages
    
    // NOTE: this function gets the current list of preferred languages (even if a key is not set in the global domain); this is the recommended approach
    public static func getPreferredLanguages() -> [String]? {
        let preferredLanguages = CFLocaleCopyPreferredLanguages()
        return preferredLanguages as? [String]
    }
    
    // NOTE: this function gets the property in the global domain (AnyApplication), but only for the current user
    public static func getAppleLanguagesFromGlobalDomain() -> [String]? {
        guard let propertyList = CFPreferencesCopyValue("AppleLanguages" as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            return nil
        }
        let result = propertyList as? [String]

        return result
    }

    // NOTE: this function sets the property in the global domain (AnyApplication), but only for the current user
    public static func setAppleLanguagesInGlobalDomain(_ languages: [String]) -> Bool {
        CFPreferencesSetValue("AppleLanguages" as CFString, languages as CFArray, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let success = CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        
        return success
    }
    
    public static func setPrimaryAppleLanguageInGlobalDomain(_ primaryLanguage: String) -> Bool {
//        // implementation option 1: get our current list of Apple Languages from the global domain (scoped to the current host)
//        guard var appleLanguages = MorphicLanguage.getAppleLanguagesFromGlobalDomain() else {
//            return false
//        }
        
//        // implementation option 2: get our current list of Apple Languages from UserDefaults
//        guard var appleLanguages: [String] = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String] else {
//            return
//        }
        
        // implementation option 2: get our current list of Apple Languages from Core Foundation; this is the preferred method
        guard var appleLanguages = MorphicLanguage.getPreferredLanguages() else {
            return false
        }
        
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
    
    // MARK: - functions to translate locale/language/country codes to human-readable format
    
    // NOTE: getCurrentLocale() may not reflect changes in the current locale until after a reboot, etc.
    public static func getCurrentLocale() -> CFLocale? {
        return CFLocaleCopyCurrent()
    }
    
    public static func createLocale(from languageAndCountryCode: String) -> CFLocale? {
        guard let canonicalLocaleIdentifier = CFLocaleCreateCanonicalLocaleIdentifierFromString(kCFAllocatorDefault, languageAndCountryCode as CFString) else {
            return nil
        }
        return createLocale(from: canonicalLocaleIdentifier)
    }

    public static func createLocale(from canonicalLocaleIdentifier: CFLocaleIdentifier) -> CFLocale? {
        return CFLocaleCreate(kCFAllocatorDefault, canonicalLocaleIdentifier)
    }
    
    public static func getLanguageAndCountryCode(for locale: CFLocale) -> String? {
        guard let iso639LanguageCode = getIso639LanguageCode(for: locale),
            let iso3166CountryCode = getIso3166CountryCode(for: locale) else {
                return nil
        }
        return iso639LanguageCode + "-" + iso3166CountryCode
    }
    
    public static func getIso639LanguageCode(for locale: CFLocale) -> String? {
        guard let iso639LanguageCodeAsCFTypeRef = CFLocaleGetValue(locale, CFLocaleKey.languageCode) else {
            return nil
        }
        let iso639LanguageCodeAsCFString = iso639LanguageCodeAsCFTypeRef as! CFString
        return iso639LanguageCodeAsCFString as String
    }

    public static func getLanguageName(for iso639LanguageCode: String, translateTo translateToLocale: CFLocale) -> String {
        return CFLocaleCopyDisplayNameForPropertyValue(translateToLocale, CFLocaleKey.languageCode, iso639LanguageCode as CFString) as String
    }

    public static func getIso3166CountryCode(for locale: CFLocale) -> String? {
        guard let iso3166CountryCodeAsCFTypeRef = CFLocaleGetValue(locale, CFLocaleKey.countryCode) else {
            return nil
        }
        let iso3166CountryCodeAsCFString = iso3166CountryCodeAsCFTypeRef as! CFString
        return iso3166CountryCodeAsCFString as String
    }
    
    public static func getCountryName(for iso3166CountryCode: String, translateTo translateToLocale: CFLocale) -> String {
        return CFLocaleCopyDisplayNameForPropertyValue(translateToLocale, CFLocaleKey.countryCode, iso3166CountryCode as CFString) as String
    }
}
