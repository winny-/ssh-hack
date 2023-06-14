{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix/0c064fa9dd025069cc215b0a8b4eb5ea734aceb0";
  };

  outputs = {
    self,
    dream2nix,
  } @ inp: (let
     output = dream2nix.lib.makeFlakeOutputs {
       systems = ["x86_64-linux"];
       config.projectRoot = ./.;
       source = ./.;
       projects = ./projects.toml;
     };
  in
    output); # // { packages.x86_64-linux.default = output.packages.x86_64-linux.ssh-hack; });
}
