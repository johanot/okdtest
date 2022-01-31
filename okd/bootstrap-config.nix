{
  runCommand,
  writeText,
  oc-installer,
}:
let
  install-config = {
    apiVersion = "v1";
    baseDomain = "example.com";
    compute = [{
      hyperthreading = "Disabled";
      name = "worker";
      replicas = 0; # no compute nodes, just go with 3 control-planes with scheduling enabled
    }];
    controlPlane = {
      hyperthreading = "Disabled";
      name = "master";
      replicas = 3;
    };
    metadata.name = "test";
    networking = {
      clusterNetwork = [{
        cidr = "10.230.0.0/16";
        hostPrefix = 24;
      }];
      networkType = "OVNKubernetes";
      serviceNetwork = [ "10.240.0.0/16" ];
    };
    platform.none = {};
    pullSecret = ''{"auths":{"fake":{"auth":"aWQ6cGFzcwo="}}}'';
    sshKey = builtins.readFile /path/to/ssh/public/key.pub; # replace with real path here
  };
in
runCommand "okd-bootstrap-config" { nativeBuildInputs = [oc-installer]; } ''
  mkdir -p $out
  cd $out
  # create install-config "yaml" (actually json) file and copy it to the writable build env,
  # since openshift-install wants to "consume" (unlink) it, for some reason.
  cp ${writeText "install-config.json" (builtins.toJSON install-config)} ./install-config.yaml
  openshift-install create manifests
  openshift-install create ignition-configs
''