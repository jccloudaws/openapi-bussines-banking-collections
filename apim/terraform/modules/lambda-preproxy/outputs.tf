# modules/lambda-preproxy/outputs.tf

output "lambda_arn" {
  value = aws_lambda_function.this.arn
}

# Devuelve el ARN del rol: si te pasaron uno externo úsalo; si no, el creado por el módulo
output "role_arn" {
  value = var.role_arn != null ? var.role_arn : aws_iam_role.lambda_exec[0].arn
}

# Nombre del rol (necesario para adjuntar políticas fuera del módulo).
# OJO: todo el ternario va en UNA sola línea.
locals {
  computed_role_name = var.role_arn == null ? aws_iam_role.lambda_exec[0].name : replace(var.role_arn, "arn:aws:iam::[0-9]+:role/", "")
}

output "role_name" {
  value = local.computed_role_name
}
