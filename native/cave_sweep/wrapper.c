/* Minimal Godot 4.6 C binding. ABI sizes and hashes are checked by the builder. */
#include "gdextension_interface.h"
#include "kernel.h"
#include <stddef.h>

/* Opaque storage, aligned for any public builtin, never interpreted by C. */
typedef union { max_align_t align; unsigned char bytes[64]; } Builtin;
typedef struct { GDExtensionObjectPtr owner; } KernelInstance;

static GDExtensionClassLibraryPtr library;
static GDExtensionInterfaceMemAlloc mem_alloc;
static GDExtensionInterfaceMemFree mem_free;
static GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;
static GDExtensionInterfaceStringNewWithUtf8Chars string_new;
static GDExtensionInterfaceVariantGetType variant_type;
static GDExtensionInterfaceVariantDestroy variant_destroy;
static GDExtensionInterfaceVariantNewNil variant_nil;
static GDExtensionInterfaceClassdbConstructObject2 construct_object;
static GDExtensionInterfaceObjectDestroy destroy_object;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionInterfaceObjectMethodBindPtrcall object_ptrcall;
static GDExtensionInterfaceClassdbGetMethodBind get_method;
static GDExtensionInterfaceClassdbRegisterExtensionClass4 register_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionInterfacePackedFloat64ArrayOperatorIndex array_index;
static GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst array_index_const;
static GDExtensionPtrConstructor array_new, array_copy;
static GDExtensionPtrDestructor array_free, name_free, string_free;
static GDExtensionPtrBuiltInMethod array_size, array_resize;
static GDExtensionVariantFromTypeConstructorFunc variant_from_array;
static GDExtensionVariantFromTypeConstructorFunc variant_from_int;
static GDExtensionVariantGetInternalPtrFunc array_from_variant;
static GDExtensionMethodBindPtr notification;
static Builtin class_name, parent_name;

static GDExtensionPtrBuiltInMethod builtin_method(
        GDExtensionInterfaceVariantGetPtrBuiltinMethod get_builtin,
        const char *name, GDExtensionInt hash) {
    Builtin method;
    name_new(&method, name);
    GDExtensionPtrBuiltInMethod result = get_builtin(
        GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY, &method, hash);
    name_free(&method);
    return result;
}

static void scan_array(GDExtensionConstTypePtr edges,
        GDExtensionConstTypePtr query, GDExtensionUninitializedTypePtr result) {
    int64_t edge_count = 0, query_count = 0, result_count = 2, resize_error = 0;
    array_size((void *)edges, NULL, &edge_count, 0);
    array_size((void *)query, NULL, &query_count, 0);
    const double *edge_values = edge_count ? array_index_const(edges, 0) : NULL;
    const double *query_values = query_count ? array_index_const(query, 0) : NULL;
    CaveSweepHit hit = cave_sweep_scan(edge_values, (size_t)edge_count,
        query_values, (size_t)query_count);
    array_new(result, NULL);
    const GDExtensionConstTypePtr resize_args[] = { &result_count };
    array_resize(result, resize_args, &resize_error, 1);
    if (!resize_error) {
        double *values = array_index(result, 0);
        values[0] = (double)hit.index;
        values[1] = hit.time;
    }
}

static void scan_call(void *userdata, GDExtensionClassInstancePtr instance,
        const GDExtensionConstVariantPtr *args, GDExtensionInt count,
        GDExtensionVariantPtr result, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    error->error = GDEXTENSION_CALL_OK;
    error->argument = 0;
    error->expected = 0;
    if (count != 2) {
        error->error = count < 2 ? GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS
                                 : GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        error->expected = 2;
        return;
    }
    for (int i = 0; i < 2; ++i) {
        if (variant_type(args[i]) != GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY) {
            error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
            error->argument = i;
            error->expected = GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY;
            return;
        }
    }
    Builtin output;
    scan_array(array_from_variant((void *)args[0]),
        array_from_variant((void *)args[1]), &output);
    /* Godot supplies an initialized Variant; replace its existing value. */
    variant_destroy(result);
    variant_from_array(result, &output);
    array_free(&output);
}

static void scan_ptrcall(void *userdata, GDExtensionClassInstancePtr instance,
        const GDExtensionConstTypePtr *args, GDExtensionTypePtr result) {
    (void)userdata; (void)instance;
    Builtin output;
    scan_array(args[0], args[1], &output);
    /* Ptrcall return values are initialized builtin storage. */
    array_free(result);
    const GDExtensionConstTypePtr copy_args[] = { &output };
    array_copy(result, copy_args);
    array_free(&output);
}

