{ compiler ? "ghc910"
}:
let
  pins = {
    # merge of https://github.com/NixOS/nixpkgs/pull/444862
    nixpkgs = builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/15ed8f7638116135ac9d3bd4353c482e7c539e0f.tar.gz";
      sha256 = "sha256:00ypnmxqm216jw55gvrh64v7shadzr16ppp3c7qpbxlkiq0mdars";
    };

    servant-reflex = nixpkgs.fetchFromGitHub {
      repo = "servant-reflex";
      owner = "alexfmpe";
      rev = "94086ddd1184557f1288c88fcdcea37f6d856252";
      sha256 = "sha256-e0P5cNVzDeF+n3jeo1dFAHzlCXqc7ODBcFHXiewVDgM";
    };

    obelisk = import ./.obelisk/impl/thunk.nix;
  };

  nixpkgs = import pins.nixpkgs {
    inherit config;
    overlays = [(import (pins.obelisk + "/nixpkgs-overlays/default.nix"))];
  };

  overrides = self: super: with nixpkgs.haskell.lib.compose;
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

    in staticAssetsOverride // {
      backend = self.callCabal2nix "backend" ./backend {};
      common = self.callCabal2nix "common" ./common {};
      dev = self.callCabal2nix "dev" ./dev {};
      frontend = self.callCabal2nix "frontend" ./frontend {};

      servant-reflex = self.callCabal2nix "servant-reflex" pins.servant-reflex {};

      obelisk-executable-config-lookup = self.callCabal2nixWithOptions
        "obelisk-executable-config-lookup"
        pins.obelisk
        "--subpath lib/executable-config/lookup"
        {};
    };

  config = {
    packageOverrides = nixpkgs: {
      haskell = nixpkgs.haskell // {
        packages = nixpkgs.haskell.packages // {
          "${compiler}" = nixpkgs.haskell.packages.${compiler}.override(old: {
            overrides = nixpkgs.lib.foldr nixpkgs.lib.composeExtensions  (_: _: {}) [
              overrides
              (import (pins.obelisk + "/haskell-overlays/obelisk.nix"))
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
      haskell-language-server
      hlint
    ];
  };
}
