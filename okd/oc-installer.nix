{ stdenv, fetchFromGitHub, go, makeWrapper }:
let
  version = "4.8";
  rev = "aaa978bb5d76472df23f6e90293e68aaa43a8457";
in
  stdenv.mkDerivation rec{
    pname = "openshift-installer";
    inherit version;

    src = fetchFromGitHub {
      owner = "openshift";
      repo = "installer";
      inherit rev;
      sha256 = "sha256-JQ3+ASITUk7F30Eh4Le2Od9ClY1jhH8ljvHyJc090E4=";
    };

    nativeBuildInputs = [go makeWrapper];

    patchPhase = ''
      patchShebangs ./hack

      # resolve symlink in source

      NETCONFIG_CRD="$(readlink -f ./data/data/manifests/openshift/cluster-networkconfig-crd.yaml)"
      unlink ./data/data/manifests/openshift/cluster-networkconfig-crd.yaml
      cp $NETCONFIG_CRD ./data/data/manifests/openshift/cluster-networkconfig-crd.yaml
    '';

    buildPhase = ''
      mkdir $out
      export HOME=$(pwd)
      export GOPATH=$(pwd)/go
      export BUILD_VERSION=${version}
      export MODE=dev
      export SOURCE_GIT_COMMIT=${rev}
      export OUTPUT=$out/bin/openshift-install
      ./hack/build.sh
    '';

    installPhase = ''
      mv ./data/data $out
      wrapProgram $out/bin/openshift-install \
        --set OPENSHIFT_INSTALL_DATA $out/data
    '';

    dontPatchShebangs = true;

  }