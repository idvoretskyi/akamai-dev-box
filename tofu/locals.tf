###############################################################################
# Resolved values: variable -> linode-cli config -> hardcoded fallback.
# The deploy username is derived from the local $USER at plan/apply time.
###############################################################################

locals {
  cli = data.external.linode_cli.result

  region        = coalesce(var.region, try(local.cli.region, ""), "gb-lon")
  instance_type = coalesce(var.instance_type, try(local.cli.type, ""), "g6-standard-6")
  image         = coalesce(var.image, try(local.cli.image, ""), "linode/ubuntu26.04")

  # Kept in sync with the validation regex on var.image (Terraform validation
  # blocks cannot reference locals, so that copy must be updated manually).
  image_pattern = "^(linode/ubuntu[0-9]+\\.[0-9]+|private/)"

  username = coalesce(var.username, data.external.local_user.result.username)
  instance = coalesce(var.instance_label, "${local.username}-dev-box")
  hostname = var.hostname == "" ? local.instance : var.hostname

  # Rendered separately so the first-boot install script can be linted/tested
  # on its own (see cloud-init/devbox-init.sh.tpl) and reused across renders.
  devbox_init_script = templatefile("${path.module}/cloud-init/devbox-init.sh.tpl", {
    username      = local.username
    dotfiles_repo = var.dotfiles_repo
  })

  cloud_init = templatefile("${path.module}/cloud-init/main.yaml.tpl", {
    username           = local.username
    hostname           = local.hostname
    timezone           = var.timezone
    ssh_keys           = var.authorized_keys
    extra_packages     = var.extra_packages
    seed_linode_cli    = var.seed_linode_cli
    linode_token       = var.linode_token
    region             = local.region
    instance_type      = local.instance_type
    image              = local.image
    git_user_name      = var.git_user_name
    git_user_email     = var.git_user_email
    devbox_init_script = local.devbox_init_script
  })

  ###############################################################################
  # Network / SSH helpers, shared by outputs.tf
  ###############################################################################

  ipv4    = length(linode_instance.dev_box.ipv4) > 0 ? tolist(linode_instance.dev_box.ipv4)[0] : ""
  have_ip = local.ipv4 != ""

  # Built once and reused by both the ~/.ssh/config output and the install
  # command; "$USER" is intentionally a literal shell variable, expanded at
  # runtime on the machine where the output command is run (not by Terraform).
  ssh_config_lines = [
    "# BEGIN akamai-dev-box",
    "Host $USER-dev-box",
    "  HostName ${local.ipv4}",
    "  User ${local.username}",
    "  IdentityFile ~/.ssh/id_ed25519",
    "  StrictHostKeyChecking accept-new",
    "# END akamai-dev-box",
  ]
  ssh_config_block = join("\n", local.ssh_config_lines)
}
