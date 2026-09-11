/*
 * Freestanding string.h for the Darwin-host xnu-loader build.
 *
 * The loader's own code never calls libc string functions (it uses its
 * XnuCopyMem/XnuSetMem inline wrappers), but common.h does
 * #include <string.h>, and the compiler may still emit calls to
 * memcpy/memset/memmove for struct copies even under -ffreestanding.
 * These tiny inline definitions keep both cases satisfied without a libc.
 */
#ifndef _PD_FREESTANDING_STRING_H
#define _PD_FREESTANDING_STRING_H

#include <stddef.h>

static inline void *memcpy(void *dst, const void *src, __SIZE_TYPE__ n) {
  unsigned char *d = (unsigned char *)dst;
  const unsigned char *s = (const unsigned char *)src;
  while (n--) *d++ = *s++;
  return dst;
}

static inline void *memmove(void *dst, const void *src, __SIZE_TYPE__ n) {
  unsigned char *d = (unsigned char *)dst;
  const unsigned char *s = (const unsigned char *)src;
  if (d < s) {
    while (n--) *d++ = *s++;
  } else {
    d += n;
    s += n;
    while (n--) *--d = *--s;
  }
  return dst;
}

static inline void *memset(void *dst, int c, __SIZE_TYPE__ n) {
  unsigned char *d = (unsigned char *)dst;
  while (n--) *d++ = (unsigned char)c;
  return dst;
}

static inline int memcmp(const void *a, const void *b, __SIZE_TYPE__ n) {
  const unsigned char *x = (const unsigned char *)a;
  const unsigned char *y = (const unsigned char *)b;
  while (n--) {
    if (*x != *y) return *x - *y;
    x++;
    y++;
  }
  return 0;
}

static inline __SIZE_TYPE__ strlen(const char *s) {
  const char *p = s;
  while (*p) p++;
  return (__SIZE_TYPE__)(p - s);
}

#endif /* _PD_FREESTANDING_STRING_H */
