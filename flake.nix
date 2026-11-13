{
  description = "llama-cpp for Apple Silicon (Metal)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
  };

  outputs = { self, nixpkgs }: {
    packages.aarch64-darwin.default = let
      pkgs = import nixpkgs {
        system = "aarch64-darwin";
        config.allowUnfree = true;
      };

      # 1. Define all "Data" variables in the let block
      src = pkgs.fetchFromGitHub {
        owner = "ggml-org";
        repo = "llama.cpp";
        tag = "v1.0.0";
        # hash = pkgs.lib.fakeHash;
        hash = "sha256-aYziwYzK9Zj7sopAEsrANhMGs4BO0F2g0cDCGmYLxDA=";
      };

      npmRoot = "tools/ui";
      # npmDepsHash = pkgs.lib.fakeHash;
      npmDepsHash = "sha256-0OJIueUN5oD/V2NtVcXTiRW59u2tJIG3OxW8aJ8JDBY=";

      allCmakeFlags = [
        "-DGGML_METAL=ON"
        "-DGGML_OPENSSL=ON"
        "-DGGML_CPU_ALL_VARIANTS=ON"
        "-DGGML_BACKEND_DL=ON"
        "-DGGML_NATIVE=OFF"
        "-DLLAMA_BUILD_EXAMPLES=OFF"
        "-DLLAMA_BUILD_SERVER=ON"
        "-DLLAMA_BUILD_TESTS=OFF"
        "-DLLAMA_TESTS_INSTALL=OFF"
        "-DLLAMA_BUILD_IS_DEV=OFF"
        "-DGGML_BACKEND_DIR=${pkgs.lib.placeholder "out"}/bin"
        "-DLLAMA_BUILD_NUMBER=11669"
        "-DLLAMA_BUILD_COMMIT=620d222"
        "-D__ARM_FEATURE_DOTPROD=1"
      ];

      # 2. Define the npmDeps variable here so it can see the variables above
      npmDeps = pkgs.fetchNpmDeps {
        name = "llama-cpp-npm-deps";
        inherit src;
        preBuild = "pushd ${npmRoot}";
        hash = npmDepsHash;
      };

      in pkgs.stdenv.mkDerivation {
        pname = "llama-cpp";
        version = "1.0.0";

        src = src;
        
        nativeBuildInputs = [
          pkgs.cmake
          pkgs.installShellFiles
          pkgs.ninja
          pkgs.nodejs_latest
          pkgs.npmHooks.npmConfigHook
          pkgs.pkg-config
        ];

        buildInputs = [
          pkgs.openssl
        ];

        # Pass the variables into the derivation attributes
        npmRoot = npmRoot;
        npmDepsHash = npmDepsHash;
        npmDeps = npmDeps;

        preConfigure = ''
          pushd ${npmRoot}
          LLAMA_BUILD_NUMBER=11669 npm run build
          popd
        '';

        cmakeFlags = allCmakeFlags;

        postInstall = ''
          installShellCompletion --cmd llama-server --bash <($out/bin/llama-server --completion-bash)
        '';

        doCheck = false;

        meta = {
          description = "Inference of Meta's LLaMA model with Metal support";
          homepage = "https://github.com/ggml-org/llama.cpp";
          license = pkgs.lib.licenses.mit;
          mainProgram = "llama";
        };
      };
  };
}
