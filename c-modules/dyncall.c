/* dyncall.c — libffi-based dynamic FFI for Emacs
 *
 * Provides:
 *   (dyncall-load LIB)         → library handle (user-ptr)
 *   (dyncall-sym LIB SYM)      → function pointer (user-ptr)
 *   (dyncall-call FN RET &rest ARGS) → call C function
 *   (dyncall-close LIB)        → close library
 *   (dyncall LIB SYM RET &rest ARGS) → load+sym+call convenience
 *
 * Type symbols (RET and ARGS pairs):
 *   :void :int :uint :long :ulong :int64 :float :double :string :pointer
 *
 * Examples:
 *   (dyncall "libm.so.6" "sqrt" :double :double 4.0)
 *   (dyncall nil "getpid" :int)
 *   (let ((lib (dyncall-load "libm.so.6")))
 *     (let ((fn (dyncall-sym lib "tgamma")))
 *       (dyncall-call fn :double :double 5.0))
 *     (dyncall-close lib))
 */

#include <emacs-module.h>
#include <dlfcn.h>
#include <ffi.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

int plugin_is_GPL_compatible;

/* ── Cached type symbols (inferred at module init) ────────── */

static emacs_value Qvoid, Qint, Quint, Qlong, Qulong;
static emacs_value Qint64, Qfloat, Qdouble, Qstring, Qpointer;


/* ── ffi_type lookup ───────────────────────────────────── */

/* Compare by name as fallback when eq fails */
static int sym_name_eq(emacs_env *env, emacs_value a, const char *name) {
  emacs_value fn_sn = env->intern(env, "symbol-name");
  emacs_value name_str = env->funcall(env, fn_sn, 1, (emacs_value[]){ a });
  if (env->non_local_exit_check(env) != emacs_funcall_exit_return)
    env->non_local_exit_clear(env);
  ptrdiff_t len = 0;
  env->copy_string_contents(env, name_str, NULL, &len);
  if (len <= 1) return 0;
  char *buf = malloc(len);
  if (!buf) return 0;
  env->copy_string_contents(env, name_str, buf, &len);
  /* Strip leading ':' from keywords before comparing */
  const char *s = buf;
  if (buf[0] == ':') s = buf + 1;
  int eq = (strcmp(s, name) == 0);
  free(buf);
  return eq;
}

static ffi_type *type_of(emacs_env *env, emacs_value sym) {
  if (sym == Qvoid)    return &ffi_type_void;
  if (sym == Qint)     return &ffi_type_sint;
  if (sym == Quint)    return &ffi_type_uint;
  if (sym == Qlong)    return &ffi_type_slong;
  if (sym == Qulong)   return &ffi_type_ulong;
  if (sym == Qint64)   return &ffi_type_sint64;
  if (sym == Qfloat)   return &ffi_type_float;
  if (sym == Qdouble)  return &ffi_type_double;
  if (sym == Qstring)  return &ffi_type_pointer;
  if (sym == Qpointer) return &ffi_type_pointer;
  /* Fallback: compare by name (handles keyword vs non-keyword) */
  if (sym_name_eq(env, sym, "void"))    return &ffi_type_void;
  if (sym_name_eq(env, sym, "int"))     return &ffi_type_sint;
  if (sym_name_eq(env, sym, "uint"))    return &ffi_type_uint;
  if (sym_name_eq(env, sym, "long"))    return &ffi_type_slong;
  if (sym_name_eq(env, sym, "ulong"))   return &ffi_type_ulong;
  if (sym_name_eq(env, sym, "int64"))   return &ffi_type_sint64;
  if (sym_name_eq(env, sym, "float"))   return &ffi_type_float;
  if (sym_name_eq(env, sym, "double"))  return &ffi_type_double;
  if (sym_name_eq(env, sym, "string"))  return &ffi_type_pointer;
  if (sym_name_eq(env, sym, "pointer")) return &ffi_type_pointer;
  return NULL;
}

/* ── Argument extraction helpers ───────────────────────── */

