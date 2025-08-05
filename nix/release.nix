{
  self,
  lib,
  myEnv,
  nix-gitignore,
  projectConfig,
  ...
}:
let
  inherit (projectConfig) pname version;
  src = nix-gitignore.gitignoreSource [
    "/flake.nix"
    "/flake.lock"
  ] ../.;

  inherit (myEnv.beamPackages.minimal) fetchMixDeps buildMixRelease;
  inherit (myEnv.nodePackages) nodejs fetchNpmDeps;

  mixDeps = fetchMixDeps {
    pname = "${pname}-mix-deps";
    inherit version src;
    hash = "sha256-wIJDshMsiTLy6Xq0ONzCpcTyD4ynsCzHri/RBvCAb3s=";
  };

  npmDeps = if builtins.pathExists "${src}/assets/package.json" then
    fetchNpmDeps {
      pname = "${pname}-npm-deps";
      inherit version;
      src = "${src}/assets";
      hash = "sha256-D4/R/pmcL72/ff6M2OZR4/Ed6mxlLPgO2sJfI0ai22Y=";
      postBuild = ''
        # fix broken local packages
        local_packages=(
          "phoenix"
          "phoenix_html"
          "phoenix_live_view"
        )
        for package in ''\${local_packages[@]}; do
          path=node_modules/$package
          if [[ -L $path ]]; then
            echo "fixing local package - $package"
            rm $path
            cp -r ${mixDeps}/deps/$package node_modules/
          fi
        done
      '';
    }
  else null;
in
buildMixRelease {
  inherit pname version src;

  inherit mixDeps;
  nativeBuildInputs = [ nodejs ];

  removeCookie = false;

  preConfigure = ''
    substituteInPlace config/config.exs \
      --replace "config :tailwind," "config :tailwind, path: \"${myEnv.tailwind}/bin/tailwindcss\","\
      --replace "config :esbuild," "config :esbuild, path: \"${myEnv.esbuild}/bin/esbuild\", "

  '';

  preBuild = lib.concatStringsSep "\n" [
    # create a fake .git for the access of current commit hash via `git rev-parse HEAD`
    (
      let
        rev = if self ? rev then self.rev else "";
      in
      ''
        mkdir -p .git
        mkdir -p .git/objects
        mkdir -p .git/refs
        echo "${rev}" > .git/HEAD
      ''
    )

    # link node_modules
    (lib.optionalString (npmDeps != null) ''
      ln -s ${npmDeps}/node_modules assets/node_modules
    '')
  ];

  postBuild = ''
    HOME=$(pwd) mix assets.deploy
  '';
}
