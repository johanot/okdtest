# OKD Nix Qemu Test

Tries to bootstrap a three node OKD v4.8 cluster.

"tries" is the keyword here. Master bootstrap networking doesn't quite work,
and the bootstrap node etcd operator fails before having a chance to start listening on 2379.

# How to run

- install Nix: https://nixos.org/download.html

Single-user mode should be sufficient.
Docker-based Nix-installations however won't be able to spawn VMs.

Checkout this repo and change the `sshKey`-reference in `okd/bootstrap-config.nix` to point to a real ssh public key.

From the checkout root of this repo, type:

`nix-shell`

(wait for everything to build, it will take a while)

once inside the nix-shell:

`startokd`
