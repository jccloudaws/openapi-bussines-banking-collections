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


module "http_api" {
  for_each = { for a in var.apis : a.name => a }
  source   = "./modules/http-api"

  api_name        = each.value.display_name
  api_description = try(each.value.description, null)
  stage_name      = var.stage_name

  openapi_body = templatefile(each.value.openapi_path, {
    jwt_issuer           = try(each.value.jwt.issuer, "")
    #jwt_audience         = try(join(",", each.value.jwt.audiences), "")
    jwt_audiences_list = join("\", \"", each.value.jwt.audiences)
    vpc_link_id          = module.vpclink.vpc_link_id
    apiScope             = "api://56ee37cb-e5ad-482f-9855-86e85d8c7889/backoffice.read"
    nlb_listener_arn     = data.aws_lb_listener.k8s_nlb_listener.arn
    region               = var.region
    stage                = var.stage_name
    lambda_arn_normalize = module.lambda_pre[each.value.lambda_name].lambda_arn
  })

  tags = var.tags
}

# ====== Permisos Lambda por-API (dinámico) ======
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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
  # Restringido al API específico (usamos el api_id que expone el módulo)
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.http_api[each.key].api_id}/*/*/*"
}

# Outputs útiles
output "api_endpoints" {
  value = { for k, m in module.http_api : k => m.invoke_url }
}

output "nlb" {
  value = {
    arn = data.aws_lb.k8s_nlb.arn
    dns = data.aws_lb.k8s_nlb.dns_name
  }
}
