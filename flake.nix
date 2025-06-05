
{
  description = "ktransformers flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils } @ inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        cudaPackages = pkgs.cudaPackages_12_1;
        
        ktransformers = pkgs.stdenv.mkDerivation {
          name = "ktransformers";
          src = self;
          
          nativeBuildInputs = [
            pkgs.cmake
            pkgs.ninja
            pkgs.patchelf
          ];
          
          buildInputs = [
            pkgs.gcc11
            pkgs.libnuma.dev
            pkgs.libtbb.dev
            pkgs.openssl.dev
            pkgs.libcurl
            pkgs.libaio
            pkgs.gflags.dev
            pkgs.zlib.dev
            pkgs.fmt.dev
            cudaPackages.cudatoolkit
          ];
          
          configurePhase = ''
            bash install.sh
          '';
          
          buildPhase = ''
            export USE_NUMA=1
            bash install.sh
          '';
          
          installPhase = ''
            mkdir -p $out/bin
            cp -r . $out/
            
            # Install service scripts
            install -Dm755 scripts/start_server.sh $out/bin/ktransformers-start
            install -Dm755 scripts/stop_server.sh $out/bin/ktransformers-stop
            
            # Create wrapper for main binary
            echo '#!/bin/sh
            exec ${ktransformers.pythonEnv}/bin/python $out/ktransformers/main.py "$@"
            ' > $out/bin/ktransformers
            chmod +x $out/bin/ktransformers
          '';
        };
      in
      {
        packages = {
          default = ktransformers;
          inherit ktransformers;
        };
        
        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
          
          buildInputs = [
            (pkgs.python3.withPackages (ps: [
              ps.torch
              ps.torchvision
              ps.torchaudio
              ps.packaging
              ps.numpy
            ]))
          ];
          
          shellHook = ''
            export CUDA_PATH=${cudaPackages.cudatoolkit}
            export LD_LIBRARY_PATH=${cudaPackages.cudatoolkit}/lib:$LD_LIBRARY_PATH
            export PATH=${cudaPackages.cudatoolkit}/bin:$PATH
          '';
        };
      }
    ) // {
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let cfg = config.services.ktransformers;
        in {
          options.services.ktransformers = {
            enable = mkEnableOption "ktransformers inference service";
            
            model = mkOption {
              type = types.path;
              description = "Path to model file (must be accessible to service user)";
            };
            
            port = mkOption {
              type = types.port;
              default = 5000;
              description = "HTTP API port";
            };
            
            numa = mkOption {
              type = types.bool;
              default = true;
              description = "Enable NUMA optimizations";
            };
            
            balanceServe = mkOption {
              type = types.bool;
              default = false;
              description = "Enable balanced serving mode for multi-GPU";
            };
            
            gpus = mkOption {
              type = types.listOf types.str;
              default = ["0"];
              description = "List of GPU devices to use";
            };
          };
          
          config = mkIf cfg.enable {
            systemd.services.ktransformers = {
              description = "ktransformers inference service";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              
              environment = {
                USE_NUMA = if cfg.numa then "1" else "0";
                USE_BALANCE_SERVE = if cfg.balanceServe then "1" else "0";
                CUDA_VISIBLE_DEVICES = builtins.concatStringsSep "," cfg.gpus;
              };
              
              serviceConfig = {
                ExecStart = "${self.packages.${pkgs.system}.default}/bin/ktransformers-start --model ${cfg.model} --port ${toString cfg.port}";
                ExecStop = "${self.packages.${pkgs.system}.default}/bin/ktransformers-stop";
                Restart = "on-failure";
                RestartSec = "30s";
                User = "ktransformers";
                Group = "ktransformers";
                StateDirectory = "ktransformers";
                WorkingDirectory = "/var/lib/ktransformers";
                LimitNOFILE = 65536;
              };
            };
            
            users.users.ktransformers = {
              isSystemUser = true;
              group = "ktransformers";
              extraGroups = ["video" "render"]; # For GPU access
            };
            
            users.groups.ktransformers = {};
          };
        };
    };
}