static void *alloc_arg_by_type(emacs_env *env, emacs_value val,
                                ffi_type *type, emacs_value tsym) {
  (void)tsym;
  if (type == &ffi_type_pointer) {
    /* Need tsym to distinguish string vs pointer */
    if (sym_name_eq(env, tsym, "string")) {
      ptrdiff_t len = 0;
      env->copy_string_contents(env, val, NULL, &len);
      /* Single allocation: [char* storage | string data] */
      size_t total = sizeof(char*) + (size_t)len;
      char *block = malloc(total);
      if (!block) return NULL;
      char **storage = (char**)block;
      char *data = block + sizeof(char*);
      env->copy_string_contents(env, val, data, &len);
      *storage = data;
      return storage;
    }
    void **p = malloc(sizeof(void*));
    if (!p) return NULL;
    *p = env->get_user_ptr(env, val);
    return p;
  }
  /* Integer / float types */
  size_t sz = type->size;
  void *buf = malloc(sz);
  if (!buf) return NULL;

  if (type == &ffi_type_sint || type == &ffi_type_sint32) {
    int32_t v = (int32_t) env->extract_integer(env, val);
    memcpy(buf, &v, sz);
  } else if (type == &ffi_type_uint || type == &ffi_type_uint32) {
    uint32_t v = (uint32_t) env->extract_integer(env, val);
    memcpy(buf, &v, sz);
  } else if (type == &ffi_type_slong) {
    long v = (long) env->extract_integer(env, val);
    memcpy(buf, &v, sz);
  } else if (type == &ffi_type_ulong) {
    unsigned long v = (unsigned long) env->extract_integer(env, val);
    memcpy(buf, &v, sz);
  } else if (type == &ffi_type_sint64) {
    int64_t v = (int64_t) env->extract_integer(env, val);
    memcpy(buf, &v, sz);
  } else if (type == &ffi_type_uint64) {
    uint64_t v = (uint64_t) env->extract_integer(env, val);
    memcpy(buf, &v, sz);
  } else if (type == &ffi_type_float) {
    double d = env->extract_float(env, val);
    float f = (float) d;
    memcpy(buf, &f, sz);
  } else if (type == &ffi_type_double) {
    double d = env->extract_float(env, val);
    memcpy(buf, &d, sz);
  } else {
    /* Unknown type: zero-fill */
    memset(buf, 0, sz);
  }
  return buf;
}

static emacs_value wrap_result(emacs_env *env, void *buf, ffi_type *type,
                                emacs_value tsym) {
  (void)tsym;
  if (type == &ffi_type_void)
    return env->intern(env, "nil");
  if (type == &ffi_type_sint || type == &ffi_type_sint32)
    return env->make_integer(env, *(int32_t*)buf);
  if (type == &ffi_type_uint || type == &ffi_type_uint32)
    return env->make_integer(env, *(uint32_t*)buf);
  if (type == &ffi_type_slong)
    return env->make_integer(env, *(long*)buf);
  if (type == &ffi_type_ulong)
    return env->make_integer(env, *(unsigned long*)buf);
  if (type == &ffi_type_sint64)
    return env->make_integer(env, *(int64_t*)buf);
  if (type == &ffi_type_uint64)
    return env->make_integer(env, *(uint64_t*)buf);
  if (type == &ffi_type_float)
    return env->make_float(env, *(float*)buf);
  if (type == &ffi_type_double)
    return env->make_float(env, *(double*)buf);
  if (type == &ffi_type_pointer) {
    /* Need the original type symbol to distinguish string vs pointer */
    if (sym_name_eq(env, tsym, "string")) {
      char *s = *(char**)buf;
      if (!s) return env->intern(env, "nil");
      return env->make_string(env, s, strlen(s));
    }
    void *p = *(void**)buf;
    if (!p) return env->intern(env, "nil");
    return env->make_user_ptr(env, NULL, p);
  }
  return env->intern(env, "nil");
}

/* ── dlclose finalizer ────────────────────────────────── */

