.PHONY: home darwin update clean

home:
	home-manager switch --flake . --impure

darwin:
	darwin-rebuild switch --flake .#$$(hostname) --impure

update:
	nix flake update

clean:
	nix-collect-garbage -d
	nix-store --optimise
