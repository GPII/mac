//
// js_native_api_types.h
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
// Source: https://github.com/nodejs/node/blob/master/src/js_native_api_types.h
// License: https://github.com/nodejs/node/blob/master/LICENSE

#ifndef js_native_api_types_h
#define js_native_api_types_h

#include <stdint.h>  // NOLINT(modernize-deprecated-headers)
// JSVM API types are all opaque pointers for ABI stability
// typedef undefined structs instead of void* for compile time type safety
typedef struct napi_env__* napi_env;
typedef struct napi_value__* napi_value;
typedef struct napi_ref__* napi_ref;
typedef struct napi_callback_info__* napi_callback_info;

typedef enum {
  napi_default = 0,
  napi_writable = 1 << 0,
  napi_enumerable = 1 << 1,
  napi_configurable = 1 << 2,

  // Used with napi_define_class to distinguish static properties
  // from instance properties. Ignored by napi_define_properties.
  napi_static = 1 << 10,
} napi_property_attributes;

typedef enum {
  // ES6 types (corresponds to typeof)
  napi_undefined,
  napi_null,
  napi_boolean,
  napi_number,
  napi_string,
  napi_symbol,
  napi_object,
  napi_function,
  napi_external,
  napi_bigint,
} napi_valuetype;

typedef enum {
  napi_ok,
  napi_invalid_arg,
  napi_object_expected,
  napi_string_expected,
  napi_name_expected,
  napi_function_expected,
  napi_number_expected,
  napi_boolean_expected,
  napi_array_expected,
  napi_generic_failure,
  napi_pending_exception,
  napi_cancelled,
  napi_escape_called_twice,
  napi_handle_scope_mismatch,
  napi_callback_scope_mismatch,
  napi_queue_full,
  napi_closing,
  napi_bigint_expected,
  napi_date_expected,
  napi_arraybuffer_expected,
  napi_detachable_arraybuffer_expected,
} napi_status;
// Note: when adding a new enum value to `napi_status`, please also update
// `const int last_status` in `napi_get_last_error_info()' definition,
// in file js_native_api_v8.cc. Please also update the definition of
// `napi_status` in doc/api/n-api.md to reflect the newly added value(s).

typedef napi_value (*napi_callback)(napi_env env,
                                    napi_callback_info info);
typedef void (*napi_finalize)(napi_env env,
                              void* finalize_data,
                              void* finalize_hint);

 typedef struct {
   // One of utf8name or name should be NULL.
   const char* utf8name;
   napi_value name;

   napi_callback method;
   napi_callback getter;
   napi_callback setter;
   napi_value value;

   napi_property_attributes attributes;
   void* data;
 } napi_property_descriptor;








#endif /* js_native_api_types_h */
