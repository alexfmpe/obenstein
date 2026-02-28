{ compiler ? "ghc910"
}:
let
  pins = {
    # merge of https://github.com/NixOS/nixpkgs/pull/488406
    nixpkgs = fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/bd5580cf56affe8d8515dd50cedbdb467838954f.tar.gz";
      sha256 = "sha256:006yhdl91ggk2hpq4y6wddzxzw5jdp0qrm9yrbwsa40g4274zld0";
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

    in staticAssetsOverride // {
      backend = self.callCabal2nix "backend" ./backend {};
      common = self.callCabal2nix "common" ./common {};
      dev = self.callCabal2nix "dev" ./dev {};
      frontend = self.callCabal2nix "frontend" ./frontend {};

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
