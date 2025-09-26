terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

########################################
# Cargar OpenAPI y (opcional) inyectar CORS
########################################

locals {
  # 1) Preferimos openapi_body (string). Si no, leemos archivo.
  _openapi_raw_input = coalesce(
    var.openapi_body,
    try(file(var.openapi_path), null)
  )

  # 2) Decodificamos el spec. yamldecode acepta YAML y JSON.
  #    Si no hay input, devolvemos un mapa vacío para mantener tipos coherentes.
  openapi_map_base = try(
    yamldecode(local._openapi_raw_input),
    tomap({})
  )

  # 3) Bloque CORS parametrizable
  cors_block = {
    allowOrigins     = var.cors_allow_origins
    allowMethods     = var.cors_allow_methods
    allowHeaders     = var.cors_allow_headers
    exposeHeaders    = var.cors_expose_headers
    maxAge           = var.cors_max_age
    allowCredentials = var.cors_allow_credentials
  }

  # 4) ¿El spec ya trae CORS?
  has_cors = contains(keys(local.openapi_map_base), "x-amazon-apigateway-cors")

  # 5) Mapa opcional con CORS (o vacío)
  cors_optional_map = (
    var.cors_enabled && (var.cors_overwrite || !local.has_cors)
    ? { "x-amazon-apigateway-cors" = local.cors_block }
    : tomap({})
  )

  # 6) Spec final = base + (opcional) CORS
  openapi_map_final = merge(local.openapi_map_base, local.cors_optional_map)

  # 7) Serializamos a string para pasar a `body`
  openapi_body_final = jsonencode(local.openapi_map_final)
}


########################################
# API + Stage
########################################
resource "aws_apigatewayv2_api" "api_from_spec" {
  name          = var.api_name
  protocol_type = "HTTP"
  description   = var.api_description
  body          = local.openapi_body_final
  tags          = var.tags

  lifecycle {
    precondition {
      condition     = var.openapi_body != null || var.openapi_path != null
      error_message = "Debes proveer 'openapi_body' (string) o 'openapi_path' (ruta a YAML/JSON)."
    }
  }
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.api_from_spec.id
  name        = var.stage_name
  auto_deploy = true
}
