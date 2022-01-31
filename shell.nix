{ pkgs ? (import ./pin.nix) }:

pkgs.mkShell {
  buildInputs = [(import ./okd.nix { inherit pkgs; })];
}
