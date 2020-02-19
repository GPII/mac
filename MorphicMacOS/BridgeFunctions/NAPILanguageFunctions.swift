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

        // getPrimaryInstalledAppleLanguage
        result.append(NAPIProperty.createMethodProperty(env: env, name: "getPrimaryInstalledAppleLanguage", method: getPrimaryInstalledAppleLanguage).napiPropertyDescriptor)

        // setPrimaryInstalledAppleLanguage
        result.append(NAPIProperty.createMethodProperty(env: env, name: "setPrimaryInstalledAppleLanguage", method: setPrimaryInstalledAppleLanguage).napiPropertyDescriptor)

        // getLanguageName
        result.append(NAPIProperty.createMethodProperty(env: env, name: "getLanguageName", method: getLanguageName).napiPropertyDescriptor)

        // getCountryName
        result.append(NAPIProperty.createMethodProperty(env: env, name: "getCountryName", method: getCountryName).napiPropertyDescriptor)

        return result
    }

    // MARK: - Swift NAPI bridge functions

    public static func getInstalledAppleLanguages() -> [String] {
        guard let installedAppleLanguages = MorphicLanguage.getAppleLanguagesFromGlobalDomain() else {
            // TODO: throw a JavaScript error if we cannot get the list of installed languages (instead of failing)
            fatalError("Could not retrieve list of installed languages")
        }
        
        let sortedLanguages = installedAppleLanguages.sorted(by: { $0 < $1 })

        return sortedLanguages
    }
    
    public static func getPrimaryInstalledAppleLanguage() -> String {
        let installedAppleLanguages = getInstalledAppleLanguages()
        return installedAppleLanguages.first!
    }
    
    // this function returns true if setting the language was successful
    public static func setPrimaryInstalledAppleLanguage(_ primaryLanguage: String) {
        guard MorphicLanguage.setPrimaryAppleLanguageInGlobalDomain(primaryLanguage) == true else {
            // TODO: throw a JavaScript error if we cannot get the list of installed languages (instead of failing)
            fatalError("Could not set primary language")
        }
    }
    
    public static func getLanguageName(_ language: String, _ translatedToLanguage: String) -> String {
        // get the language code for the provided language
        guard let languageLocale = MorphicLanguage.createLocale(from: language) else {
            // TODO: throw a JavaScript error
            fatalError("COULD NOT CREATE LOCALE FOR: \(language)")
        }
        guard let languageIso639LanguageCode = MorphicLanguage.getIso639LanguageCode(for: languageLocale) else {
            fatalError("COULD NOT GET LANGUAGE CODE FOR: \(language)")
            // TODO: throw a JavaScript error
        }
        
        // create a locale to match the desired target language
        guard let targetTranslationLanguageLocale = MorphicLanguage.createLocale(from: translatedToLanguage) else {
            // TODO: throw a JavaScript error
            fatalError("COULD NOT CREATE LOCALE FOR: \(translatedToLanguage)")
        }

        return MorphicLanguage.getLanguageName(for: languageIso639LanguageCode, translateTo: targetTranslationLanguageLocale)
    }
    
    public static func getCountryName(_ language: String, _ translatedToLanguage: String) -> String {
        // get the language code for the provided language
        guard let languageLocale = MorphicLanguage.createLocale(from: language) else {
            // TODO: throw a JavaScript error
            fatalError("COULD NOT CREATE LOCALE FOR: \(language)")
        }
        guard let languageIso3166CountryCode = MorphicLanguage.getIso3166CountryCode(for: languageLocale) else {
            fatalError("COULD NOT GET COUNTRY CODE FOR: \(language)")
            // TODO: throw a JavaScript error
        }
        
        // create a locale to match the desired target language
        guard let targetTranslationLanguageLocale = MorphicLanguage.createLocale(from: translatedToLanguage) else {
            // TODO: throw a JavaScript error
            fatalError("COULD NOT CREATE LOCALE FOR: \(translatedToLanguage)")
        }

        return MorphicLanguage.getCountryName(for: languageIso3166CountryCode, translateTo: targetTranslationLanguageLocale)
    }
}
