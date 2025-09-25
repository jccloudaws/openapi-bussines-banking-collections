# secrets-perms.tf (versión corregida)

data "aws_iam_policy_document" "secrets_read_doc" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      data.aws_secretsmanager_secret.rsa_keys.arn,
      "${data.aws_secretsmanager_secret.rsa_keys.arn}*"
    ]
  }
}

resource "aws_iam_policy" "secrets_read" {
  name   = "lambda-secrets-read"
  policy = data.aws_iam_policy_document.secrets_read_doc.json
}


# secrets-perms.tf
resource "aws_iam_role_policy_attachment" "secrets_read_attach" {
  for_each   = module.lambda_pre
  role       = each.value.role_name
  policy_arn = aws_iam_policy.secrets_read.arn
}
