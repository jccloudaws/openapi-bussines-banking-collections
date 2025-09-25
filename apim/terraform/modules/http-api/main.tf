# (elimina cualquier locals { openapi_body = ... } que tengas)

resource "aws_apigatewayv2_api" "api_from_spec" {
  name          = var.api_name
  protocol_type = "HTTP"
  description   = var.api_description
  body          = var.openapi_body # 👈 usa el body pasado desde el root
  tags          = var.tags
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.api_from_spec.id
  name        = var.stage_name
  auto_deploy = true
}
