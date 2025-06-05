
{ lib
, python3
, pkgs
, stdenv
, fetchFromGitHub
, cudaSupport ? true
, rocmSupport ? false
}:

python3.pkgs.buildPythonPackage rec {
  pname = "ktransformers";
  version = "2025.06.05"; # Using current date as version identifier

  src = fetchFromGitHub {
    owner = "kvcache-ai";
    repo = pname;
    rev = "70719703396d4efabeb047f0f480436131f05918"; # Actual commit hash
    sha256 = "0c8gxi92s5n2xk4d780wii31cw0s6m2h7icfdywwc3vpvpc911ii"; # Actual hash
  };

  propagatedBuildInputs = with python3.pkgs; [
    torch
    transformers
    fastapi
    uvicorn
    langchain
    blessed
    accelerate
    sentencepiece
    setuptools
    ninja
    wheel
    colorlog
    build
    fire
    protobuf
    numpy
    tiktoken
    blobfile
  ];

  # No Windows-specific patches needed for Linux target

  # Build system configuration
  nativeBuildInputs = with python3.pkgs; [
    cmake
    ninja
  ];

  # Hardware configuration
  CUDA_CAPABILITY = "8.9"; # RTX 4090
  ROCM_TARGETS = "gfx1100"; # EPYC 9334

  # GPU acceleration support
  buildInputs = with pkgs; [
  ] ++ lib.optionals cudaSupport [
    cudaPackages.cudatoolkit
    cudaPackages.cuda_nvcc
  ] ++ lib.optionals rocmSupport [
    rocmPackages.clr
    rocmPackages.rocblas
  ];

  preConfigure = ''
    export TORCH_CUDA_ARCH_LIST="''${CUDA_CAPABILITY}"
    export ROCM_TARGETS="''${ROCM_TARGETS}"
    ${lib.optionalString cudaSupport "export CUDA_HOME=${pkgs.cudaPackages.cudatoolkit}"}
    ${lib.optionalString rocmSupport "export ROCM_HOME=${pkgs.rocmPackages.clr}"}
  '';

  meta = with lib; {
    description = "High-performance transformer inference framework";
    homepage = "https://github.com/kvcache-ai/ktransformers";
    license = licenses.asl20;
    maintainers = [];
    platforms = platforms.linux;
  };
}
