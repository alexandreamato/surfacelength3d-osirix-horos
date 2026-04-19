#if MY_DEBUG_FLAG
#define DebugNSLog(fmt, ...) NSLog(fmt, ## __VA_ARGS__)
#else
#define DebugNSLog(fmt, ...)
#endif

