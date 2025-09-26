variable "api_name" {
  type = string
}

variable "api_description" {
  type    = string
  default = null
}

variable "stage_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "openapi_body" {
  type        = string
  default     = null
  description = "OpenAPI como string (YAML o JSON). Alternativa a openapi_path."
}

variable "openapi_path" {
  type        = string
  default     = null
  description = "Ruta a archivo OpenAPI (YAML o JSON). Alternativa a openapi_body."
}

variable "cors_enabled" {
  type        = bool
  default     = true
}

variable "cors_overwrite" {
  type        = bool
  default     = true
}

variable "cors_allow_origins" {
  type    = list(string)
  default = ["*"]
}

variable "cors_allow_methods" {
  type    = list(string)
  default = ["GET","POST","PUT","PATCH","DELETE","OPTIONS"]
}

variable "cors_allow_headers" {
  type = list(string)
  default = [
    "Content-Type",
    "X-Amz-Date",
    "Authorization",
    "X-Api-Key",
    "X-Amz-Security-Token"
  ]
}

variable "cors_expose_headers" {
  type    = list(string)
  default = []
}

variable "cors_max_age" {
  type    = number
  default = 3600
}

variable "cors_allow_credentials" {
  type    = bool
  default = false
}