static int64_t overlap_array(GDExtensionConstTypePtr edges,
        GDExtensionConstTypePtr query) {
    int64_t edge_count = 0, query_count = 0;
    array_size((void *)edges, NULL, &edge_count, 0);
    array_size((void *)query, NULL, &query_count, 0);
    const double *edge_values = edge_count ? array_index_const(edges, 0) : NULL;
    const double *query_values = query_count ? array_index_const(query, 0) : NULL;
    return cave_sweep_overlap(edge_values, (size_t)edge_count,
        query_values, (size_t)query_count);
}

static void overlap_call(void *userdata, GDExtensionClassInstancePtr instance,
        const GDExtensionConstVariantPtr *args, GDExtensionInt count,
        GDExtensionVariantPtr result, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    error->error = GDEXTENSION_CALL_OK;
    error->argument = 0;
    error->expected = 0;
    if (count != 2) {
        error->error = count < 2 ? GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS
                                 : GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        error->expected = 2;
        return;
    }
    for (int i = 0; i < 2; ++i) {
        if (variant_type(args[i]) != GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY) {
            error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
            error->argument = i;
            error->expected = GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY;
            return;
        }
    }
    int64_t index = overlap_array(array_from_variant((void *)args[0]),
        array_from_variant((void *)args[1]));
    variant_destroy(result);
    variant_from_int(result, &index);
}

static void overlap_ptrcall(void *userdata, GDExtensionClassInstancePtr instance,
        const GDExtensionConstTypePtr *args, GDExtensionTypePtr result) {
    (void)userdata; (void)instance;
    *(int64_t *)result = overlap_array(args[0], args[1]);
}

static GDExtensionObjectPtr create_instance(void *userdata,
        GDExtensionBool notify_postinitialize) {
    (void)userdata;
    GDExtensionObjectPtr object = construct_object(&parent_name);
    if (!object) return NULL;
    KernelInstance *instance = mem_alloc(sizeof(*instance));
    if (!instance) { destroy_object(object); return NULL; }
    instance->owner = object;
    set_instance(object, &class_name, instance);
    if (notify_postinitialize) {
        int64_t what = 0; /* Object::NOTIFICATION_POSTINITIALIZE */
        GDExtensionBool reversed = 0;
        const GDExtensionConstTypePtr args[] = { &what, &reversed };
        object_ptrcall(notification, object, args, NULL);
    }
    return object;
}

static void free_instance(void *userdata, GDExtensionClassInstancePtr instance) {
    (void)userdata;
    mem_free(instance);
}

static GDExtensionPropertyInfo array_property(Builtin *name,
        Builtin *empty_name, Builtin *empty_string) {
    GDExtensionPropertyInfo info = {0};
    info.type = GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY;
    info.name = name;
    info.class_name = empty_name;
    info.hint_string = empty_string;
    info.usage = 6; /* PROPERTY_USAGE_DEFAULT */
    return info;
}

static void initialize(void *userdata, GDExtensionInitializationLevel level) {
    (void)userdata;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    name_new(&class_name, "CaveSweepKernel");
    name_new(&parent_name, "RefCounted");
    GDExtensionClassCreationInfo4 creation = {0};
    creation.is_exposed = 1;
    creation.create_instance_func = create_instance;
    creation.free_instance_func = free_instance;
    register_class(library, &class_name, &parent_name, &creation);

    Builtin method_name, edges_name, query_name, result_name, empty_name, empty_string;
    name_new(&method_name, "scan");
    name_new(&edges_name, "edges");
    name_new(&query_name, "query");
    name_new(&result_name, "");
    name_new(&empty_name, "");
    string_new(&empty_string, "");
    GDExtensionPropertyInfo args[2] = {
        array_property(&edges_name, &empty_name, &empty_string),
        array_property(&query_name, &empty_name, &empty_string)
    };
    GDExtensionPropertyInfo result = array_property(&result_name, &empty_name, &empty_string);
    GDExtensionClassMethodArgumentMetadata metadata[2] = {0, 0};
    GDExtensionClassMethodInfo method = {0};
    method.name = &method_name;
    method.call_func = scan_call;
    method.ptrcall_func = scan_ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL | GDEXTENSION_METHOD_FLAG_CONST;
    method.has_return_value = 1;
    method.return_value_info = &result;
    method.argument_count = 2;
    method.arguments_info = args;
    method.arguments_metadata = metadata;
    register_method(library, &class_name, &method);
    Builtin overlap_name;
    name_new(&overlap_name, "overlap");
    GDExtensionPropertyInfo overlap_result = result;
    overlap_result.type = GDEXTENSION_VARIANT_TYPE_INT;
    GDExtensionClassMethodInfo overlap_method = method;
    overlap_method.name = &overlap_name;
    overlap_method.call_func = overlap_call;
    overlap_method.ptrcall_func = overlap_ptrcall;
    overlap_method.return_value_info = &overlap_result;
    overlap_method.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64;
    register_method(library, &class_name, &overlap_method);
    name_free(&overlap_name);
    name_free(&method_name); name_free(&edges_name); name_free(&query_name);
    name_free(&result_name); name_free(&empty_name); string_free(&empty_string);
}

