//
// node_api.h
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
// Source: https://github.com/nodejs/node/blob/master/src/node_api.h
// License: https://github.com/nodejs/node/blob/master/LICENSE
//
// Source: https://github.com/nodejs/node-addon-api/blob/master/src/node_api.h
// License: MIT (https://github.com/nodejs/node-addon-api/blob/master/LICENSE.md)

#ifndef node_api_h
#define node_api_h

#include "js_native_api.h"
#include "node_api_types.h"

#define NAPI_MODULE_EXPORT __attribute__((visibility("default")))

#ifdef __GNUC__
#define NAPI_NO_RETURN __attribute__((noreturn))
#else
#define NAPI_NO_RETURN /* nothing */
#endif

typedef napi_value (*napi_addon_register_func)(napi_env env,
                                               napi_value exports);

typedef struct {
  int nm_version;
  unsigned int nm_flags;
  const char* nm_filename;
  napi_addon_register_func nm_register_func;
  const char* nm_modname;
  void* nm_priv;
  void* reserved[4];
} napi_module;

#define NAPI_MODULE_VERSION  1

#define NAPI_C_CTOR(fn)                              \
  static void fn(void) __attribute__((constructor)); \
  static void fn(void)

#define NAPI_MODULE_X(modname, regfunc, priv, flags)                  \
  EXTERN_C_START                                                      \
    static napi_module _module =                                      \
    {                                                                 \
      NAPI_MODULE_VERSION,                                            \
      flags,                                                          \
      __FILE__,                                                       \
      regfunc,                                                        \
      #modname,                                                       \
      priv,                                                           \
      {0},                                                            \
    };                                                                \
    NAPI_C_CTOR(_register_ ## modname) {                              \
      napi_module_register(&_module);                                 \
    }                                                                 \
  EXTERN_C_END

#define NAPI_MODULE(modname, regfunc)                                 \
  NAPI_MODULE_X(modname, regfunc, NULL, 0)  // NOLINT (readability/null_usage)

#endif /* node_api_h */
