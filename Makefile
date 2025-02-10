root = $(shell pwd)
repl = cabal repl dev all

define ghcid
  ghcid                                       \
    -c '$(repl)'                              \
    --warnings                                \
    --restart 'common/common.cabal'           \
    --restart 'backend/backend.cabal'         \
    --restart 'frontend/frontend.cabal'       \
    --restart 'dev/dev.cabal'
endef

# Call inside `nix-shell`
all: build

.PHONY: hoogle
hoogle:
	hoogle server --local -p 8080

.PHONY: build
build:
	cabal build all

.PHONY: repl
repl:
	$(repl)

.PHONY: watch
watch:
	$(ghcid)

.PHONY: dev
dev:
	$(ghcid)                           \
	--restart 'config'                 \
	--test 'Dev.dev "$(root)"'