static void library_finalizer(void *ptr) {
  if (ptr) dlclose(ptr);
}

/* ── Fdyncall_load (dlopen wrapper) ───────────────────── */

static emacs_value Fdyncall_load(emacs_env *env, ptrdiff_t nargs,
                                  emacs_value args[], void *data) {
  (void)nargs; (void)data;
  /* nil or empty string → RTLD_DEFAULT */
  if (env->eq(env, args[0], env->intern(env, "nil")))
    return env->make_user_ptr(env, library_finalizer, RTLD_DEFAULT);

  ptrdiff_t len = 0;
  env->copy_string_contents(env, args[0], NULL, &len);
  if (len <= 1)
    return env->make_user_ptr(env, library_finalizer, RTLD_DEFAULT);

  char *name = malloc(len);
  if (!name) { env->non_local_exit_signal(env, env->intern(env, "error"),
      env->make_string(env, "dyncall-load: alloc failed", 26)); return env->intern(env, "nil"); }
  env->copy_string_contents(env, args[0], name, &len);

  void *handle = dlopen(name, RTLD_NOW | RTLD_LOCAL);
  free(name);
  if (!handle) {
    env->non_local_exit_signal(env, env->intern(env, "error"),
        env->make_string(env, dlerror(), strlen(dlerror())));
    return env->intern(env, "nil");
  }
  return env->make_user_ptr(env, library_finalizer, handle);
}

/* ── Fdyncall_sym (dlsym wrapper) ─────────────────────── */

static emacs_value Fdyncall_sym(emacs_env *env, ptrdiff_t nargs,
                                 emacs_value args[], void *data) {
  (void)nargs; (void)data;
  void *handle = env->get_user_ptr(env, args[0]);

  ptrdiff_t len = 0;
  env->copy_string_contents(env, args[1], NULL, &len);
  char *name = malloc(len);
  if (!name) { env->non_local_exit_signal(env, env->intern(env, "error"),
      env->make_string(env, "dyncall-sym: alloc failed", 25)); return env->intern(env, "nil"); }
  env->copy_string_contents(env, args[1], name, &len);

  void *fn = dlsym(handle, name);
  free(name);
  if (!fn) {
    env->non_local_exit_signal(env, env->intern(env, "error"),
        env->make_string(env, dlerror(), strlen(dlerror())));
    return env->intern(env, "nil");
  }
  return env->make_user_ptr(env, NULL, fn);
}

/* ── Fdyncall_close (dlclose wrapper) ─────────────────── */

static emacs_value Fdyncall_close(emacs_env *env, ptrdiff_t nargs,
                                   emacs_value args[], void *data) {
  (void)nargs; (void)data;
  void *handle = env->get_user_ptr(env, args[0]);
  if (handle && handle != RTLD_DEFAULT)
    dlclose(handle);
  /* Reset the user-ptr so finalizer won't double-close */
  return env->make_user_ptr(env, NULL, NULL);
}

/* ── Fdyncall_call (core FFI call) ────────────────────── */

/* Signature: (dyncall-call FN RETURN-TYPE ARG-TYPE ARG-VALUE ...) */
/* nargs: 2 + 2*K  (fn + ret + pairs)                        */
/* args[0] = fn pointer (user-ptr)                           */
/* args[1] = return-type symbol                              */
/* args[2K] = arg-type, args[2K+1] = arg-value               */

