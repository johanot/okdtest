{ stdenv, fetchurl, xz }:
let
  pname = "fedora-coreos";
  version = "35.20220103.3.0";
  artifact = "${pname}-${version}-qemu.x86_64.qcow2";
in
  stdenv.mkDerivation rec{
    inherit pname version;

    src = fetchurl {
      url = "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/${artifact}.xz";
      sha256 = "sha256-hmxL3BX9XSP3GiY3dsuPRfIdmUYVYYzArCFASl4Bwf4=";
    };

    nativeBuildInputs = [xz];

    unpackPhase = ''
      xz -T 0 -dc $src >${artifact}
    '';

    installPhase = ''
      mkdir $out
      mv ${artifact} $out/disk.img
    '';
  }
