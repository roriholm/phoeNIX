{
  description = "Nix infrastructure for Phoenix project including Elixir development environment, package, and NixOS module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    beam-utils = {
      url = "github:nix-giant/beam-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      beam-utils,
      ...
    }@inputs:
    let
      projectConfig = {
        pname = builtins.replaceStrings ["\n"] [""] (builtins.readFile (
          nixpkgs.legacyPackages.x86_64-linux.runCommand "mix-app-name" {} ''
            ${nixpkgs.legacyPackages.x86_64-linux.gnused}/bin/sed -n 's/.*app: :\([^,]*\).*/\1/p' ${./mix.exs} | ${nixpkgs.legacyPackages.x86_64-linux.gnused}/bin/sed 's/_/-/g' > $out
          ''
        ));
        version = builtins.replaceStrings ["\n"] [""] (builtins.readFile (
          nixpkgs.legacyPackages.x86_64-linux.runCommand "mix-version" {} ''
            ${nixpkgs.legacyPackages.x86_64-linux.gnused}/bin/sed -n 's/.*version: "\([^"]*\)".*/\1/p' ${./mix.exs} > $out
          ''
        ));
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            beam-utils.overlays.default
            (import ./nix/overlay.nix)
          ];
        };
      in
      {
        devShells = {
          default = pkgs.myCallPackage ./nix/shell.nix { };
        };

        packages =
          let
            release = pkgs.myCallPackage ./nix/release.nix ({ inherit projectConfig; } // inputs);

            buildDockerImage =
              hostSystem: pkgs.myCallPackage ./nix/docker-image.nix ({ inherit release hostSystem; } // inputs);

            docker-images = builtins.listToAttrs (
              map (hostSystem: {
                name = "docker-image-triggered-by-${hostSystem}";
                value = buildDockerImage hostSystem;
              }) flake-utils.lib.defaultSystems
            );
          in
          { default = release; inherit release; } // docker-images;
      }
    ) // {
      nixosModules.default = import ./nix/module.nix { inherit self projectConfig; };
    };
}
