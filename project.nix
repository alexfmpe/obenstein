{ compiler ? "ghc914"
}:
let
  pins = {
    # WIP of https://github.com/NixOS/nixpkgs/pull/521260
    nixpkgs = fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/40b76b77e7176534d7ab8897d92379005d66d033.tar.gz";
      sha256 = "sha256-T9y3hXpQH/QMlg4xaiH1anPM9tvB6XBWJsbW7e89DP4";
    };

    obelisk = import ./.obelisk/impl/thunk.nix;
  };

  nixpkgs = import pins.nixpkgs {
    inherit config;
    overlays = [(import (pins.obelisk + "/nixpkgs-overlays/default.nix"))];
  };

  overrides = self: super:
    let
      staticAssetsOverride =
        let
          name = "obelisk-generated-static";
          obelisk = import pins.obelisk {};
          processed = (obelisk.processAssets { src = ./static; packageName = name; }).overrideAttrs (_: _: {
            # Otherwise defaults to obelisk-asset-manifest from bundled 8.10 package set and rebuilds the world
            nativeBuildInputs = [ nixpkgs.haskell.packages.${compiler}.obelisk-asset-manifest ];
          });
        in {
          "${name}" = self.callCabal2nix name processed.haskellManifest {};
        };

    in with nixpkgs.haskell.lib; staticAssetsOverride // {
      backend = self.callCabal2nix "backend" ./backend {};
      common = self.callCabal2nix "common" ./common {};
      dev = self.callCabal2nix "dev" ./dev {};
      frontend = self.callCabal2nix "frontend" ./frontend {};

      # Flaky test
      time-manager = dontCheck super.time-manager;

      # Cabal 3.18 needs newer process on mac
      # process = super.process_1_6_30_0;

      # 'Some' import conflicts. Let upstream handle it
      obelisk-route = dontCheck super.obelisk-route;

      obelisk-executable-config-lookup = self.callCabal2nixWithOptions
        "obelisk-executable-config-lookup"
        pins.obelisk
        "--subpath lib/executable-config/lookup"
        {};

#      Cabal = dontCheck super.Cabal;
      dependent-sum-template = doJailbreak super.dependent-sum-template;
      ghcjs-dom = doJailbreak super.ghcjs-dom;
      patch = doJailbreak super.patch;
      reflex = doJailbreak super.reflex;
    };

  config = {
    packageOverrides = nixpkgs: {
      haskell = nixpkgs.haskell // {
        packages = nixpkgs.haskell.packages // {
          "${compiler}" = nixpkgs.haskell.packages.${compiler}.override(old: {
            overrides = nixpkgs.lib.foldr nixpkgs.lib.composeExtensions  (_: _: {}) [
              (import (pins.obelisk + "/haskell-overlays/obelisk.nix"))
              overrides
            ];
          });
        };
      };
    };
  };

in {
  inherit nixpkgs;

  shell = nixpkgs.haskell.packages.${compiler}.shellFor {
    packages = p: with p; [ common backend frontend dev ];
    strictDeps = true;
    withHoogle = true;
    nativeBuildInputs = with nixpkgs; [
      cabal-install
      ghcid
      nixpkgs.haskell.packages.${compiler}.haskell-debugger
      haskell-language-server
      hlint
    ];
  };
}
