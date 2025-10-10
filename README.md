Skeleton project for working on forward-compatibility in obelisk projects.

Adds support for local dev (jsaddle-warp runner) with
- modern GHC
- Haskell Language Server
- multi component support
- NixOS.org caching
- GHC2021/GHC2024 polyfills

Example usage
 - `nix-shell --run 'make dev'`
 - `nix-shell --run 'make hoogle'`
 - `nix-shell --run 'your-editor'`

Configure your editor to use HLS from `PATH` and [enable multi component support](https://well-typed.com/blog/2024/07/hls-multi/#enabling-multi-component-support-in-hls).

As for nix language server, a global installation of [nixd](https://github.com/nix-community/nixd) is recommended.
Offering it as part of the (main) nix-shell is risky since if your *.nix does not eval, you won't be able to launch the language server to help you fix it.

Refer to `Makefile` and `project.nix` for details and customization.

See git history for step-by-step conversion of an obelisk project.

The base skeleton 8.6/8.10 workflow is kept in `default.nix`, and the `ob` commands work the same as always.
