terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# NLB expuesto por EKS (resuelto por TAGS)
data "aws_lb" "k8s_nlb" {
  tags = {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
    "kubernetes.io/service-name"                    = "${var.svc_namespace}/${var.svc_name}"
  }
}

# Listener del NLB (¡clave para HTTP API + VPC_LINK!)
data "aws_lb_listener" "k8s_nlb_listener" {
  load_balancer_arn = data.aws_lb.k8s_nlb.arn
  port              = var.nlb_listener_port # 80 o 443 (según tu NLB)
}

# SG para Lambdas pre-proxy
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-preproxy-sg"
  description = "Egress from Lambda to NLB"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "lambda-preproxy-sg" })
}

# ===== Secrets Manager: resolver ARN del secreto RSA =====
data "aws_secretsmanager_secret" "rsa_keys" {
  name = var.rsa_keys_secret_name
}

# VPC Link
module "vpclink" {
  source             = "./modules/vpc-link"
  name               = "vpclink"
  subnet_ids         = var.lambda_subnet_ids
  security_group_ids = [aws_security_group.lambda_sg.id]
  tags               = var.tags
}

# Lambdas pre-proxy
module "lambda_pre" {
  for_each = { for l in var.preproxy_lambdas : l.name => l }
  source   = "./modules/lambda-preproxy"

  name     = "pre-${each.value.name}"
  zip_path = each.value.zip_path
  handler  = each.value.handler
  runtime  = each.value.runtime
  role_arn = try(each.value.role_arn, null)

  subnet_ids         = var.lambda_subnet_ids
  security_group_ids = [aws_security_group.lambda_sg.id]

  # 👇 NO duplicamos FORWARD_BASE_PATH; viene por-lambda en each.value.env_vars
  env_vars = merge(each.value.env_vars, {
    RSA_KEYS_SECRET_NAME = var.rsa_keys_secret_name
    NLB_HOST             = data.aws_lb.k8s_nlb.dns_name
    NLB_PORT             = tostring(var.nlb_port)
    NLB_SCHEME           = var.nlb_listener_port == 443 ? "https" : "http"
  })

  tags = var.tags
}

# ===== HTTP APIs desde OpenAPI (body) =====
module "http_api" {
  for_each = { for a in var.apis : a.name => a }
  source   = "./modules/http-api"

  api_name        = each.value.display_name
  api_description = try(each.value.description, null)
  stage_name      = var.stage_name
  tags            = var.tags

  openapi_body = templatefile(each.value.openapi_path, {
    jwt_issuer           = try(each.value.jwt.issuer, "")
    jwt_audiences_list   = join("\", \"", each.value.jwt.audiences)
    vpc_link_id          = module.vpclink.vpc_link_id
    apiScope             = "api://56ee37cb-e5ad-482f-9855-86e85d8c7889/backoffice.read"
    nlb_listener_arn     = data.aws_lb_listener.k8s_nlb_listener.arn
    region               = var.region
    stage                = var.stage_name
    lambda_arn_normalize = module.lambda_pre[each.value.lambda_name].lambda_arn
  })
}

# ====== CORS para HTTP API v2 cuando se usa `body` ======
# API Gateway ignora x-amazon-apigateway-cors en HTTP API; por eso
# aplicamos CORS con un update-api por cada API creada por el módulo.
locals {
  cors_allow_origins     = ["*"]
  cors_allow_methods     = ["GET", "POST", "OPTIONS"]
  cors_allow_headers     = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key"]
  cors_expose_headers    = []
  cors_max_age           = 3600
  cors_allow_credentials = false
}

resource "null_resource" "set_httpapi_cors" {
  for_each = module.http_api

  triggers = {
    api_id            = each.value.api_id
    allow_origins     = join(",", local.cors_allow_origins)
    allow_methods     = join(",", local.cors_allow_methods)
    allow_headers     = join(",", local.cors_allow_headers)
    expose_headers    = join(",", local.cors_expose_headers)
    max_age           = tostring(local.cors_max_age)
    allow_credentials = tostring(local.cors_allow_credentials)
  }

  depends_on = [module.http_api]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -euo pipefail
      aws apigatewayv2 update-api \
        --region ${var.region} \
        --api-id ${each.value.api_id} \
        --cors-configuration '{
          "AllowOrigins": ${jsonencode(local.cors_allow_origins)},
          "AllowMethods": ${jsonencode(local.cors_allow_methods)},
          "AllowHeaders": ${jsonencode(local.cors_allow_headers)},
          "ExposeHeaders": ${jsonencode(local.cors_expose_headers)},
          "MaxAge": ${local.cors_max_age},
          "AllowCredentials": ${local.cors_allow_credentials}
        }' >/dev/null
      echo "CORS actualizado para API ${each.value.api_id}"
    EOT
  }
}

# ====== Permisos Lambda por-API (dinámico) ======
data "aws_caller_identity" "current" {}

# Mapa API -> lambda_name (sólo las APIs que lo definan)
locals {
  api_lambda_map = {
    for a in var.apis :
    a.name => try(a.lambda_name, "")
    if try(a.lambda_name, "") != ""
  }
}

resource "aws_lambda_permission" "allow_apigw" {
  for_each = local.api_lambda_map

  statement_id  = "AllowAPIGW-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_pre[each.value].lambda_arn
  principal     = "apigateway.amazonaws.com"
  # Restringido al API específico (usa var.region para evitar warning deprecado)
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${module.http_api[each.key].api_id}/*/*/*"
}

