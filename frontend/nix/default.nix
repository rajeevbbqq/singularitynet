{ src
, pkgs
, system
, inputs
, ...
}:

let
  nodejs = pkgs.nodejs-12_x;
  easy-ps = import inputs.easy-purescript-nix { inherit pkgs; };
  compiler = easy-ps.purs-0_14_5;
  spagoPkgs = import ../spago-packages.nix { inherit pkgs; };
  nodeEnv = import
    (pkgs.runCommand "nodePackages"
      {
        buildInputs = [ pkgs.nodePackages.node2nix ];
      } ''
      mkdir $out
      cp ${src}/package.json $out/package.json
      cp ${src}/package-lock.json $out/package-lock.json
      cd $out
      node2nix --lock package-lock.json
    '')
    { inherit pkgs nodejs system; };
  nodeModules =
    let
      modules = pkgs.callPackage
        (_:
          nodeEnv // {
            shell = nodeEnv.shell.override {
              # see https://github.com/svanderburg/node2nix/issues/198
              buildInputs = [ pkgs.nodePackages.node-gyp-build ];
            };
          });
    in
    (modules { }).shell.nodeDependencies;

  buildPursProject = { name, src, ... }:
    pkgs.stdenv.mkDerivation {
      inherit name src;
      buildInputs = [
        spagoPkgs.installSpagoStyle
        spagoPkgs.buildSpagoStyle
      ];
      nativeBuildInputs = [
        compiler
        easy-ps.spago
      ];
      unpackPhase = ''
        export HOME="$TMP"

        cp -r ${nodeModules}/lib/node_modules .
        chmod -R u+rw node_modules
        cp -r $src .

        install-spago-style
      '';
      buildPhase = ''
        build-spago-style "./**/*.purs"
      '';
      installPhase = ''
        mkdir $out
        mv output $out/
      '';
    };

  runPursTest = { name, testMain ? "Test.Main", ... }@args:
    (buildPursProject args).overrideAttrs
      (oldAttrs: {
        name = "${name}-check";
        doCheck = true;
        buildInputs = oldAttrs.buildInputs ++ [ nodejs ];
        # spago will attempt to download things, which will fail in the
        # sandbox (idea taken from `plutus-playground-client`)
        checkPhase = ''
          node -e 'require("./output/${testMain}").main()'
        '';
        installPhase = ''
          touch $out
        '';
      });

  flake = {
    packages = {
      singularitynet-frontend-nodejs = buildPursProject {
        name = "singularitynet-frontend";
        inherit src;
      };
    };

    checks = {
      singularitynet-frontend = runPursTest {
        name = "singularitynet-frontend";
        inherit src;
      };

      frontendFormatCheck = pkgs.runCommand "formatting-check"
        {
          nativeBuildInputs = [
            easy-ps.purs-tidy
            pkgs.fd
          ];
        }
        ''
          cd ${src}
          purs-tidy check $(fd -epurs)
          touch $out
        '';
    };

    devShell =
      pkgs.mkShell
        {
          buildInputs = with easy-ps; [
            compiler
            spago
            purs-tidy
            purescript-language-server
            pscid
            spago2nix
            pkgs.nodePackages.node2nix
            nodejs
          ];

          shellHook = ''
            __ln-node-modules () {
              local modules=./frontend/node_modules
              if test -L "$modules"; then
                rm "$modules";
              elif test -e "$modules"; then
                echo 'refusing to overwrite existing (non-symlinked) `node_modules`'
                exit 1
              fi

              ln -s ${nodeModules}/lib/node_modules "$modules"
            }

            __ln-node-modules

            export PATH="${nodeModules}/bin:$PATH"
          '';
        };
  };
in
{ inherit flake; }