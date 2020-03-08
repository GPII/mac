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

class NAPILanguageFunctions {
    // MARK: - Swift NAPI bridge setup

    static func getFunctionsAsPropertyDescriptors(cNapiEnv: napi_env!) -> [napi_property_descriptor] {
        var result: [napi_property_descriptor] = []
        
        // getInstalledAppleLanguages
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "getInstalledAppleLanguages", method: getInstalledAppleLanguages).cNapiPropertyDescriptor)

        // getPrimaryInstalledAppleLanguage
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "getPrimaryInstalledAppleLanguage", method: getPrimaryInstalledAppleLanguage).cNapiPropertyDescriptor)

        // setPrimaryInstalledAppleLanguage
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "setPrimaryInstalledAppleLanguage", method: setPrimaryInstalledAppleLanguage).cNapiPropertyDescriptor)

        // getLanguageName
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "getLanguageName", method: getLanguageName).cNapiPropertyDescriptor)

        // getCountryName
        result.append(NAPIProperty.createMethodProperty(cNapiEnv: cNapiEnv, name: "getCountryName", method: getCountryName).cNapiPropertyDescriptor)

        return result
    }

    // MARK: - Swift NAPI bridge functions

    public static func getInstalledAppleLanguages() throws -> [String] {
        guard let installedAppleLanguages = MorphicLanguage.getPreferredLanguages() else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not retrieve list of Apple preferred languages")
        }
        
        let sortedLanguages = installedAppleLanguages.sorted(by: { $0 < $1 })

        return sortedLanguages
    }
    
    public static func getPrimaryInstalledAppleLanguage() throws -> String {
        // NOTE: we capture the list (sorted by preference...so that the first item in the list is the current (primary) language)
        guard let installedAppleLanguages = MorphicLanguage.getPreferredLanguages() else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not retrieve list of Apple preferred languages")
        }

        return installedAppleLanguages.first!
    }
    
    // this function returns true if setting the language was successful
    public static func setPrimaryInstalledAppleLanguage(_ primaryLanguage: String) throws {
        guard MorphicLanguage.setPrimaryAppleLanguageInGlobalDomain(primaryLanguage) == true else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not set primary preferred language")
        }
    }
    
    public static func getLanguageName(_ language: String, _ translatedToLanguage: String) throws -> String {
        // get the language code for the provided language
        guard let languageLocale = MorphicLanguage.createLocale(from: language) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not create locale for: \(language)")
        }
        guard let languageIso639LanguageCode = MorphicLanguage.getIso639LanguageCode(for: languageLocale) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not get language code for: \(language)")
        }
        
        // create a locale to match the desired target language
        guard let targetTranslationLanguageLocale = MorphicLanguage.createLocale(from: translatedToLanguage) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not create locale for: \(translatedToLanguage)")
        }

        return MorphicLanguage.getLanguageName(for: languageIso639LanguageCode, translateTo: targetTranslationLanguageLocale)
    }
    
    public static func getCountryName(_ language: String, _ translatedToLanguage: String) throws -> String {
        // get the language code for the provided language
        guard let languageLocale = MorphicLanguage.createLocale(from: language) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not create locale for: \(language)")
        }
        guard let languageIso3166CountryCode = MorphicLanguage.getIso3166CountryCode(for: languageLocale) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not get country code for: \(language)")
        }
        
        // create a locale to match the desired target language
        guard let targetTranslationLanguageLocale = MorphicLanguage.createLocale(from: translatedToLanguage) else {
            throw NAPISwiftBridgeJavaScriptThrowableError.error(message: "Could not create locale for: \(translatedToLanguage)")
        }

        return MorphicLanguage.getCountryName(for: languageIso3166CountryCode, translateTo: targetTranslationLanguageLocale)
    }
}
