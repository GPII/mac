//
// NAPIObjectCompatible.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

// NOTE: ideally we would want to limit NAPIObjectCompatible to only support structs (in the future, if Swift provides such a programmatic constraint)
public protocol NAPIObjectCompatible: Decodable, NAPIValueCompatible {
    static var NAPIPropertyCodingKeysAndTypes: [(propertyKey: CodingKey, type: NAPIValueType)] { get }
}
extension NAPIObjectCompatible {
    static var NAPIPropertyNamesAndTypes: [String: NAPIValueType]
    {
        get {
            var result: [String: NAPIValueType] = [:]
            for (propertyName, type) in self.NAPIPropertyCodingKeysAndTypes {
                result[propertyName.stringValue] = type
            }
            
            return result
        }
    }
}
extension NAPIObjectCompatible {
    public static var napiValueType: NAPIValueType {
        var propertyNamesAndTypes: [String : NAPIValueType] = [:]

        for (propertyKey, type) in self.NAPIPropertyCodingKeysAndTypes {
            propertyNamesAndTypes[propertyKey.stringValue] = type
        }
                
        return .object(propertyNamesAndTypes: propertyNamesAndTypes, swiftType: self)
    }
}
