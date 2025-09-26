output "api_id" {
  value       = aws_apigatewayv2_api.api_from_spec.id
  description = "ID del API HTTP v2"
}

output "invoke_url" {
  value       = aws_apigatewayv2_stage.stage.invoke_url
  description = "URL de invocación (base + stage)"
}
