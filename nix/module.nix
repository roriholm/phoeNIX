{ self, projectConfig }:
{ config, lib, pkgs, ... }:
  let
   inherit (projectConfig) pname;
   phx_project_name = builtins.replaceStrings ["-"] ["_"] pname;
   cfg = config.services.${pname};
  in
  {
    options.services.${pname} = {
      enable = lib.mkEnableOption "${pname}";
      port = lib.mkOption {
        type = lib.types.port;
        default = 4000;
      };
      databaseUrl = lib.mkOption {
        type = lib.types.str;
        default = "postgres://postgres:postgres@localhost/${phx_project_name}_prod";
      };
      environment = lib.mkOption {
        type = lib.types.enum [ "dev" "test" "prod" ];
        default = "prod";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
      };
      secretKeyBase = lib.mkOption {
        type = lib.types.str;
        description = "Secret key for signing/encrypting cookies and tokens";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [
        (pkgs.writeShellScriptBin pname ''
          export PORT=${toString cfg.port}
          export DATABASE_URL="${cfg.databaseUrl}"
          export MIX_ENV="${cfg.environment}"
          export PHX_HOST="${cfg.host}"
          export SECRET_KEY_BASE="${cfg.secretKeyBase}"
          export PHX_SERVER="true"
          exec ${self.packages.${pkgs.system}.release}/bin/${phx_project_name} "$@"
        '')
      ];
      systemd.services.${pname} = {
        description = "${pname} Service";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        environment = {
          PORT = toString cfg.port;
          DATABASE_URL = cfg.databaseUrl;
          MIX_ENV = cfg.environment;
          PHX_HOST = cfg.host;
          SECRET_KEY_BASE = cfg.secretKeyBase;
          PHX_SERVER = "true";
        };

        serviceConfig = {
          Type = "simple";
          ExecStart = "${self.packages.${pkgs.system}.release}/bin/${phx_project_name} start";
          Restart = "on-failure";
        };
      };
    };
  }
