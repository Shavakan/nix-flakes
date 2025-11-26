.PHONY: home darwin update clean

home:
	home-manager switch --flake . --impure

darwin:
	darwin-rebuild switch --flake .#$$(hostname) --impure

update:
	nix flake update

clean:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "Error: make clean requires sudo to remove .app bundles"; \
		echo "Run: sudo make clean"; \
		exit 1; \
	fi
	home-manager expire-generations "-30 days"
	@echo "Removing old .app bundles that block GC..."
	@nix-store --gc --print-dead | grep -E '\.app$$' | xargs -r rm -rf 2>/dev/null || true
	-nix-store --gc
	nix-store --optimise
