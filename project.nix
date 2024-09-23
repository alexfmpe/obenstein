{ compiler ? "ghc96"
, buildPlatform ? builtins.currentSystem
, hostPlatform ? builtins.currentSystem
}:
let
  deps = import ./deps.nix;

  nixpkgsWith = args: import deps.pins.nixpkgs (args // {
    inherit config;
  });

  nixpkgsEval  = nixpkgsWith { localSystem = builtins.currentSystem; };
  nixpkgsCross = nixpkgsWith { localSystem = buildPlatform; crossSystem = hostPlatform; };
  nixpkgsDocker =
    let linuxSystem = builtins.replaceStrings [ "darwin" ] [ "linux" ] builtins.currentSystem; # aarch64-darwin -> aarch64-linux, etc
    in nixpkgsWith {
      localSystem = linuxSystem; # We cannot cross-compile directly, so need to *build on* a linux builder VM
      crossSystem = linuxSystem; # Output will *run on* a linux system
      overlays = [ dockerWithoutKVM ];
    };

  # https://github.com/NixOS/nixpkgs/issues/67079#issuecomment-920364273
  dockerWithoutKVM = final: prev:
    let
      runInLinuxVMNoKVM = drv: final.lib.overrideDerivation (final.vmTools.runInLinuxVM drv) (_: { requiredSystemFeatures = []; });
      modifiedVmTools = prev.vmTools // { runInLinuxVM = runInLinuxVMNoKVM; };
    in {
      dockerTools = prev.dockerTools.override { vmTools = modifiedVmTools; };
    };

  overrides = nixpkgs: self: super: with nixpkgs.haskell.lib.compose;
    let
      inherit (nixpkgs.stdenv) isDarwin isLinux isAarch64 isx86_64;
      when = b: f: if b then f else (x: x);

      staticAssetsOverride =
        let
          name = "obelisk-generated-static";
          obelisk = import deps.pins.obelisk {};
          processed = (obelisk.processAssets { src = ./static; packageName = name; }).overrideAttrs (_: _: {
            # Otherwise defaults to obelisk-asset-manifest from bundled 8.10 package set and rebuilds the world
            nativeBuildInputs = [ nixpkgsEval.haskellPackages.obelisk-asset-manifest ];
          });
        in {
          "${name}" = self.callCabal2nix name processed.haskellManifest {};
        };

      obelisk-lib = name: pinned-lib "obelisk-${name}" "obelisk" "lib/${name}";

      pinned-lib = name: pin: subpath: {
        "${name}" =
          if subpath == null
          then self.callCabal2nix            name deps.pins.${pin} {}
          else self.callCabal2nixWithOptions name deps.pins.${pin} "--subpath ${subpath}" {};
      };

    in staticAssetsOverride // {
      frontend = nixpkgs.lib.pipe (self.callCabal2nix "frontend" ./frontend {})
        [ buildStrictly
          dontHaddock
          justStaticExecutables # https://github.com/NixOS/nixpkgs/blob/f73ed219335199067ae839ae4db2a32af2b879ed/doc/languages-frameworks/haskell.section.md#packaging-helpers-haskell-packaging-helpers
        ];

      backend = nixpkgs.lib.pipe (self.callCabal2nix "backend" ./backend {})
        [ buildStrictly
          dontHaddock
          justStaticExecutables
        ];

      common = nixpkgs.lib.pipe (self.callCabal2nix "common" ./common {})
        [ buildStrictly
          dontHaddock
        ];

      # need newer version for proper deriving with ghc 9.6
      dependent-sum-template = self.callHackage "dependent-sum-template" "0.2.0.1" {};

      # reflex-dom-core's test suite only runs on x86_64-linux and needs deps that are not on hackage
      inherit (pinned-lib "chrome-test-utils" "reflex-dom" "chrome-test-utils") chrome-test-utils;
      reflex-dom = doJailbreak (pinned-lib "reflex-dom" "reflex-dom" "reflex-dom").reflex-dom;
      reflex-dom-core =
        let addDeps = import (deps.pins.reflex-dom + "/reflex-dom-test-selenium/add-overrides.nix") { inherit nixpkgs; };
        in when (isLinux && isx86_64) addDeps (doJailbreak (pinned-lib "reflex-dom-core" "reflex-dom" "reflex-dom-core").reflex-dom-core);

      # Not on hackage
      inherit (pinned-lib "obelisk-asset-manifest" "obelisk" "lib/asset/manifest") obelisk-asset-manifest;
      inherit (pinned-lib "obelisk-asset-serve-snap" "obelisk" "lib/asset/serve-snap") obelisk-asset-serve-snap;
      inherit (pinned-lib "obelisk-executable-config-inject" "obelisk" "lib/executable-config/inject") obelisk-executable-config-inject;
      inherit (pinned-lib "obelisk-executable-config-lookup" "obelisk" "lib/executable-config/lookup") obelisk-executable-config-lookup;
      obelisk-backend = (obelisk-lib "backend").obelisk-backend;
      obelisk-frontend = (obelisk-lib "frontend").obelisk-frontend;
      obelisk-route = (obelisk-lib "route").obelisk-route;
      obelisk-run =
        let addDeps = overrideCabal (drv: {
              testSystemDepends = (drv.testSystemDepends or []) ++ (with nixpkgs; [ iproute ]);
            });
        in when isLinux addDeps (obelisk-lib "run").obelisk-run;
      inherit (obelisk-lib "snap-extras") obelisk-snap-extras;
      inherit (pinned-lib "tabulation" "obelisk" "lib/tabulation") tabulation;
    };

  config = {
    packageOverrides = nixpkgs: {
      haskell = nixpkgs.haskell // {
        packages = nixpkgs.haskell.packages // {
          "${compiler}" = nixpkgs.haskell.packages.${compiler}.override(old: {
            overrides = nixpkgs.lib.foldr nixpkgs.lib.composeExtensions  (_: _: {}) [
              (overrides nixpkgs)
            ];
          });
        };
      };
    };
  };

in rec {
  inherit deps nixpkgsEval nixpkgsCross nixpkgsDocker;

  ci = nixpkgsCross.haskell.packages.${compiler}.backend;

  shell = nixpkgsEval.haskell.packages.${compiler}.shellFor {
    packages = p: with p; [ common backend frontend ];
    strictDeps = true;
    withHoogle = true;
    nativeBuildInputs = builtins.concatLists [
      (with nixpkgsEval.haskell.packages.${compiler}; [ haskell-language-server ])
      (with nixpkgsEval; [
        cabal-install
        ghcid
        hlint
      ])
    ];
  };
}
