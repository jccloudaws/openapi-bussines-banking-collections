# ===================== Outputs =====================
output "api_endpoints" {
  value = { for k, m in module.http_api : k => m.invoke_url }
}

output "nlb" {
  value = {
    arn = data.aws_lb.k8s_nlb.arn
    dns = data.aws_lb.k8s_nlb.dns_name
  }
}
