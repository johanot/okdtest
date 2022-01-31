{ pkgs ? (import ./pin.nix) }:
let
  lib = pkgs.lib;
  oc-installer = pkgs.callPackage ./okd/oc-installer.nix {};
  fcos = pkgs.callPackage ./okd/fcos.nix {};
  bootstrapConfig = pkgs.callPackage ./okd/bootstrap-config.nix { inherit oc-installer; };
  startVM = name: vmConfig: pkgs.callPackage ./okd/start-vm.nix { bootDisk = fcos; inherit name vmConfig; };

  vmDefaults = {
    cores = 4; memorySize = 2048;
  };

  VMs = {
    bootstrap = { cores = 8; sshHostPort = 2221; type = "bootstrap"; ip = "10.0.5.15"; mac = "52:54:00:12:00:05"; };
    m1 = { sshHostPort = 2222; type = "master"; ip = "10.0.5.16"; mac = "52:54:00:12:00:06"; };
    m2 = { sshHostPort = 2223; type = "master"; ip = "10.0.5.17"; mac = "52:54:00:12:00:07"; };
    m3 = { sshHostPort = 2224; type = "master"; ip = "10.0.5.18"; mac = "52:54:00:12:00:08"; };
  };

  ignition = node: ip: mac: type: pkgs.writeText "${node}-${type}.ign" (
    let
      oldAttrs = builtins.fromJSON (builtins.readFile "${bootstrapConfig}/${type}.ign");
      oldFiles = (oldAttrs.storage or {}).files or [];
      base64String = str: builtins.readFile (pkgs.runCommand "base64" {} ''
        echo -n '${str}' | base64 -w 0 >$out
      '');
    in
    builtins.toJSON 
      (oldAttrs // { 
        storage.files = oldFiles ++ [{
          path = "/etc/hostname";
          mode = 420;
          overwrite = true;
          contents.source = "data:,${node}";
        }
        {
          path = "/etc/NetworkManager/conf.d/noauto.conf";
          mode = 256;
          contents.source = "data:text/plain;charset=utf-8;base64," + 
            base64String ''
              [main]
              no-auto-default=${mac}
            '';
        }
        {
          path = "/etc/NetworkManager/system-connections/Wired connection 2.nmconnection";
          mode = 256;
          contents.source = "data:text/plain;charset=utf-8;base64," + 
            base64String ''
              [ethernet]
              mac-address=${mac}

              [connection]
              id=Wired connection 2
              type=ethernet
              timestamp=0
              mac-address=${mac}

              [ipv6]
              method=disabled

              [ipv4]
              addresses=${ip}/24
              method=manual
            '';
        }
        {
          path = "/etc/hosts";
          append = [{
            source = "data:text/plain;charset=utf-8;base64," + 
              base64String ((lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${v.ip} ${n} ${n}.example.com") VMs)) + ''

                ${VMs.m1.ip} *.apps.example.com api.example.com api-int.example.com
                ${VMs.bootstrap.ip} bootstrap.example.com
                ${VMs.m1.ip} master1.example.com
                ${VMs.m2.ip} master2.example.com
                ${VMs.m3.ip} master3.example.com
              '');
         }];
        }
        ];
      }));

  VMsEnriched = lib.mapAttrsToList (name: cfg: 
  let
    mergedCfg = vmDefaults // cfg // { ignition = ignition name cfg.ip cfg.mac cfg.type; };
  in
  {
    inherit name;
    startScript = startVM name mergedCfg;
  } // mergedCfg) VMs;

  vmCount = (lib.length VMsEnriched)-1;

  startAll = pkgs.writeShellScript "start-all" ''
    if [ -z "$TESTTMPDIR" ]; then
      export TESTTMPDIR=$(mktemp -d nix-vm.XXXXXXXXXX --tmpdir)
      echo "starting switch in $TESTTMPDIR ..."
      ${pkgs.vde2}/bin/vde_switch -s $TESTTMPDIR/vde --dirmode 0700 -d -p $TESTTMPDIR/vde.pid
    fi
    export VDE_PID=$(cat $TESTTMPDIR/vde.pid)

    declare -a procs
    declare -a pids
    ${lib.concatStringsSep "\n" (lib.imap0 (i: vm: ''procs[${toString i}]="${vm.startScript}"'') VMsEnriched)}
    for i in ''${!procs[@]}; do
      ''${procs[$i]} &
      pids[$i]=$!
    done

    # wait for all pids
    for pid in ''${pids[*]}; do
        wait $pid
    done

    kill -s 15 $VDE_PID
    wait $VDE_PID
    rm -fr $TESTTMPDIR
  '';
in
  pkgs.runCommand "test-scripts" {} ''
    mkdir -p $out/bin
    ln -s ${startAll} $out/bin/startokd
  ''
