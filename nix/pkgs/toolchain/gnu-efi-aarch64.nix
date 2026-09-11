# gnu-efi built ON a Darwin host, targeting aarch64 UEFI (ELF objects +
# gnu-efi's ELF linker script + crt0), for the Darwin-host xnu-loader port.
# The upstream package only builds on Linux because its CC is the host
# compiler; here every tool is pinned explicitly: clang with an explicit
# aarch64-linux target produces ELF, and the archive/link tools come from the
# aarch64 cross binutils.
{
  lib,
  stdenvNoCC,
  gnu-efi,
  aarch64CrossBinutils,
  clang,
  writeShellScript,
}:

let
  binutilsBin = "${aarch64CrossBinutils}/bin";
  # Produces aarch64 ELF objects; also answers gnu-efi's -dumpversion and
  # -v probes (clang supports both, so its USING_CLANG detection works).
  targetCc = writeShellScript "aarch64-linux-gnu-clang" ''
    exec ${clang}/bin/clang --target=aarch64-linux-gnu "$@"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "gnu-efi-aarch64-cross";
  version = gnu-efi.version;

  src = gnu-efi.src;

  # -Werror in Make.defaults trips on clang warnings; upstream nixpkgs strips
  # it the same way.
  postPatch = ''
    substituteInPlace Make.defaults --replace "-Werror" ""
  '';

  makeFlags = [
    "ARCH=aarch64"
    "prefix="
    "CROSS_COMPILE="
    "CC=${targetCc}"
    "AS=${binutilsBin}/aarch64-unknown-linux-gnu-as"
    "LD=${binutilsBin}/aarch64-unknown-linux-gnu-ld"
    "AR=${binutilsBin}/aarch64-unknown-linux-gnu-ar"
    "RANLIB=${binutilsBin}/aarch64-unknown-linux-gnu-ranlib"
    "OBJCOPY=${binutilsBin}/aarch64-unknown-linux-gnu-objcopy"
  ];

  buildPhase = ''
    runHook preBuild
    # Build from the top: the recursion exports TOPDIR so the per-directory
    # Make.defaults -I$(TOPDIR)/inc points at the real include tree (a direct
    # `make -C lib` leaves TOPDIR pointing at lib/ and misses every header).
    # apps/ is skipped; only lib (libefi.a) and gnuefi (libgnuefi.a, crt0,
    # linker script) are wanted.
    make lib gnuefi $makeFlags
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    # Same layout the Linux gnu-efi package exposes, which is what
    # xnu-loader's CMake expects (GNU_EFI_DIR/include/efi/... + GNU_EFI_LIB_DIR).
    # The build lands in aarch64/ (OBJDIR = $(TOPDIR)/$(ARCH)).
    mkdir -p $out/lib $out/include
    cp -R inc/. $out/include/efi/
    cp aarch64/lib/libefi.a $out/lib/
    cp aarch64/gnuefi/libgnuefi.a aarch64/gnuefi/crt0-efi-aarch64.o $out/lib/
    # The linker scripts live in the gnuefi SOURCE dir ($(SRCDIR)), not OBJDIR.
    cp gnuefi/elf_aarch64_efi.lds gnuefi/elf_aarch64_efi_local.lds $out/lib/
    runHook postInstall
  '';

  dontFixup = true;

  meta = with lib; {
    description = "gnu-efi for aarch64 UEFI, built on a Darwin host";
    platforms = platforms.darwin;
  };
}
