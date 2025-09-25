variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "svc_namespace" {
  type = string
}

variable "svc_name" {
  type = string
}

variable "lambda_subnet_ids" {
  type = list(string)
}

variable "stage_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

# Lambdas de pre-procesamiento
variable "preproxy_lambdas" {
  type = list(object({
    name     = string
    zip_path = string
    handler  = string
    runtime  = string
    role_arn = optional(string)
    env_vars = optional(map(string), {})
  }))
  default = []
}

# Definición de APIs
# Definición de APIs
variable "apis" {
  type = list(object({
    name : string
    display_name : string
    description : optional(string)
    openapi_path : optional(string)

    # <-- CLAVE: tu main espera esto a nivel top-level
    lambda_name : string

    jwt : optional(object({
      issuer : string
      audiences : list(string)
    }))

    # Opcional: solo si vas a definir rutas “a mano” (no con OpenAPI)
    routes : optional(list(object({
      route_key : string
      auth_scopes : optional(list(string))
      integration : object({
        type : string                   # "VPC_LINK" | "LAMBDA" | "AWS_PROXY" | "HTTP_PROXY"
        listener_arn : optional(string) # para VPC_LINK
        url : optional(string)          # para HTTP_PROXY
        method : optional(string)
        lambda_name : optional(string) # (si integras por ruta)
        payload_format_version : optional(string)
        nlb_dns : optional(string)
        port : optional(number)
      })
    })), [])
  }))
  default = []
}


# Puerto del listener del NLB que usará el VPC Link (normalmente 80 o 443)
variable "nlb_listener_port" {
  type    = number
  default = 443
}

# Puerto del servicio detrás del NLB (tu upstream real; p.ej. Istio en 8080)
variable "nlb_port" {
  type    = number
  default = 8080
}

# Nombre del secreto con las llaves RSA en base64:
# SecretString debe ser: {"public_key_b64":"...","private_key_b64":"..."}
variable "rsa_keys_secret_name" {
  type        = string
  description = "Secrets Manager name con las llaves RSA (base64). Ej: rsa-keys/dev"
}
