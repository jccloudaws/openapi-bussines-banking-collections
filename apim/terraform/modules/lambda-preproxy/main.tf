# Rol (opcional) si no se provee uno externo
resource "aws_iam_role" "lambda_exec" {
  count = var.role_arn == null ? 1 : 0
  name  = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# modules/lambda-preproxy/main.tf
resource "aws_iam_role_policy_attachment" "vpc_access" {
  count      = var.role_arn == null && length(var.subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.lambda_exec[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


resource "aws_iam_role_policy_attachment" "basic" {
  count      = var.role_arn == null ? 1 : 0
  role       = aws_iam_role.lambda_exec[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# --- Permiso a Secrets Manager (solo si el rol lo crea el módulo) ---
resource "aws_iam_role_policy" "secrets_read" {
  count = var.role_arn == null && length(var.secret_arns) > 0 ? 1 : 0
  name  = "${var.name}-secrets-read"
  role  = aws_iam_role.lambda_exec[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "ReadSecrets",
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = var.secret_arns
      }
    ]
  })
}


resource "aws_lambda_function" "this" {
  function_name = var.name
  filename      = var.zip_path
  handler       = var.handler
  runtime       = var.runtime
  role          = var.role_arn != null ? var.role_arn : aws_iam_role.lambda_exec[0].arn
  memory_size   = var.memory_size
  timeout       = var.timeout
  tags          = var.tags

  environment {
    variables = var.env_vars
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  # ⬇⬇⬇ LISTA ESTÁTICA (sin concat/ternarios)
  depends_on = [
    aws_iam_role_policy_attachment.basic,
    aws_iam_role_policy_attachment.vpc_access,
  ]
}



