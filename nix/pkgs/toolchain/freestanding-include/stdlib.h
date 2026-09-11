/*
 * Empty stdlib.h: freestanding.h-style stub for the Darwin-host
 * xnu-loader build. include/uefi/smbios.h includes <stdlib.h> but nothing
 * in the loader references any libc allocation/exit routine (the loader
 * allocates through EFI boot services).
 */
#ifndef _PD_FREESTANDING_STDLIB_H
#define _PD_FREESTANDING_STDLIB_H
#endif /* _PD_FREESTANDING_STDLIB_H */