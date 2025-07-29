// Windows
#if _WIN32 || _WIN64
#if _WIN64
#define ENVIRONMENT64
#else
#define ENVIRONMENT32
#endif
#endif

// Linux, MinGW
#if __GNUC__
#if __x86_64__ || __ppc64__
#define ENVIRONMENT64
#else
#define ENVIRONMENT32
#endif
#endif

// ---------------------------------------------------------------------
#ifdef ENVIRONMENT32
#define byte    unsigned char
#define word    unsigned short
#define dword   unsigned long
#define qword   unsigned long long
#define word_s  signed short
#define dword_s signed long
#define qword_s signed long long
#endif

// ---------------------------------------------------------------------
#ifdef ENVIRONMENT64
#define byte    unsigned char
#define word    unsigned short
#define dword   unsigned int
#define qword   unsigned long long
#define word_s  signed short
#define dword_s signed int
#define qword_s signed long long
#endif
