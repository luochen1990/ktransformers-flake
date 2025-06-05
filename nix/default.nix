let
  pkgs = import <nixpkgs> {
    config = {
      allowUnfree = true;
      cudaSupport = true;
    };
  };
  inherit (pkgs) lib stdenv fetchFromGitHub;
  python3 = pkgs.python3;
  cudaSupport = true;
  rocmSupport = false;

  ktransformers = import ./pkgs/ktransformers.nix {
    inherit lib python3 pkgs stdenv fetchFromGitHub;
    inherit cudaSupport rocmSupport;
  };
in
ktransformers.overridePythonAttrs (old: {
  buildInputs = old.buildInputs or [ ] ++ lib.optionals cudaSupport [
    pkgs.cudaPackages.cudatoolkit
    pkgs.cudaPackages.cuda_nvcc
  ] ++ lib.optionals rocmSupport [
    pkgs.rocmPackages.clr
    pkgs.rocmPackages.rocblas
  ];

  preConfigure = (old.preConfigure or "") + ''
    export TORCH_CUDA_ARCH_LIST="${old.CUDA_CAPABILITY or "8.9"}"
    export ROCM_TARGETS="${old.ROCM_TARGETS or "gfx1100"}"
    ${lib.optionalString cudaSupport "export CUDA_HOME=${pkgs.cudaPackages.cudatoolkit}"}
    ${lib.optionalString rocmSupport "export ROCM_HOME=${pkgs.rocmPackages.clr}"}
  '';
})