static void deinitialize(void *userdata, GDExtensionInitializationLevel level) {
    (void)userdata;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    unregister_class(library, &class_name);
    name_free(&class_name);
    name_free(&parent_name);
}

#if defined(_WIN32)
__declspec(dllexport)
#else
__attribute__((visibility("default")))
#endif
GDExtensionBool cave_sweep_library_init(GDExtensionInterfaceGetProcAddress get_proc,
        GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *init) {
#define LOAD(type, variable, symbol) \
    variable = (type)get_proc(symbol); if (!(variable)) return 0
    LOAD(GDExtensionInterfaceMemAlloc, mem_alloc, "mem_alloc");
    LOAD(GDExtensionInterfaceMemFree, mem_free, "mem_free");
    LOAD(GDExtensionInterfaceStringNameNewWithUtf8Chars, name_new, "string_name_new_with_utf8_chars");
    LOAD(GDExtensionInterfaceStringNewWithUtf8Chars, string_new, "string_new_with_utf8_chars");
    LOAD(GDExtensionInterfaceVariantGetType, variant_type, "variant_get_type");
    LOAD(GDExtensionInterfaceVariantDestroy, variant_destroy, "variant_destroy");
    LOAD(GDExtensionInterfaceVariantNewNil, variant_nil, "variant_new_nil");
    LOAD(GDExtensionInterfaceClassdbConstructObject2, construct_object, "classdb_construct_object2");
    LOAD(GDExtensionInterfaceObjectDestroy, destroy_object, "object_destroy");
    LOAD(GDExtensionInterfaceObjectSetInstance, set_instance, "object_set_instance");
    LOAD(GDExtensionInterfaceObjectMethodBindPtrcall, object_ptrcall, "object_method_bind_ptrcall");
    LOAD(GDExtensionInterfaceClassdbGetMethodBind, get_method, "classdb_get_method_bind");
    LOAD(GDExtensionInterfaceClassdbRegisterExtensionClass4, register_class, "classdb_register_extension_class4");
    LOAD(GDExtensionInterfaceClassdbRegisterExtensionClassMethod, register_method, "classdb_register_extension_class_method");
    LOAD(GDExtensionInterfaceClassdbUnregisterExtensionClass, unregister_class, "classdb_unregister_extension_class");
    LOAD(GDExtensionInterfacePackedFloat64ArrayOperatorIndex, array_index, "packed_float64_array_operator_index");
    LOAD(GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst, array_index_const, "packed_float64_array_operator_index_const");
    GDExtensionInterfaceVariantGetPtrConstructor constructor;
    GDExtensionInterfaceVariantGetPtrDestructor destructor;
    GDExtensionInterfaceVariantGetPtrBuiltinMethod get_builtin;
    GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
    GDExtensionInterfaceGetVariantGetInternalPtrFunc get_internal;
    LOAD(GDExtensionInterfaceVariantGetPtrConstructor, constructor, "variant_get_ptr_constructor");
    LOAD(GDExtensionInterfaceVariantGetPtrDestructor, destructor, "variant_get_ptr_destructor");
    LOAD(GDExtensionInterfaceVariantGetPtrBuiltinMethod, get_builtin, "variant_get_ptr_builtin_method");
    LOAD(GDExtensionInterfaceGetVariantFromTypeConstructor, from_type, "get_variant_from_type_constructor");
    LOAD(GDExtensionInterfaceGetVariantGetInternalPtrFunc, get_internal, "variant_get_ptr_internal_getter");
#undef LOAD
    name_free = destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
    string_free = destructor(GDEXTENSION_VARIANT_TYPE_STRING);
    array_free = destructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY);
    array_new = constructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY, 0);
    array_copy = constructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY, 1);
    variant_from_array = from_type(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY);
    variant_from_int = from_type(GDEXTENSION_VARIANT_TYPE_INT);
    array_from_variant = get_internal(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY);
    if (!name_free || !string_free || !array_free || !array_new || !array_copy ||
            !variant_from_array || !variant_from_int || !array_from_variant) return 0;
    array_size = builtin_method(get_builtin, "size", 3173160232LL);
    array_resize = builtin_method(get_builtin, "resize", 848867239LL);
    Builtin object_name, notification_name;
    name_new(&object_name, "Object"); name_new(&notification_name, "notification");
    notification = get_method(&object_name, &notification_name, 4023243586LL);
    name_free(&object_name); name_free(&notification_name);
    if (!array_size || !array_resize || !notification) return 0;
    library = p_library;
    init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    init->userdata = NULL;
    init->initialize = initialize;
    init->deinitialize = deinitialize;
    return 1;
}
