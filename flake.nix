{
  description = "chr.fan blog - Hugo site, two themes, no external CDN";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    terminal = {
      url = "github:panr/hugo-theme-terminal";
      flake = false;
    };
    diary = {
      url = "github:AmazingRise/hugo-theme-diary";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, terminal, diary }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      mkVendor = pkgs: pkgs.callPackage ./nix/vendor.nix { inherit terminal diary; };
    in
    {
      # `mkSite` is the real entry point: the Nix repo calls it with the baseURL
      # of whatever domain the site is currently served from, so the same tree
      # builds for blog.chr.fan today and chr.fan after the cutover. `theme`
      # picks a config/<theme>/ environment and the matching overlay/<theme>/.
      lib.mkSite =
        pkgs: args:
        pkgs.callPackage ./nix/site.nix ({ vendor = mkVendor pkgs; theme = "terminal"; } // args);

      packages = forAllSystems (pkgs: rec {
        default = blog;
        blog = self.lib.mkSite pkgs { baseURL = "https://blog.chr.fan/"; };
        # Used after the cutover, when Hugo takes over the apex domain.
        blog-apex = self.lib.mkSite pkgs { baseURL = "https://chr.fan/"; };
        # The other theme, kept buildable so the choice stays a comparison
        # rather than an archaeology exercise.
        blog-diary = self.lib.mkSite pkgs {
          baseURL = "https://blog.chr.fan/";
          theme = "diary";
        };
        # ./dev.sh materialises this into the working tree for `hugo server`.
        vendor = mkVendor pkgs;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.hugo ];
          shellHook = ''
            echo "./dev.sh [terminal|diary]  -- live preview on http://localhost:1313"
          '';
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
