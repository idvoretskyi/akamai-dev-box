# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu config for a minimal Ubuntu 24.04 LTS dev box on [Akamai Cloud](https://www.linode.com/). Vanilla Ubuntu, a non-root user matching local `$USER`, SSH key auth, SSH-only firewall.

## Usage

```sh
export LINODE_TOKEN="…"
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
$EDITOR tofu/terraform.tfvars                                # authorized_keys + root_pass

tofu -chdir=tofu init && tofu -chdir=tofu apply
eval "$(tofu -chdir=tofu output -raw wait_ready_command)"
eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"
ssh "$USER-dev-box"
```

Tear down: `tofu -chdir=tofu destroy`. See `tofu/variables.tf` for all options.

## License

[MIT](LICENSE).