static emacs_value Fdyncall_call(emacs_env *env, ptrdiff_t nargs,
                                  emacs_value args[], void *data) {
  (void)data;
  void *fn = env->get_user_ptr(env, args[0]);
  if (!fn) {
    env->non_local_exit_signal(env, env->intern(env, "error"),
        env->make_string(env, "dyncall-call: NULL function pointer", 35));
    return env->intern(env, "nil");
  }

  emacs_value ret_sym = args[1];
  ffi_type *ret_type = type_of(env, ret_sym);
  if (!ret_type) {
    env->non_local_exit_signal(env, env->intern(env, "error"),
        env->make_string(env, "dyncall-call: unknown return type", 33));
    return env->intern(env, "nil");
  }

  int n_args = (nargs - 2) / 2;
  if (n_args < 0 || nargs != 2 + 2 * n_args) {
    env->non_local_exit_signal(env, env->intern(env, "error"),
        env->make_string(env, "dyncall-call: malformed args", 28));
    return env->intern(env, "nil");
  }

  /* Build ffi type and value arrays */
  ffi_type **arg_types = NULL;
  void **arg_values = NULL;
  void *ret_buf = NULL;
  emacs_value result = env->intern(env, "nil");

  if (n_args > 0) {
    arg_types = malloc(n_args * sizeof(ffi_type*));
    arg_values = malloc(n_args * sizeof(void*));
    if (!arg_types || !arg_values) goto cleanup;
  }

  for (int i = 0; i < n_args; i++) {
    emacs_value tsym = args[2 + i*2];
    arg_types[i] = type_of(env, tsym);
    if (!arg_types[i]) {
      env->non_local_exit_signal(env, env->intern(env, "error"),
          env->make_string(env, "dyncall-call: unknown arg type", 30));
      goto cleanup;
    }
    arg_values[i] = alloc_arg_by_type(env, args[3 + i*2], arg_types[i], tsym);
    if (!arg_values[i]) {
      env->non_local_exit_signal(env, env->intern(env, "error"),
          env->make_string(env, "dyncall-call: arg alloc failed", 30));
      goto cleanup;
    }
  }

  ret_buf = calloc(1, ret_type->size);
  if (!ret_buf) {
    env->non_local_exit_signal(env, env->intern(env, "error"),
        env->make_string(env, "dyncall-call: ret alloc failed", 30));
    goto cleanup;
  }

  ffi_cif cif;
  ffi_status status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, n_args,
                                     ret_type, arg_types);
  if (status != FFI_OK) {
    env->non_local_exit_signal(env, env->intern(env, "error"),
        env->make_string(env, "dyncall-call: ffi_prep_cif failed", 34));
    goto cleanup;
  }

  ffi_call(&cif, FFI_FN(fn), ret_buf, arg_values);
  result = wrap_result(env, ret_buf, ret_type, ret_sym);

 cleanup:
  free(ret_buf);
  if (arg_values) {
    for (int i = 0; i < n_args; i++) free(arg_values[i]);
    free(arg_values);
  }
  free(arg_types);
  return result;
}

/* ── Fdyncall (convenience: load + sym + call) ────────── */

/* Signature: (dyncall LIB-NAME SYM-NAME RET-TYPE &rest ARGS) */
/* args[0] = library name (string) or nil (for RTLD_DEFAULT)  */
/* args[1] = symbol name (string)                              */
/* args[2] = return type symbol                                */
/* args[3..] = arg-type arg-value pairs                        */

