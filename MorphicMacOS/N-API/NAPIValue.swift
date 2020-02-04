//
// NAPIValue.swift
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

public class NAPIValue {
    private enum NAPIValueError: Error {
        case typeMismatch
        case otherNapiError
    }
    
    private let env: napi_env
    public let napiValue: napi_value
    public let napiValueType: NAPIValueType
    
    public init(env: napi_env, napiValue: napi_value) {
        let type = NAPIValueType.getNAPIValueTypeOf(env: env, napiValue: napiValue)

        self.env = env
        self.napiValue = napiValue
        self.napiValueType = type
    }
    
    public static func create(env: napi_env, nativeValue: Double) -> NAPIValue {
        var result: napi_value! = nil
        
        let status = napi_create_double(env, nativeValue, &result)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        return NAPIValue(env: env, napiValue: result)
    }

    public static func create(env: napi_env, nativeValue: String) -> NAPIValue {
        var result: napi_value! = nil
        
        let status = napi_create_string_utf8(env, nativeValue, nativeValue.utf8.count, &result)
        guard status == napi_ok else {
            // TODO: check for JavaScript errors instead and throw them instead
            fatalError()
        }

        return NAPIValue(env: env, napiValue: result)
    }

    public func asDouble() throws -> Double? {
        do {
            switch self.napiValueType {
            case .number:
                let valueAsDouble = try self.convertNapiValueToDouble()
                return valueAsDouble
            case .string:
                let valueAsString = try self.convertNapiValueToString()
                return Double(valueAsString)
            case .undefined:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPIJavaScriptError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    public func asString() throws -> String? {
        do {
            switch self.napiValueType {
            case .number:
                let valueAsDouble = try self.convertNapiValueToDouble()
                return String(valueAsDouble)
            case .string:
                let valueAsString = try self.convertNapiValueToString()
                return valueAsString
            case .undefined:
                return nil
            }
        } catch NAPIValueError.otherNapiError {
            // TODO: handle this error...or convert it into a NAPIJavaScriptError and throw it instead
            fatalError()
        } catch {
            // any other errors indicate a programming bug
            fatalError()
        }
    }
    
    private func convertNapiValueToDouble() throws -> Double {
        guard self.napiValueType == .number else {
            throw NAPIValueError.typeMismatch
        }

        var status: napi_status
        var valueAsDouble: Double = 0
        //
        status = napi_get_value_double(self.env, self.napiValue, &valueAsDouble)
        guard status == napi_ok else {
            if status == napi_number_expected {
                // type mismatch
                // TODO: we should still check for a JavaScript exception
                throw NAPIValueError.typeMismatch
            } else {
                // TODO: we should check for a JavaScript exception
                throw NAPIValueError.otherNapiError
            }
        }

        return valueAsDouble
    }
    
    private func convertNapiValueToString() throws -> String {
        guard self.napiValueType == .string else {
            throw NAPIValueError.typeMismatch
        }

        var status: napi_status
        
        var bufferSize = 0
        
        // first, get the size of the string; we do this by passing in a nil buffer (and then we get the size from its 'result' parameter)
        var requiredBufferSize: Int = 0
        status = napi_get_value_string_utf8(self.env, self.napiValue, nil, 0, &requiredBufferSize)
        guard status == napi_ok else {
            if status == napi_string_expected {
                // type mismatch
                // TODO: we should still check for a JavaScript exception
                throw NAPIValueError.typeMismatch
            } else {
                // TODO: we should check for a JavaScript exception
                throw NAPIValueError.otherNapiError
            }
        }
        bufferSize = requiredBufferSize + 1 // +1 for the null terminator
        
        // then get the full string; pass in a buffer equal to its size; we do not worry about null terminators since N-API auto-truncates for us
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        var populatedBufferSize: Int = 0
        status = napi_get_value_string_utf8(self.env, self.napiValue, buffer, bufferSize, &populatedBufferSize)
        guard status == napi_ok else {
            // TODO: we should check for a JavaScript exception
            throw NAPIValueError.otherNapiError
        }
        
        return String(cString: buffer)
    }
}
