resource "aws_iam_user" "default" {
  count = "${var.enabled == "true" ? 1 : 0}"

  name                 = "${var.name}"
  path                 = "${var.path}"
  permissions_boundary = "${var.permissions_boundary}"
  force_destroy        = "${var.force_destroy}"
}

resource "aws_iam_user_login_profile" "default" {
  count = "${var.enabled == "true" && var.login_profile_enabled == "true" ? 1 : 0}"

  user                    = "${aws_iam_user.default[count.index].name}"
  pgp_key                 = "${var.pgp_key}"
  password_length         = "${var.password_length}"
  password_reset_required = "${var.password_reset_required}"
  depends_on              = ["aws_iam_user.default"]
}

resource "aws_iam_access_key" "default" {
  count                   = "${var.enabled == "true" && var.access_keys_enabled == "true" ? 1 : 0}"
  user                    = "${aws_iam_user.default[count.index].name}"
  pgp_key                 = "${var.pgp_key}"
  status                  = "${var.access_key_status}"
}

resource "aws_iam_user_group_membership" "default" {
  count      = "${var.enabled == "true" && length(var.groups) > 0 ? 1 : 0}"
  user       = "${aws_iam_user.default[count.index].name}"
  groups     = var.groups
  depends_on = ["aws_iam_user.default"]
}

locals {
  encrypted_password                        = "${element(concat(aws_iam_user_login_profile.default.*.encrypted_password, list("")), 0)}"
  access_key                                = "${element(concat(aws_iam_access_key.default.*.id, list("")), 0)}"
  encrypted_secret_access_key               = "${element(concat(aws_iam_access_key.default.*.encrypted_secret, list("")), 0)}"
  keybase_secret_access_key_pgp_message     = "${data.template_file.keybase_secret_access_key_pgp_message.rendered}"
  keybase_secret_access_key_decrypt_command = "${data.template_file.keybase_secret_access_key_decrypt_command.rendered}"
  keybase_password_pgp_message              = "${data.template_file.keybase_password_pgp_message.rendered}"
  keybase_password_decrypt_command          = "${data.template_file.keybase_password_decrypt_command.rendered}"
  credentials                               = "${data.template_file.credentials_output.rendered}"

}

data "template_file" "keybase_password_decrypt_command" {
  template = "${file("${path.module}/templates/decrypt_command.sh")}"

  vars = {
    encrypted_data = "${local.encrypted_password}"
  }
}

data "template_file" "keybase_secret_access_key_decrypt_command" {
  template = "${file("${path.module}/templates/decrypt_command.sh")}"

  vars = {
    encrypted_data = "${local.encrypted_secret_access_key}"
  }
}

data "template_file" "keybase_password_pgp_message" {
  template = "${file("${path.module}/templates/pgp_message.txt")}"

  vars = {
    encrypted_data = "${local.encrypted_password}"
  }
}

data "template_file" "keybase_secret_access_key_pgp_message" {
  template = "${file("${path.module}/templates/pgp_message.txt")}"

  vars = {
    encrypted_data = "${local.encrypted_secret_access_key}"
  }

}

data "aws_caller_identity" "current" {}

data "template_file" "credentials_output" {
  template = "\n${file("${path.module}/templates/credential_output.txt")}"

  vars = {
    encrypted_key = "${local.encrypted_secret_access_key}"
    encrypted_password = "${local.encrypted_password}"
    access_key_id = "${local.access_key}"
    username = "${element(concat(aws_iam_user.default.*.name, list("")), 0)}"
    account_id = "${data.aws_caller_identity.current.account_id}"
  }

}
