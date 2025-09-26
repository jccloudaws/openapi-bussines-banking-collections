# ======== Infra base ========
region     = "us-east-1"
stage_name = "dev"

vpc_id           = "vpc-0460f67b8e0530a61"
eks_cluster_name = "desarrollo-eks"
svc_namespace    = "istio-system"
svc_name         = "istio-ingressgateway"

lambda_subnet_ids = [
  "subnet-068164e782b6073ab",
  "subnet-08e8ea6ec4fe2652a",
]

# Puerto del NLB donde publica tu Ingress (mismo usado por listener)
nlb_port          = 80
nlb_listener_port = 80

tags = {
  owner = "da-team"
  env   = "dev"
}

# ======== Lambdas pre-proxy ========
# (La role_arn es opcional; si la omites, el módulo crea un rol mínimo)
preproxy_lambdas = [
  {
  
    name     = "lambda_back-office-preprocessing_a"
    zip_path = "../lambda/pre-proc-normalize/dist/pre-proc-normalize.zip"
    handler  = "index.handler"
    runtime  = "nodejs20.x"
    env_vars = {
      FORWARD_BASE_PATH     = "/k8s"
      CONNECT_TIMEOUT_MS    = "20000"
      READ_TIMEOUT_MS       = "10000"
      RETRIES               = "0"
      LOG_HEADERS           = "false"
      INCLUDE_STAGE_IN_PATH = "false"
      UPSTREAM_HOST_HEADER  = "apisdes.bancaempresasdescal.pichincha.pe"
    }
  }
]

# ======== APIs ========
apis = [
  {
    name         = "api_back-office-ux-bo-approval-servicing-order"
    display_name = "API back office ux bo approval servicing order"
    description  = "api_back-office-ux-bo-approval-servicing-order"
    # Usa template para inyectar variables (Opción B)
    openapi_path = "../openapi/bo-approval-servicing-order/openapi.tpl.yaml"

    # Lambda que usará este contrato (dinámico)
    lambda_name = "lambda_back-office-preprocessing_a"

    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }
  },
  {
    name         = "bbe-msa-ux-bo-user-management-v1"
    display_name = "API Back Office User Management"
    description  = "bbe-msa-ux-bo-user-management-v1"
    openapi_path = "../openapi/bo-user-management/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }
  },
  {
    name         = "bbe-msa-ux-tray-order-v1"
    display_name = "API BB Channel Tray Order"
    description  = "bbe-msa-ux-tray-order-v1"
    openapi_path = "../openapi/approval-tray-order/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }
  },
  {
    name         = "experience-account-overview"
    display_name = "Experience Account Overview"
    description  = "experience-account-overview"
    openapi_path = "../openapi/accounts/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }
  },
  {
    name         = "business-banking-ux-b2c-captcha-authentication"
    display_name = "API BB Channel B2C Captcha Authentication"
    description  = "business-banking-ux-b2c-captcha-authentication"
    openapi_path = "../openapi/b2c-captcha-authentication/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }
  },
  {
    name         = "business-banking-ux-b2c-token-authenticate"
    display_name = "API BB Channel B2C Token Authenticate"
    description  = "business-banking-ux-b2c-token-authenticate"
    openapi_path = "../openapi/b2c-token-authenticate/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }
  },
  {
    name         = "bbe-msa-ux-bo-customer-management-v1"
    display_name = "API Back Office Customer Management"
    description  = "bbe-msa-ux-bo-customer-management-v1"
    openapi_path = "../openapi/bo-customer-management/openapi.tpl.yml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }
    },
    {
    name         = "bbp-msa-ux-bo-employee-access-v1"
    display_name = "API Back Office Employee Access"
    description  = "bbp-msa-ux-bo-employee-access-v1"
    openapi_path = "../openapi/bo-employee-access/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }
  },
  {
    name         = "bbp-msa-ux-bo-user-access-management"
    display_name = "API Back Office User Access Management"
    description  = "bbp-msa-ux-bo-user-access-management"
    openapi_path = "../openapi/bo-user-access-management/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }},
    {
    name         = "ws-business-banking-ux-currency-exchange-java"
    display_name = "ws-business-banking-ux-currency-exchange-java"
    description  = "ws-business-banking-ux-currency-exchange-java"
    openapi_path = "../openapi/currency-exchange/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }},
    {
    name         = "bbp-msa-ux-interbank-transfer-v1"
    display_name = "API BB Channel Interbank Transfer Order"
    description  = "bbp-msa-ux-interbank-transfer-v1"
    openapi_path = "../openapi/interbank-transfer/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }},
    {
    name         = "bbe-msa-ux-load-account-transfer-order-v1"
    display_name = "API BB Channel Load Account Transfer Order"
    description  = "bbe-msa-ux-load-account-transfer-order-v1"
    openapi_path = "../openapi/load-account-transfer-order-v1/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }},
    {
    name         = "business-banking-ux-loan-overview"
    display_name = "API BB Channel Loan Overview"
    description  = "business-banking-ux-loan-overview"
    openapi_path = "../openapi/loan-overview/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }},
    {
    name         = "business-banking-ux-users"
    display_name ="API BB Channel Users"
    description  = "API BB Channel Users"
    openapi_path = "../openapi/users/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }},
    {
    name         = "business-banking-ux-user-unlock"
    display_name = "API BB Channel User Unlock"
    description  = "API BB Channel User Unlock"
    openapi_path = "../openapi/user-unlock/openapi.tpl.yaml"
    lambda_name = "lambda_back-office-preprocessing_a"
    # JWT Authorizer
    jwt = {
      issuer    = "https://login.microsoftonline.com/10da1d35-90f9-400b-9fd8-770597b82485/v2.0"
      audiences = [
          "api://56ee37cb-e5ad-482f-9855-86e85d8c7889",
          "56ee37cb-e5ad-482f-9855-86e85d8c7889"
    ]
    }},
]

# === Secreto con llaves RSA (creado con el bash) ===
rsa_keys_secret_name = "rsa-keys/dev"
