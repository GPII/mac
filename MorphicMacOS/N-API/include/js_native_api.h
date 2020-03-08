//
// js_native_api.h
// Morphic support library for macOS
//
// Copyright © 2020 Raising the Floor -- US Inc. All rights reserved.
//
// The R&D leading to these results received funding from the
// Department of Education - Grant H421A150005 (GPII-APCP). However,
// these results do not necessarily represent the policy of the
// Department of Education, and you should not assume endorsement by the
// Federal Government.

// These headers were copied or derived from the Node.js repositories at GitHub:
//
// Source: https://github.com/nodejs/node/blob/master/src/js_native_api.h
// License: https://github.com/nodejs/node/blob/master/LICENSE

#ifndef js_native_api_h
#define js_native_api_h

// This file needs to be compatible with C compilers.
#include <stddef.h>   // NOLINT(modernize-deprecated-headers)
#include <stdbool.h>  // NOLINT(modernize-deprecated-headers)
#include "js_native_api_types.h"

// Use INT_MAX, this should only be consumed by the pre-processor anyway.
#ifndef NAPI_VERSION
// The baseline version for N-API.
// The NAPI_VERSION controls which version will be used by default when
// compilling a native addon. If the addon developer specifically wants to use
// functions available in a new version of N-API that is not yet ported in all
// LTS versions, they can set NAPI_VERSION knowing that they have specifically
// depended on that version.
#define NAPI_VERSION 5
#endif

#ifndef NAPI_EXTERN
  #define NAPI_EXTERN __attribute__((visibility("default")))
#endif

#define NAPI_AUTO_LENGTH SIZE_MAX

#ifdef __cplusplus
#define EXTERN_C_START extern "C" {
#define EXTERN_C_END }
#else
#define EXTERN_C_START
#define EXTERN_C_END
#endif

EXTERN_C_START

// Getters for defined singletons
NAPI_EXTERN napi_status napi_get_null(napi_env env, napi_value* result);
NAPI_EXTERN napi_status napi_get_global(napi_env env, napi_value* result);
NAPI_EXTERN napi_status napi_get_boolean(napi_env env,
                                         bool value,
                                         napi_value* result);

// Methods to create Primitive types/Objects
NAPI_EXTERN napi_status napi_create_object(napi_env env, napi_value* result);
NAPI_EXTERN napi_status napi_create_array_with_length(napi_env env,
                                                      size_t length,
                                                      napi_value* result);
NAPI_EXTERN napi_status napi_create_double(napi_env env,
                                           double value,
                                           napi_value* result);
NAPI_EXTERN napi_status napi_create_string_utf8(napi_env env,
                                                const char* str,
                                                size_t length,
                                                napi_value* result);
NAPI_EXTERN napi_status napi_create_function(napi_env env,
                                             const char* utf8name,
                                             size_t length,
                                             napi_callback cb,
                                             void* data,
                                             napi_value* result);
NAPI_EXTERN napi_status napi_create_error(napi_env env,
                                          napi_value code,
                                          napi_value msg,
                                          napi_value* result);
NAPI_EXTERN napi_status napi_create_type_error(napi_env env,
                                               napi_value code,
                                               napi_value msg,
                                               napi_value* result);
NAPI_EXTERN napi_status napi_create_range_error(napi_env env,
                                                napi_value code,
                                                napi_value msg,
                                                napi_value* result);

// Methods to get the native napi_value from Primitive type
NAPI_EXTERN napi_status napi_typeof(napi_env env,
                                    napi_value value,
                                    napi_valuetype* result);
NAPI_EXTERN napi_status napi_get_value_double(napi_env env,
                                              napi_value value,
                                              double* result);
NAPI_EXTERN napi_status napi_get_value_bool(napi_env env,
                                            napi_value value,
                                            bool* result);

// Copies UTF-8 encoded bytes from a string into a buffer.
NAPI_EXTERN napi_status napi_get_value_string_utf8(napi_env env,
                                                   napi_value value,
                                                   char* buf,
                                                   size_t bufsize,
                                                   size_t* result);

// Methods to work with Objects
NAPI_EXTERN napi_status napi_get_property_names(napi_env env,
                                                napi_value object,
                                                napi_value* result);
NAPI_EXTERN napi_status napi_set_property(napi_env env,
                                          napi_value object,
                                          napi_value key,
                                          napi_value value);
NAPI_EXTERN napi_status napi_has_property(napi_env env,
                                          napi_value object,
                                          napi_value key,
                                          bool* result);
NAPI_EXTERN napi_status napi_get_property(napi_env env,
                                          napi_value object,
                                          napi_value key,
                                          napi_value* result);
NAPI_EXTERN napi_status napi_set_element(napi_env env,
                                         napi_value object,
                                         uint32_t index,
                                         napi_value value);
NAPI_EXTERN napi_status napi_get_element(napi_env env,
                                         napi_value object,
                                         uint32_t index,
                                         napi_value* result);
NAPI_EXTERN napi_status
napi_define_properties(napi_env env,
                       napi_value object,
                       size_t property_count,
                       const napi_property_descriptor* properties);

// Methods to work with Arrays
NAPI_EXTERN napi_status napi_is_array(napi_env env,
                                      napi_value value,
                                      bool* result);
NAPI_EXTERN napi_status napi_get_array_length(napi_env env,
                                              napi_value value,
                                              uint32_t* result);

// Methods to work with Functions
NAPI_EXTERN napi_status napi_call_function(napi_env env,
                                           napi_value recv,
                                           napi_value func,
                                           size_t argc,
                                           const napi_value* argv,
                                           napi_value* result);

// Methods to work with napi_callbacks

// Gets all callback info in a single call. (Ugly, but faster.)
NAPI_EXTERN napi_status napi_get_cb_info(
    napi_env env,               // [in] NAPI environment handle
    napi_callback_info cbinfo,  // [in] Opaque callback-info handle
    size_t* argc,      // [in-out] Specifies the size of the provided argv array
                       // and receives the actual count of args.
    napi_value* argv,  // [out] Array of values
    napi_value* this_arg,  // [out] Receives the JS 'this' arg for the call
    void** data);          // [out] Receives the data pointer for the callback.

// Methods to support error handling
NAPI_EXTERN napi_status napi_throw(napi_env env, napi_value error);
NAPI_EXTERN napi_status napi_throw_error(napi_env env,
                                         const char* code,
                                         const char* msg);
NAPI_EXTERN napi_status napi_throw_type_error(napi_env env,
                                         const char* code,
                                         const char* msg);
NAPI_EXTERN napi_status napi_throw_range_error(napi_env env,
                                         const char* code,
                                         const char* msg);
NAPI_EXTERN napi_status napi_is_error(napi_env env,
                                      napi_value value,
                                      bool* result);

#if NAPI_VERSION >= 5

// Add finalizer for pointer
NAPI_EXTERN napi_status napi_add_finalizer(napi_env env,
                                          napi_value js_object,
                                          void* native_object,
                                          napi_finalize finalize_cb,
                                          void* finalize_hint,
                                          napi_ref* result);

#endif  // NAPI_VERSION >= 5

EXTERN_C_END

#endif /* js_native_api_h */
