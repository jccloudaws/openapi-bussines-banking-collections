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

# 👉 El módulo recibe el OpenAPI YA RENDERIZADO desde el root
variable "openapi_body" {
  type = string
}

# (compatibilidad opcional; ya no se usan dentro del módulo)
variable "openapi_path" {
  type    = string
  default = null
}

variable "openapi_vars" {
  type    = map(any)
  default = {}
}
