/*
 * Apple Blocks ABI compatibility.
 *
 * clang's -fblocks lowering references the runtime entry points with two
 * leading underscores in the source (__Block_copy, __NSConcreteGlobalBlock,
 * __Block_object_assign, ...), which become three-underscore Mach-O symbols.
 * The Swift-derived BlocksRuntime here defines them with one leading
 * underscore (_Block_copy, ...), two in Mach-O. Every consumer compiled with
 * -fblocks (libxpc, launchctl, libc's block-using call sites) therefore needs
 * these forwarding definitions to link, and dyld needs them to resolve at
 * load time. Kept in the dispatch component so the symbols land inside
 * libdyld/libSystem exactly where the underscore-single versions live.
 */

extern void *_Block_copy(const void *arg);
extern void _Block_release(const void *arg);
extern void _Block_object_assign(void *destAddr, const void *object, const int flags);
extern void _Block_object_dispose(const void *object, const int flags);
extern void *_NSConcreteGlobalBlock[32];
extern void *_NSConcreteStackBlock[32];

__attribute__((used))
void *__Block_copy(const void *arg) { return _Block_copy(arg); }
__attribute__((used))
void __Block_release(const void *arg) { _Block_release(arg); }
__attribute__((used))
void __Block_object_assign(void *destAddr, const void *object, const int flags) {
    _Block_object_assign(destAddr, object, flags);
}
__attribute__((used))
void __Block_object_dispose(const void *object, const int flags) {
    _Block_object_dispose(object, flags);
}
__attribute__((used)) void *__NSConcreteGlobalBlock[32] = { 0 };
__attribute__((used)) void *__NSConcreteStackBlock[32] = { 0 };
