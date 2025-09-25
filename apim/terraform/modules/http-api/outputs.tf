output "api_id" {
  value = aws_apigatewayv2_api.api_from_spec.id
}

output "invoke_url" {
  value = aws_apigatewayv2_stage.stage.invoke_url
}

output "api_arn" {
  value = aws_apigatewayv2_api.api_from_spec.arn
}
