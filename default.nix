{ rpRef ? "ea3c9a1536a987916502701fb6d319a880fdec96", rpSha ?  "0339ds5xa4ymc7xs8nzpa4mvm09lzscisdgpdfc6rykwhbgw9w2a" }:

let rp = (import <nixpkgs> {}).fetchFromGitHub {
           owner = "mightybyte";
           repo = "reflex-platform";
           rev = rpRef;
           sha256 = rpSha;
         };

in
  (import rp {}).project ({ pkgs, ... }: {
    name = "pact-web-umbrella";
    overrides = self: super:
      let guardGhcjs = p: if self.ghc.isGhcjs or false then null else p;
       in {
            blake2 = guardGhcjs super.blake2;
            cacophony = guardGhcjs (pkgs.haskell.lib.dontCheck (self.callHackage "cacophony" "0.8.0" {}));
            cryptonite = guardGhcjs (self.callHackage "cryptonite" "0.23" {});
            haskeline = guardGhcjs (self.callHackage "haskeline" "0.7.4.2" {});
            katip = guardGhcjs (pkgs.haskell.lib.doJailbreak (self.callHackage "katip" "0.3.1.4" {}));
            ridley = guardGhcjs (pkgs.haskell.lib.dontCheck (self.callHackage "ridley" "0.3.1.2" {}));

            # Needed to work with the below version of statistics
            criterion = guardGhcjs (pkgs.haskell.lib.dontCheck (self.callCabal2nix "criterion" (pkgs.fetchFromGitHub {
              owner = "bos";
              repo = "criterion";
              rev = "5a704392b670c189475649c32d05eeca9370d340";
              sha256 = "1kp0l78l14w0mmva1gs9g30zdfjx4jkl5avl6a3vbww3q50if8pv";
            }) {}));

            # Version 1.6.4, needed by weeder, not in callHackage yet
            extra = guardGhcjs (pkgs.haskell.lib.dontCheck (self.callCabal2nix "extra" (pkgs.fetchFromGitHub {
              owner = "ndmitchell";
              repo = "extra";
              rev = "4064bfa7e48a7f1b79f791560d51dbefed879219";
              sha256 = "1p7rc5m70rkm1ma8gnihfwyxysr0n3wxk8ijhp6qjnqp5zwifhhn";
            }) {}));

            seal = pkgs.haskell.lib.dontCheck (self.callCabal2nix "seal" (pkgs.fetchFromGitHub {
              owner = "Gyoung";
              repo = "seal-pact";
              rev = "739037558c64d6f0bc13e03f06de1542557b0eef";
              sha256 = "1ycgydi67izpf6irbdsb2j11mz60qhzb83h9f8x4fdvvpg7z791p";
            }) {});

            reflex-dom-ace = (self.callCabal2nix "reflex-dom-ace" (pkgs.fetchFromGitHub {
              owner = "reflex-frp";
              repo = "reflex-dom-ace";
              rev = "24e1ee4b84f50bd5b6b4401c4bdc28963ce8d80f";
              sha256 = "0hdn00cd17a7zp56krqs3y5mpcml75pn8mnmhwyixqgscqd1q9y5";
            }) {});

            # sbv >= 7.6
            # sbv = pkgs.haskell.lib.dontCheck (self.callCabal2nix "sbv" (pkgs.fetchFromGitHub {
            #   owner = "LeventErkok";
            #   repo = "sbv";
            #   rev = "dbbdd396d069dc8235f5c8cf58209886318f6525";
            #   sha256 = "0s607qbgiykgqv2b5sxcvzqpj1alxzqw6szcjzhs4hxcbbwkd60y";
            # }) {});

            sbv = pkgs.haskell.lib.dontCheck (self.callCabal2nix "sbv" (pkgs.fetchFromGitHub {
              owner = "LeventErkok";
              repo = "sbv";
              rev = "3dc60340634c82f39f6c5dca2b3859d10925cfdf";
              sha256 = "18xcxg1h19zx6gdzk3dfs87447k3xjqn40raghjz53bg5k8cdc31";
            }) {});

            # dontCheck is here because a couple tests were failing
            statistics = guardGhcjs (pkgs.haskell.lib.dontCheck (self.callCabal2nix "statistics" (pkgs.fetchFromGitHub {
              owner = "bos";
              repo = "statistics";
              rev = "1ed1f2844c5a2209f5ea72e60df7d14d3bb7ac1a";
              sha256 = "1jjmdhfn198pfl3k5c4826xddskqkfsxyw6l5nmwrc8ibhhnxl7p";
            }) {}));

            thyme = pkgs.haskell.lib.dontCheck (pkgs.haskell.lib.enableCabalFlag (self.callCabal2nix "thyme" (pkgs.fetchFromGitHub {
              owner = "kadena-io";
              repo = "thyme";
              rev = "6ee9fcb026ebdb49b810802a981d166680d867c9";
              sha256 = "09fcf896bs6i71qhj5w6qbwllkv3gywnn5wfsdrcm0w1y6h8i88f";
            }) {}) "ghcjs");

           parser-combinators = pkgs.haskell.lib.dontCheck (self.callCabal2nix "parser-combinators" (pkgs.fetchFromGitHub {
              owner = "mrkkrp";
              repo = "parser-combinators";
              rev = "dd6599224fe7eb224477ef8e9269602fb6b79fe0";
              sha256 = "11cpfzlb6vl0r5i7vbhp147cfxds248fm5xq8pwxk92d1f5g9pxm";
            }) {});

            megaparsec = pkgs.haskell.lib.dontCheck (self.callCabal2nix "megaparsec" (pkgs.fetchFromGitHub {
              owner = "mrkkrp";
              repo = "megaparsec";
              rev = "7b271a5edc1af59fa435a705349310cfdeaaa7e9";
              sha256 = "0415z18gl8dgms57rxzp870dpz7rcqvy008wrw5r22xw8qq0s13c";
            }) {});

             algebraic-graphs = pkgs.haskell.lib.dontCheck (self.callCabal2nix "algebraic-graphs" (pkgs.fetchFromGitHub {
              owner = "snowleopard";
              repo = "alga";
              rev = "64e4d908c15d5e79138c6445684b9bef27987e8c";
              sha256 = "0v8knhmrd0qrpx2lxlk7b14j79q170jmb1l0pzk93x90b2v638yw";
            }) {});

            mmorph = pkgs.haskell.lib.dontCheck (self.callCabal2nix "mmorph" (pkgs.fetchFromGitHub {
              owner = "Gabriel439";
              repo = "Haskell-MMorph-Library";
              rev = "c557fd52358d15c395c33b63a2e7e318160d735c";
              sha256 = "0a96q893zzj8zsq815qzmk341ykjdk7qh8rpp541hj40f53k55ir";
            }) {});

             trifecta = pkgs.haskell.lib.dontCheck (self.callCabal2nix "trifecta" (pkgs.fetchFromGitHub {
              owner = "ekmett";
              repo = "trifecta";
              rev = "c89be798e839ad12d7f29394e3654375dc6cf948";
              sha256 = "10cmhskz8kh3ji15qzrkp9n9gnymhxz63sab7rm8jib11qhnrbw1";
            }) {});

            universum = pkgs.haskell.lib.dontCheck (self.callCabal2nix "universum" (pkgs.fetchFromGitHub {
              owner = "serokell";
              repo = "universum";
              rev = "f868329d346d5b1acbd82c53bbdba884dcc21296";
              sha256 = "1glz0grncyyhrr3z5l1g37hs0jsmlh7a6hj5ck95hcmgq3ja8kja";
            }) {});

          };
    packages = {
      pact-ghcjs = builtins.filterSource
        (path: type: !(builtins.elem (baseNameOf path)
           ["result" "dist" "dist-ghcjs" ".git"]))
        ./.;
    };
    tools = ghc: [
      pkgs.z3
    ];
    shells = {
      ghc = ["pact-ghcjs"];
      ghcjs = ["pact-ghcjs"];
    };

  })
