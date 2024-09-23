let
  nixpkgs = import pins.nixpkgs {};

  pins = {
    # merge of https://github.com/NixOS/nixpkgs/pull/327219
    nixpkgs = builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/80ab71601549f1af09894ff006c7e368f05f6234.tar.gz";
      sha256 = "sha256:06mzgzplg85gxgvm43yxh1gkqsbnp5m5y8cvxlwzbzbpxq81jaq8";
    };

    # https://github.com/obsidiansystems/obelisk/pull/984
    # https://github.com/obsidiansystems/obelisk/pull/988
    # https://github.com/obsidiansystems/obelisk/pull/989
    # https://github.com/obsidiansystems/obelisk/pull/1075
    # https://github.com/obsidiansystems/obelisk/pull/1079
    # https://github.com/obsidiansystems/obelisk/pull/1080
    obelisk = import ./.obelisk/impl/thunk.nix;

    # https://github.com/reflex-frp/reflex-dom/pull/470
    reflex-dom = nixpkgs.fetchFromGitHub {
      owner = "alexfmpe";
      repo = "reflex-dom";
      rev = "d7e04396d927bc98f988e9c3627f42c8fd750a03";
      sha256 = "sha256-FIj0unHF/6vquqbhYW9wVGfoqQ5fwNPbgqASKCZhj+c=";
    };

  };

  packages = self: with self; {

    # 8.10 package set: Not yet present in pinned snapshot
    base16 = callHackageDirect {
      pkg = "base16";
      ver = "1.0";
      sha256 = "sha256-pLnipLnF7YuQvCwgw7Lp7sbwhab63sdEpubeSpaoEmY=";
    } {};

    # 8.10 package set: Not yet present in pinned snapshot
    crypton = callHackageDirect {
      pkg = "crypton";
      ver = "0.34";
      sha256 = "sha256-dHvzmwq5l1dPZsp0sYFe9l8mXF/Ya5aFbkDg0ljEEKY=";
    } {};

    # 8.10 package set:
    #   Setup: Encountered missing or private dependencies:
    #   aeson >=0.7.0.5 && <2.1
    lens-aeson = callHackageDirect {
      pkg = "lens-aeson";
      ver = "1.2.3";
      sha256 = "sha256-M0+QJWxN8BCpxxJhZxXSPy5Revf9p2M9uvm4gSXdE4k=";
    } {};
  };

  patches = {};

in { inherit nixpkgs packages patches pins; }
