# xnu-loader built ON a Darwin host. The upstream flake builds it via
# pkgsCross.aarch64-multiplatform (a full Linux cross stdenv), which is not
# viable on Darwin. The loader itself is freestanding aarch64 code: compile
# with the host clang pinned to an aarch64-linux target (ELF objects), link
# with the aarch64 GNU ld using gnu-efi's linker script, and convert to the
# EFI PE image with the cross objcopy. Output layout matches the upstream
# package (img/EFI/BOOT/BOOTAA64.EFI), so image.nix needs no changes.
{
  lib,
  stdenv,
  python3,
  cmake,
  coreutils,
  dosfstools,
  mtools,
  clang,
  writeShellScript,
  runCommand,
  xnuLoaderSrc,
  gnuEfiAarch64,
  aarch64CrossBinutils,
}:

let
  binutilsBin = "${aarch64CrossBinutils}/bin";
  # xnu-loader's CMake runs `${CMAKE_C_COMPILER} -print-libgcc-file-name` and
  # appends the result to the link line. Answer with nothing: the flag is
  # guarded by $<BOOL:...>, and the loader's aarch64 code does not need
  # libgcc builtins (hardware div, no FP).
  targetCc = writeShellScript "aarch64-linux-gnu-clang" ''
    if [ "$1" = "-print-libgcc-file-name" ]; then
      exit 0
    fi
    exec ${clang}/bin/clang --target=aarch64-linux-gnu \
      -isystem ${./freestanding-include} "$@"
  '';
  # binutils >= 2.39 dropped the efi-app-* BFD target aliases; the PE output
  # target is pei-aarch64-little. xnu-loader's CMakeLists hardcodes
  # --target=efi-app-aarch64. Note --target sets BOTH the input and output
  # format, and a PE input format makes the ELF input unrecognizable - so the
  # shim splits it into explicit -I (ELF input) and -O (PE output).
  targetObjcopy = writeShellScript "aarch64-linux-gnu-objcopy" ''
    args=(-I elf64-littleaarch64)
    for a in "$@"; do
      if [ "$a" = "--target=efi-app-aarch64" ]; then
        args+=(-O pei-aarch64-little)
      else
        args+=("$a")
      fi
    done
    exec ${aarch64CrossBinutils}/bin/aarch64-unknown-linux-gnu-objcopy "''${args[@]}"
  '';
in
stdenv.mkDerivation {
  pname = "xnu-loader-aarch64-darwin";
  version = "0.1";

  src = xnuLoaderSrc;

  nativeBuildInputs = [
    python3
    cmake
    coreutils
    dosfstools
    mtools
    aarch64CrossBinutils
  ];

  cmakeFlags = [
    "-DGNU_EFI_DIR=${gnuEfiAarch64}"
    "-DARCH=aarch64"
    "-DXNU_LOADER_QEMU_VIRT=ON"
    "-DCMAKE_SYSTEM_NAME=Linux"
    "-DCMAKE_SYSTEM_PROCESSOR=aarch64"
    # The compiler probe must not try to LINK an aarch64-linux executable
    # (no target libc on a Darwin host); static-archive probes are enough.
    "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
    "-DCMAKE_C_COMPILER=${targetCc}"
    "-DCMAKE_LINKER=${binutilsBin}/aarch64-unknown-linux-gnu-ld"
    "-DCMAKE_OBJCOPY=${targetObjcopy}"
    "-DCMAKE_AR=${binutilsBin}/aarch64-unknown-linux-gnu-ar"
    "-DCMAKE_RANLIB=${binutilsBin}/aarch64-unknown-linux-gnu-ranlib"
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    # objcopy -O pei-aarch64-little produces a PE header with Subsystem=0,
    # Section/FileAlignment=0 and SizeOfHeaders=0 (binutils 2.46 dropped the
    # efi-app-* BFD target that used to fill these in). EDK2 rejects the image
    # ("Unsupported") unless they are fixed. Subsystem 10 = EFI application.
    python3 ${./patch-pe.py} xnu-loader.efi
    cp xnu-loader.efi $out/xnu-loader.efi
    mkdir -p $out/img/EFI/BOOT
    cp xnu-loader.efi $out/img/EFI/BOOT/BOOTAA64.EFI
    runHook postInstall
  '';

  # Skip the upstream xnu-loader.img FAT test image; image.nix only consumes
  # img/EFI/BOOT/BOOTAA64.EFI.
  dontFixup = true;

  meta = with lib; {
    description = "xnu-loader EFI loader (aarch64), built natively on a Darwin host";
    platforms = platforms.darwin;
  };
}