static emacs_value Fdyncall(emacs_env *env, ptrdiff_t nargs,
                             emacs_value args[], void *data) {
  (void)data;
  /* Resolve library */
  void *handle;
  if (env->eq(env, args[0], env->intern(env, "nil"))) {
    handle = RTLD_DEFAULT;
  } else {
    ptrdiff_t len = 0;
    env->copy_string_contents(env, args[0], NULL, &len);
    char *name = malloc(len);
    if (!name) { env->non_local_exit_signal(env, env->intern(env, "error"),
        env->make_string(env, "dyncall: alloc failed", 21)); return env->intern(env, "nil"); }
    env->copy_string_contents(env, args[0], name, &len);
    handle = dlopen(name, RTLD_NOW | RTLD_LOCAL);
    free(name);
    if (!handle) {
      env->non_local_exit_signal(env, env->intern(env, "error"),
          env->make_string(env, dlerror(), strlen(dlerror())));
      return env->intern(env, "nil");
    }
  }

  /* Lookup symbol */
  ptrdiff_t len = 0;
  env->copy_string_contents(env, args[1], NULL, &len);
  char *sym_name = malloc(len);
  if (!sym_name) { env->non_local_exit_signal(env, env->intern(env, "error"),
      env->make_string(env, "dyncall: alloc failed", 21)); return env->intern(env, "nil"); }
  env->copy_string_contents(env, args[1], sym_name, &len);
  void *fn = dlsym(handle, sym_name);
  free(sym_name);
  if (!fn) {
    env->non_local_exit_signal(env, env->intern(env, "error"),
        env->make_string(env, dlerror(), strlen(dlerror())));
    return env->intern(env, "nil");
  }

  /* Build argument array for Fdyncall_call:
     [fn, ret_sym, arg_type, arg_value, ...] */
  int remain = nargs - 2; /* skip library name */
  emacs_value *call_args = malloc((remain + 1) * sizeof(emacs_value));
  if (!call_args) {
    env->non_local_exit_signal(env, env->intern(env, "error"),
        env->make_string(env, "dyncall: alloc failed", 21));
    return env->intern(env, "nil");
  }
  /* call_args[0] = fn pointer — wrap in user-ptr */
  call_args[0] = env->make_user_ptr(env, NULL, fn);
  /* call_args[1..] = args[2..] */
  memcpy(call_args + 1, args + 2, remain * sizeof(emacs_value));

  emacs_value result = Fdyncall_call(env, remain + 1, call_args, data);

  if (handle != RTLD_DEFAULT)
    dlclose(handle);
  free(call_args);
  return result;
}

/* ── Keyword intern helper ──────────────────────────────── */

static emacs_value intern_keyword(emacs_env *env, const char *name) {
  /* (read ":name") → :name  */
  size_t klen = strlen(name);
  char *buf = malloc(klen + 2);
  if (!buf) goto fallback;
  buf[0] = ':';
  memcpy(buf + 1, name, klen + 1);
  emacs_value str = env->make_string(env, buf, klen + 1);
  free(buf);
  emacs_value result = env->funcall(env, env->intern(env, "read"), 1,
                                     (emacs_value[]){ str });
  if (env->non_local_exit_check(env) != emacs_funcall_exit_return)
    goto fallback;
  return result;

 fallback:
  env->non_local_exit_clear(env);
  return env->intern(env, name);
}

/* ── Module init ────────────────────────────────────────── */

int emacs_module_init(struct emacs_runtime *ert) {
  emacs_env *env = ert->get_environment(ert);
  if (!env) return 1;
  Qvoid    = intern_keyword(env, "void");
  Qint     = intern_keyword(env, "int");
  Quint    = intern_keyword(env, "uint");
  Qlong    = intern_keyword(env, "long");
  Qulong   = intern_keyword(env, "ulong");
  Qint64   = intern_keyword(env, "int64");
  Qfloat   = intern_keyword(env, "float");
  Qdouble  = intern_keyword(env, "double");
  Qstring  = intern_keyword(env, "string");
  Qpointer = intern_keyword(env, "pointer");

  struct { const char *name; emacs_value (*fn)(emacs_env*,ptrdiff_t,emacs_value[],void*); ptrdiff_t min, max; } funcs[] = {
    { "dyncall-load",  Fdyncall_load,  1, 1 },
    { "dyncall-sym",   Fdyncall_sym,   2, 2 },
    { "dyncall-close",  Fdyncall_close,  1, 1 },
    { "dyncall-call",  Fdyncall_call,  2, 100 },
    { "dyncall",       Fdyncall,       3, 100 },
  };

  for (size_t i = 0; i < sizeof(funcs)/sizeof(funcs[0]); i++) {
    emacs_value f = env->make_function(env, funcs[i].min, funcs[i].max,
                                        funcs[i].fn, "", NULL);
    emacs_value sym = env->intern(env, funcs[i].name);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){ sym, f });
  }

  env->funcall(env, env->intern(env, "provide"), 1,
               (emacs_value[]){ env->intern(env, "dyncall") });
  return 0;
}
