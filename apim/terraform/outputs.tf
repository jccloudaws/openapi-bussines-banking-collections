output "api_invoke_urls" {
  value = { for k, m in module.http_api : k => m.invoke_url }
}
