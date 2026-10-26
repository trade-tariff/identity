{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-ruby = {
      url = "github:bobvanderlinden/nixpkgs-ruby";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      pre-commit-hooks,
      nixpkgs-ruby,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ nixpkgs-ruby.overlays.default ];
        };

        rubyVersion = builtins.head (builtins.split "\n" (builtins.readFile ./.ruby-version));
        ruby = pkgs."ruby-${rubyVersion}";

        # Worktree detection hook (Bundler + pre-commit isolation)
        worktree = rec {
          isWorktree = ''
            if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
              if [ "$(git rev-parse --git-dir 2>/dev/null)" != "$(git rev-parse --git-common-dir 2>/dev/null)" ]; then
                echo "true"
              else
                echo "false"
              fi
            else
              echo "false"
            fi
          '';

          id = ''
            if [ "$(${isWorktree})" = "true" ]; then
              git rev-parse --show-toplevel | md5sum | cut -c1-8
            else
              echo "main"
            fi
          '';
        };

        psychBuildFlags = with pkgs; [
          "--with-libyaml-include=${libyaml.dev}/include"
          "--with-libyaml-lib=${libyaml.out}/lib"
        ];

        lint = pkgs.writeShellScriptBin "lint" ''
          mapfile -t changed_files < <(git diff --name-only --diff-filter=ACM --merge-base main)

          if [ ''${#changed_files[@]} -eq 0 ]; then
            echo "No changed files to lint."
            exit 0
          fi

          pre-commit run --files "''${changed_files[@]}"
        '';

        init = pkgs.writeShellScriptBin "init" ''
          cd terraform && terraform init -input=false -no-color -backend=false
        '';

        update-providers = pkgs.writeShellScriptBin "update-providers" ''
          cd terraform
          terraform init -backend=false -reconfigure -upgrade
        '';

        reviewTools =
          import
            (builtins.fetchTree {
              type = "github";
              owner = "NixOS";
              repo = "nixpkgs";
              rev = "4a29d733e8a7d5b824c3d8c958a946a9867b3eb2";
              narHash = "sha256-f+JACbTqzZ+G92DSnXOUGRhGANb8Blh7CoeYOeBF8/U=";
            })
            {
              inherit system;
              config.allowUnfree = true;
            };
        reviewLatestTools = import (builtins.fetchTree {
          type = "github";
          owner = "NixOS";
          repo = "nixpkgs";
          rev = "55bfb4d7437bd4e09ab7cba58a43bd68eb310044";
          narHash = "sha256-jBYGPi4udQ9uo4KQp9m2J0546nJVQitG15gvZSaVVAs=";
        }) { inherit system; };
        reviewTerraformHooks = builtins.fetchTree {
          type = "github";
          owner = "antonbabenko";
          repo = "pre-commit-terraform";
          rev = "d0e12caebb2ab0ee8bf98181c8bfe9702bca103d";
          narHash = "sha256-JQmD7QoYegr9zvwBbauNo+kOa/u4VEr9m2Uxgb5QI/8=";
        };
        reviewRubyHooks = builtins.fetchTree {
          type = "github";
          owner = "mattlqx";
          repo = "pre-commit-ruby";
          rev = "1f893f2c0db4068fafa19b8ea7d7db1253ea0cc1";
          narHash = "sha256-7S84RvncmcXVIjgNhzFyN4HnKJk+tKxHYvfOLcuiw8c=";
        };
        reviewTrufflehogScan = pkgs.writeShellScript "trufflehog-pre-commit" ''
          set -euo pipefail
          exclude_file="$(mktemp)"
          trap 'rm -f "$exclude_file"' EXIT
          printf '%s\n' '(^|/)\.git(/|$)' '(^|/)\.terraform(/|$)' '(^|/)\.terragrunt-cache(/|$)' > "$exclude_file"
          while IFS= read -r ignored; do
            [ -n "$ignored" ] || continue
            escaped="$(printf '%s' "''${ignored%/}" | sed 's/[][(){}.^$*+?|\\]/\\&/g')"
            case "$ignored" in
              */) printf '(^|/)%s(/|$)\n' "$escaped" >> "$exclude_file" ;;
              *) printf '(^|/)%s$\n' "$escaped" >> "$exclude_file" ;;
            esac
          done < <(git ls-files --others --ignored --exclude-standard --directory)
          exec ${reviewLatestTools.trufflehog}/bin/trufflehog filesystem "$(pwd -P)" --exclude-paths="$exclude_file" --results=verified,unknown --fail
        '';
        reviewPreCommitConfig = pkgs.writeText "review-pre-commit.json" (
          builtins.toJSON {
            default_install_hook_types = [
              "pre-commit"
              "pre-push"
            ];
            default_stages = [ "pre-commit" ];
            repos = [
              {
                repo = "local";
                hooks = [
                  {
                    id = "terraform_fmt";
                    name = "Terraform fmt";
                    language = "system";
                    entry = "${reviewTerraformHooks}/hooks/terraform_fmt.sh";
                    files = "\\.(tf|tofu|tfvars|(tftest|tofutest|tfmock|tfquery)\\.hcl)$";
                    exclude = "\\.terraform/.*$";
                  }
                  {
                    id = "terraform_validate";
                    name = "Terraform validate";
                    language = "system";
                    entry = "${reviewTerraformHooks}/hooks/terraform_validate.sh";
                    files = "\\.(tf|tofu|tfvars|terraform\\.lock\\.hcl)$";
                    exclude = "\\.terraform/.*$";
                    require_serial = true;
                  }
                  {
                    id = "terraform_tflint";
                    name = "Terraform validate with tflint";
                    language = "system";
                    entry = "${reviewTerraformHooks}/hooks/terraform_tflint.sh";
                    files = "\\.(tf|tofu|tfvars)$";
                    exclude = "\\.terraform/.*$";
                    require_serial = true;
                  }
                  {
                    id = "terraform_docs";
                    name = "Terraform docs";
                    language = "system";
                    entry = "${reviewTerraformHooks}/hooks/terraform_docs.sh";
                    files = "\\.(tf|tofu|terraform\\.lock\\.hcl)$";
                    exclude = "\\.terraform/.*$";
                    require_serial = true;
                    args = [
                      "--hook-config=--add-to-existing-file=true"
                      "--hook-config=--path-to-file=README.md"
                      "--hook-config=--create-file-if-not-exist=true"
                    ];
                  }
                  {
                    id = "trailing-whitespace";
                    name = "trim trailing whitespace";
                    language = "system";
                    entry = "${reviewTools.python3Packages.pre-commit-hooks}/bin/trailing-whitespace-fixer";
                    types = [ "text" ];
                    stages = [
                      "pre-commit"
                      "pre-push"
                      "manual"
                    ];
                  }
                  {
                    id = "end-of-file-fixer";
                    name = "fix end of files";
                    language = "system";
                    entry = "${reviewTools.python3Packages.pre-commit-hooks}/bin/end-of-file-fixer";
                    types = [ "text" ];
                    stages = [
                      "pre-commit"
                      "pre-push"
                      "manual"
                    ];
                  }
                  {
                    id = "check-yaml";
                    name = "check yaml";
                    language = "system";
                    entry = "${reviewTools.python3Packages.pre-commit-hooks}/bin/check-yaml";
                    types = [ "yaml" ];
                  }
                  {
                    id = "file-contents-sorter";
                    name = "file contents sorter";
                    language = "system";
                    entry = "${reviewTools.python3Packages.pre-commit-hooks}/bin/file-contents-sorter";
                    files = ".env.development|.env.test";
                  }
                  {
                    id = "trufflehog";
                    name = "TruffleHog";
                    language = "system";
                    entry = "${reviewTrufflehogScan}";
                    pass_filenames = false;
                    require_serial = true;
                    stages = [
                      "pre-commit"
                      "pre-push"
                    ];
                  }
                  {
                    id = "markdownlint-docker";
                    name = "markdownlint-docker";
                    language = "system";
                    entry = "${reviewTools.markdownlint-cli}/bin/markdownlint";
                    types = [ "markdown" ];
                    args = [
                      "--ignore"
                      "terraform"
                      "--fix"
                      ".github"
                    ];
                  }
                  {
                    id = "rubocop";
                    name = "Check Ruby style with rubocop";
                    language = "system";
                    entry = "${reviewRubyHooks}/bin/rubocop-wrapper.sh";
                    types = [ "ruby" ];
                    pass_filenames = true;
                    args = [ "--autocorrect" ];
                  }
                  {
                    id = "actionlint-docker";
                    name = "Lint GitHub Actions workflow files";
                    language = "system";
                    entry = "${reviewTools.actionlint}/bin/actionlint";
                    types = [ "yaml" ];
                    files = "^\\.github/workflows/";
                  }
                ];
              }
            ];
          }
        );
        reviewEnvironment = ''
          if [ "''${REVIEW_SANDBOX:-}" != 1 ] || [ "$PWD" != /workspace ]; then
            echo 'Run review commands inside a disposable review sandbox.' >&2
            exit 64
          fi
          export TMPDIR=/workspace/.review/tmp PRE_COMMIT_HOME=/workspace/.review/pre-commit
          export GEM_HOME=/workspace/.review/gems
          export GEM_PATH="$GEM_HOME''${REVIEW_GEM_CACHE:+:$REVIEW_GEM_CACHE}"
          export PATH="$GEM_HOME/bin:$PATH" BUNDLE_BIN="$GEM_HOME/bin"
          export BUNDLE_IGNORE_CONFIG=1 BUNDLE_PATH__SYSTEM=true BUNDLE_FROZEN=true
          export RAILS_ENV=test CI=true AWS_EC2_METADATA_DISABLED=true TF_IN_AUTOMATION=1 TF_INPUT=0 CHECKPOINT_DISABLE=1
          export TF_CLI_CONFIG_FILE=/workspace/.review/terraform.rc
          export npm_config_ignore_scripts=true npm_config_audit=false
          unset BUNDLE_PATH BUNDLE_APP_CONFIG BUNDLE_WITHOUT TF_PLUGIN_CACHE_DIR
          mkdir -p "$TMPDIR" "$GEM_HOME"
        '';

        preCommitCheck = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          configPath = ".pre-commit-config-nix.yaml";
          default_stages = [ "pre-commit" ];
          hooks = {
            actionlint = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            check-added-large-files = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            check-case-conflicts = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            check-merge-conflicts = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            check-yaml = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            deadnix = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            detect-private-keys = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            end-of-file-fixer = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            markdownlint = {
              enable = true;
              excludes = [ "^terraform/" ];
              stages = [ "pre-commit" ];
            };
            nixfmt-rfc-style = {
              package = pre-commit-hooks.inputs.nixpkgs.legacyPackages.${system}.nixfmt;
              enable = true;
              stages = [ "pre-commit" ];
            };
            sort-file-contents = {
              enable = true;
              files = "^\\.env\\.(development|test)$";
              stages = [ "pre-commit" ];
            };
            statix = {
              enable = true;
              settings.ignore = [ "{.direnv,.nix,.worktrees}/**" ];
              stages = [ "pre-commit" ];
            };
            terraform-format = {
              enable = true;
              package = pkgs.terraform;
              stages = [ "pre-commit" ];
            };
            terraform-validate = {
              enable = true;
              package = pkgs.terraform;
              entry = ''
                bash -c '
                  set -uo pipefail
                  status=0

                  while read -r dir; do
                    lockfile="$dir/.terraform.lock.hcl"
                    backup=$(mktemp)
                    had_lockfile=false

                    if [ -f "$lockfile" ]; then
                      cp "$lockfile" "$backup"
                      had_lockfile=true
                    fi

                    ${pkgs.terraform}/bin/terraform -chdir="$dir" init -backend=false
                    init_status=$?

                    if [ "$init_status" -eq 0 ]; then
                      ${pkgs.terraform}/bin/terraform -chdir="$dir" validate
                      validate_status=$?
                    else
                      validate_status=$init_status
                    fi

                    if [ "$had_lockfile" = true ]; then
                      cp "$backup" "$lockfile"
                    else
                      rm -f "$lockfile"
                    fi
                    rm -f "$backup"

                    if [ "$validate_status" -ne 0 ]; then
                      status=$validate_status
                    fi
                  done < <(for arg in "$@"; do dirname "$arg"; done | sort | uniq)

                  exit "$status"
                ' --
              '';
              stages = [ "pre-commit" ];
            };
            tflint = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            trim-trailing-whitespace = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            trufflehog = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            rubocop = {
              enable = true;
              name = "rubocop";
              description = "Run RuboCop through Bundler on changed Ruby files";
              entry = ''
                bash -c '
                  changed_files=$(git diff --name-only --diff-filter=ACM --merge-base main | grep -E "\\.(rb|rake)$|^(Gemfile|Rakefile|config\\.ru)$" || true)

                  if [ -n "$changed_files" ]; then
                    bundle exec rubocop --autocorrect --force-exclusion $changed_files
                  fi
                '
              '';
              files = "\\.(rb|rake)$|^(Gemfile|Rakefile|config\\.ru)$";
              pass_filenames = false;
              stages = [ "pre-commit" ];
            };
          };
        };

        worktree-info = pkgs.writeShellScriptBin "worktree-info" ''
          if [ "$(${worktree.isWorktree})" = "true" ]; then
            WT_ID=$(${worktree.id})
            echo "Worktree mode enabled"
            echo "  ID:          $WT_ID"
            echo "  GEM_HOME:    $HOME/.local/share/gem/worktrees/$WT_ID"
            echo "  BUNDLE_PATH: .bundle"
          else
            echo "Normal checkout (not a worktree)"
          fi
        '';

        worktree-clean = pkgs.writeShellScriptBin "worktree-clean" ''
          set -euo pipefail
          if [ "$(${worktree.isWorktree})" != "true" ]; then
            echo "Not inside a worktree. Nothing to clean."
            exit 0
          fi

          WT_ID=$(${worktree.id})
          echo "Cleaning worktree $WT_ID..."

          rm -rf ".bundle"
          rm -rf "$HOME/.local/share/gem/worktrees/$WT_ID" 2>/dev/null || true
          rm -rf "$HOME/.cache/bundle/worktrees/$WT_ID" 2>/dev/null || true

          echo "Worktree $WT_ID cleaned (bundle + gem)."
        '';
      in
      {
        devShells.review = pkgs.mkShell {
          shellHook = "";
          packages = [
            pkgs.gitMinimal
            pkgs.bash
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.gawk
            pkgs.jq
            pkgs.util-linux
            pkgs.diffutils
            pkgs.nodejs_24
            ruby
            reviewTools.pre-commit
            reviewTools.terraform
            reviewTools.tflint
            reviewTools.terraform-docs
            (pkgs.writeShellApplication {
              name = "review-bootstrap";
              text = reviewEnvironment + ''
                for archive in /deps/gem-archives/*.gem; do
                  [ -f "$archive" ] || continue
                  gem install --local --no-document --ignore-dependencies "$archive"
                done
                bundle check || bundle install --local
                bundle binstubs --all
                cp -a /deps/node_modules /workspace/node_modules
                npm ls --all --offline
                printf 'disable_checkpoint = true\nprovider_installation {\n filesystem_mirror {\n path = "/deps/terraform-inputs/providers"\n include = ["registry.terraform.io/*/*"]\n }\n}\n' > "$TF_CLI_CONFIG_FILE"
                files="$(git ls-files '*.tf')"
                test -n "$files"
                mapfile -t roots < <(printf '%s\n' "$files" | while IFS= read -r file; do dirname "$file"; done | sort -u)
                for root in "''${roots[@]}"; do
                  mkdir -p "$root/.terraform/modules"
                  if [ -f "/deps/terraform-inputs/roots/$root/modules.json" ]; then cp "/deps/terraform-inputs/roots/$root/modules.json" "$root/.terraform/modules/modules.json"; fi
                  if [ ! -f "$root/.terraform.lock.hcl" ]; then cp "/deps/terraform-inputs/roots/$root/lock.hcl" "$root/.terraform.lock.hcl"; fi
                  terraform -chdir="$root" init -backend=false -input=false -lockfile=readonly -no-color
                done
              '';
            })
            (pkgs.writeShellApplication {
              name = "review-check";
              text = reviewEnvironment + ''
                status=0
                pre-commit run --all-files --config ${reviewPreCommitConfig} || status=$?
                pre-commit run --all-files --hook-stage pre-push --config ${reviewPreCommitConfig} || status=$?
                bundle exec brakeman || status=$?
                bundle exec rspec --format progress --format json --out "$TMPDIR/unit.json" || status=$?
                ruby -rjson -e 's = JSON.parse(File.read(ARGV[0])).fetch("summary"); abort "Unit tests failed or skipped" unless s.fetch("example_count").positive? && s.fetch("failure_count").zero? && s.fetch("pending_count").zero?' "$TMPDIR/unit.json" || status=$?
                bin/rails assets:precompile || status=$?
                npm test || status=$?
                exit "$status"
              '';
            })
          ];
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.libyaml
            pkgs.zlib
            pkgs.openssl
          ];
          BUNDLE_BUILD__PSYCH = builtins.concatStringsSep " " psychBuildFlags;
          TZDIR = "${pkgs.tzdata.outPath}/share/zoneinfo";
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        };

        devShells.default = pkgs.mkShell {
          shellHook = ''
            # Worktree-aware Bundler/Ruby isolation
            if [ "$(${worktree.isWorktree})" = "true" ]; then
              WT_ID=$(${worktree.id})
              export GEM_HOME="$HOME/.local/share/gem/worktrees/$WT_ID"
              export BUNDLE_PATH=".bundle"
              export BUNDLE_APP_CONFIG=".bundle"
              export BUNDLE_IGNORE_CONFIG=1
              mkdir -p "$GEM_HOME" ".bundle"
              echo "Worktree Bundler isolation enabled (ID: $WT_ID)"
            else
              export GEM_HOME=$PWD/.nix/ruby/$(${ruby}/bin/ruby -e "puts RUBY_VERSION")
              mkdir -p $GEM_HOME
            fi

            export BUNDLE_BUILD__PSYCH="${builtins.concatStringsSep " " psychBuildFlags}"

            export GEM_PATH=$GEM_HOME
            export PATH=${ruby}/bin:$GEM_HOME/bin:$PATH

            ${worktree-info}/bin/worktree-info

            # === Automatic first-time setup for identity worktrees ===
            if [ "$(${worktree.isWorktree})" = "true" ]; then
              WT_ID=$(${worktree.id})
              MARKER="$HOME/.local/share/gem/worktrees/$WT_ID/.worktree-initialized"

              if [ ! -f "$MARKER" ]; then
                echo ""
                echo "==> First time in this worktree (ID: $WT_ID)"
                echo "    Running bundle install..."
                echo ""

                fail_worktree_setup() {
                  echo ""
                  echo "==> Worktree setup failed. Fix the error above, then re-enter the shell."
                  exit 1
                }

                run_setup_step() {
                  label="$1"
                  shift
                  log_file="/tmp/worktree-$WT_ID-$(echo "$label" | tr '[:upper:] /:' '[:lower:]---').log"

                  echo "    $label..."
                  if "$@" >"$log_file" 2>&1; then
                    echo "      ok (log: $log_file)"
                  else
                    status=$?
                    echo "      failed with exit $status (log: $log_file)"
                    echo "      last 80 log lines:"
                    tail -80 "$log_file" | sed 's/^/        /'
                    return "$status"
                  fi
                }

                rm -rf .bundle
                export BUNDLE_PATH=".bundle"
                export BUNDLE_APP_CONFIG=".bundle"
                export BUNDLE_IGNORE_CONFIG=1
                run_setup_step "Installing gems" bundle install --jobs=4 --retry=3 || fail_worktree_setup

                touch "$MARKER"
                echo ""
                echo "==> Identity ready."
                echo ""
              else
                export BUNDLE_PATH=".bundle"
                export BUNDLE_APP_CONFIG=".bundle"
                export BUNDLE_IGNORE_CONFIG=1
              fi
            fi

            ${preCommitCheck.shellHook}
            export PATH=${pkgs.writeShellScriptBin "pre-commit" ''
              set -euo pipefail

              has_config=false
              for arg in "$@"; do
                case "$arg" in
                  -c|--config|--config=*)
                    has_config=true
                    ;;
                esac
              done

              if [ "$has_config" = true ]; then
                exec ${preCommitCheck.config.package}/bin/pre-commit "$@"
              fi

              if [ "''${1:-}" = "run" ]; then
                shift
                exec ${preCommitCheck.config.package}/bin/pre-commit run --config .pre-commit-config-nix.yaml "$@"
              fi

              exec ${preCommitCheck.config.package}/bin/pre-commit "$@"
            ''}/bin:$PATH
          '';

          buildInputs =
            preCommitCheck.enabledPackages
            ++ (with pkgs; [
              init
              lint
              ruby
              terraform-docs
              update-providers
              worktree-info
              worktree-clean
            ]);
        };
      }
    );
}
