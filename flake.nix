
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
          
          installPhase = ''
            mkdir -p $out
            cp -r . $out/
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
            enable = mkEnableOption "ktransformers service";
            
            model = mkOption {
              type = types.str;
              description = "Path to the model file";
            };
            
            port = mkOption {
              type = types.port;
              default = 5000;
              description = "Port to run the service on";
            };
          };
          
          config = mkIf cfg.enable {
            systemd.services.ktransformers = {
              description = "ktransformers service";
              wantedBy = [ "multi-user.target" ];
              
              serviceConfig = {
                ExecStart = "${self.packages.${pkgs.system}.default}/bin/ktransformers --model ${cfg.model} --port ${toString cfg.port}";
                Restart = "always";
                User = "ktransformers";
                Group = "ktransformers";
              };
            };
            
            users.users.ktransformers = {
              isSystemUser = true;
              group = "ktransformers";
            };
            
            users.groups.ktransformers = {};
          };
        };
    };
}
