# PhoeNIX

This is a Nix setup for developing and deploying Elixir Phoenix apps. Based on [nix-giant](https://github.com/nix-giant/nix-dev-templates/tree/main/elixir/phoenix/nix) dev templates.
The main extension is a module definition that uses the app name from `mix.exs` to define a systemd service using the default database

# Setup
Start with a fresh folder containing only the contents of this repo.

```
nix develop
mix archive.install hex phx_new
mix phx.new . --app my_phoenix_app
```
Don't overwrite the Readme with phx.new, you still need to read me.

Now we need to work around the default setup to use our provided version of `tailwindcss`.
First go to `config/config.exs` and look for where it say:
```
config :tailwind,
  version: "4.1.7",
```
change this to:
```
config :tailwind,
  path: System.find_executable("tailwindcss")
```

Next go to `mix.exs` and find the alias:
```
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
```
delete `assets.setup` out of there.

Now you are free to run
```
mix setup
```

# Run
`iex -S mix phx.server`

# Build
You will need to `git add .` the generated files then run
`nix build`. There will probably be a hash mismatch. See next section.

# Develop

Adding npm and mix packages works in the normal way. (Add them to `mix.exs` or `package.json`. Make sure to `npm install --prefix assets` and  `git add assets/package-lock.json`.) However next time you build it will cause a FOD hash mismatch.
Looks like:
```
error: hash mismatch in fixed-output derivation '/nix/store/4w7dbvrrf160a94jfyq6zzlldrs0ndhh-${pname}-mix-deps-0.1.0.drv':
         specified: sha256-80+QZV7CFokVbIwVkFK0ckfI/4YannWF3ws1q9s9j+g=
            got:    sha256-73q7qCBWRzRRRs4dA55yN/EWo9o2Z9FW0xyIBHaJpLE=
```
Replace the hash in `nix/release.nix`.

# Deploy
Here's an example of a flake defining a NixOS system that runs the app:
```
{
  inputs = {
    phx-app.url = "path:/home/path/to/my_phoenix_app";
  };

  outputs = { self, nixpkgs, phx-app }: let
    system = "x86_64-linux";
  in {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        phx-app.nixosModules.default {
          services.my-phoenix-app = {
            enable = true;
            secretKeyBase = "";
          };
        }

      ];
    };
  };
}
```

Of course there are lots of little things that can go wrong. Let me know if this guide was helpful or if you ran into problems I should address.
