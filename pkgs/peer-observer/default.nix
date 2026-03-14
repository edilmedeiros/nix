{ stdenv
, lib
, pkgs
, rustPlatform
, enableTracing ? stdenv.hostPlatform.isLinux && !stdenv.hostPlatform.isStatic
, ...
}:

rustPlatform.buildRustPackage rec {
  name = "peer-observer";
  pname = "peer-observer";
  version = "c786df7649b04c101a3d59c1dfeaed82495d1c31";

  src = pkgs.fetchFromGitHub {
    owner = "peer-observer";
    repo = "peer-observer";
    rev = version;
    sha256 = "sha256-KneE/rKUXhS9DFIEgzwhXbGdEIrn/tJD8Qh+WsDZIvw=";
  };

  hardeningDisable = [
    "stackprotector"
    "fortify"
  ];

  buildInputs = with pkgs; [
    zlib
  ] ++ lib.optionals enableTracing [
    elfutils
  ];

  nativeBuildInputs = with pkgs; [
    protobuf
    cmake
  ] ++ lib.optionals enableTracing [
    llvmPackages_20.clang-unwrapped
    pkg-config
    rustfmt
  ];

  cargoBuildFlags = lib.optionals (!enableTracing) [
      "--workspace --exclude ebpf-extractor"
  ];

  # during the integration tests, don't try to download a bitcoind binary
  # use the nix one instead
  BITCOIND_SKIP_DOWNLOAD = "1";
  BITCOIND_EXE = "${pkgs.bitcoind}/bin/bitcoind";
  # Overwrite the default `cargo check` with `cargo test --all-features`
  # to run the integration tests.
  checkPhase = ''
    export NATS_SERVER_BINARY="${pkgs.nats-server}/bin/nats-server"
    cargo test --all-features ${lib.strings.join " " cargoBuildFlags}
  '';

  # set the path of the Linux kernel headers. These are needed in
  # build.rs of the ebpf-extractor on Nix.
  KERNEL_HEADERS = lib.derivations.optionalDrvAttr enableTracing 
    "${pkgs.linuxHeaders}/include";

  cargoHash = "sha256-CNbNliqp4BwbdySoD+BFfq9QsIYDiaKRZdD/oBgwyvo=";

  meta = {
    description = "Hooks into Bitcoin Core to observe how our peers interact with us.";
  };

  postInstall = ''
    cp -r $src/tools/metrics/dashboards $out
    cp -r $src/tools/websocket/www $out/websocket-www
  '';
}
