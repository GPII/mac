//
// NAPIBridingCoding.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

// MARK: Object bridging protocols/functions

internal struct NAPIBridgingKeyedDecodingContainerProtocol<Key: CodingKey>: KeyedDecodingContainerProtocol {
     var codingPath: [CodingKey] = []
     
     var allKeys: [Key] = []
     
     let propertyNamesAndValues: [String: Any]
     
     init(propertyNamesAndValues: [String: Any]) {
         self.propertyNamesAndValues = propertyNamesAndValues
     }
     
     func contains(_ key: Key) -> Bool {
         return self.propertyNamesAndValues.keys.contains(key.stringValue)
     }
     
     func decodeNil(forKey key: Key) throws -> Bool {
         let keyAsString = key.stringValue

         // capture the value (if the property exists)
         if self.propertyNamesAndValues.keys.contains(keyAsString) == false {
             throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "Property \(keyAsString) cannot be initialized because it was not provided."))
         }
         let value = self.propertyNamesAndValues[keyAsString]

         if case Optional<Any>.none = value {
             // value is nil
             return true
         } else {
             // value is not nil
             return false
         }
     }
     
     func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
         return try innerDecode(nativeType: type, napiValueType: .boolean, forKey: key) as! Bool
     }
     
     func decode(_ type: String.Type, forKey key: Key) throws -> String {
         return try innerDecode(nativeType: type, napiValueType: .string, forKey: key) as! String
     }
     
     func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
         return try innerDecode(nativeType: type, napiValueType: .number, forKey: key) as! Double
     }
     
     func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
         fatalError("NOT SUPPORTED")
     }
     
     func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
         fatalError("NOT SUPPORTED")
     }
     
     func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
         fatalError("NOT SUPPORTED")
     }
     
     func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
         fatalError("NOT SUPPORTED")
     }
     
     func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
         fatalError("NOT SUPPORTED")
     }
     
     func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
         fatalError("NOT SUPPORTED")
     }
     
     func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
         fatalError("NOT SUPPORTED")
     }
     
     func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
         fatalError("NOT SUPPORTED")
     }
     
     func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
         fatalError("NOT SUPPORTED")
     }
     
     func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
         fatalError("NOT SUPPORTED")
     }
     
     func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
         fatalError("NOT SUPPORTED")
     }
     
     func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
         guard let typeAsNapiValueType = (type as? NAPIValueCompatible.Type)?.napiValueType else {
             throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Property \(key.stringValue) cannot be initialized with a value of type \(T.Type.self)"))
         }
         
         return try innerDecode(nativeType: type, napiValueType: typeAsNapiValueType, forKey: key) as! T
     }
     
     // NOTE: this function returns the requested type (or throws an error if the property is missing or the type is mismatched
     private func innerDecode(nativeType: Any.Type, napiValueType: NAPIValueType, forKey key: Key) throws -> Any? {
         let keyAsString = key.stringValue

         // capture the value (if the property exists)
         if self.propertyNamesAndValues.keys.contains(keyAsString) == false {
             throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Property \(keyAsString) cannot be initialized because it is missing."))
         }
         let value = self.propertyNamesAndValues[keyAsString]

         let nativeTypeAsNapiValueType: NAPIValueType
         // verify that the type is a NAPIValueCompatible type
         guard let nativeTypeAsNapiValueCompatibleType = nativeType as? NAPIValueCompatible.Type else {
             throw DecodingError.typeMismatch(nativeType, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Property \(keyAsString) cannot be initialized with a value of type \(nativeType.self)"))
         }
         nativeTypeAsNapiValueType = nativeTypeAsNapiValueCompatibleType.napiValueType
         
         if nativeTypeAsNapiValueType.isCompatible(withRhs: napiValueType, disregardRhsOptionals: true) {
             return value
         } else {
             throw DecodingError.typeMismatch(nativeType, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Property \(keyAsString) cannot be initialized with a value of type \(nativeType.self)"))
         }
     }
     
     func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
         fatalError("NOT IMPLEMENTED")
     }
     
     func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
         fatalError("NOT IMPLEMENTED")
     }
     
     func superDecoder() throws -> Decoder {
         fatalError("NOT IMPLEMENTED")
     }
     
     func superDecoder(forKey key: Key) throws -> Decoder {
         fatalError("NOT IMPLEMENTED")
     }
 }

 internal struct NAPIBridgingDecoder: Decoder {
     var codingPath: [CodingKey] = []
     
     var userInfo: [CodingUserInfoKey : Any] = [:]
     
     let propertyNamesAndValues: [String: Any]
     
     init(propertyNamesAndValues: [String: Any]) {
         self.propertyNamesAndValues = propertyNamesAndValues
     }
     
     func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
         return KeyedDecodingContainer(NAPIBridgingKeyedDecodingContainerProtocol(propertyNamesAndValues: propertyNamesAndValues))
     }
     
     func unkeyedContainer() throws -> UnkeyedDecodingContainer {
         fatalError("NOT IMPLEMENTED")
     }
     
     func singleValueContainer() throws -> SingleValueDecodingContainer {
         fatalError("NOT IMPLEMENTED")
     }
 }
