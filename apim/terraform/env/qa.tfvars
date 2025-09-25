org        = "ibk"
domain     = "bb"
app        = "apigw"
env        = "qa"
region     = "us-east-1"
stage_name = "qa"

tags = {
  owner = "d&a"
  env   = "qa"
}
# completar con tus valores reales
nlb_arns          = ["arn:aws:elasticloadbalancing:us-east-1:111122223333:loadbalancer/net/eks-svc/abc123"]
lambda_subnet_ids = ["subnet-aaa", "subnet-bbb"]
lambda_sg_ids     = ["sg-xxx"]

preproxy_lambdas = [
  {
    name     = "pre-proc-normalize"
    zip_path = "../lambda/pre-proc-normalize/dist/pre-proc-normalize.zip"
    handler  = "index.handler"
    runtime  = "nodejs20.x"
    role_arn = "arn:aws:iam::111122223333:role/lambda-preproc-role"
    env_vars = { NLB_URL = "internal-eks-svc-abc.us-east-1.elb.amazonaws.com" }
  }
]

apis = [
  {
    name         = "bb-ux-users"
    display_name = "users"
    openapi_path = "../openapi/users/openapi.yaml"
    jwt = {
      issuer    = "https://login.microsoftonline.com/<TENANT_ID>/v2.0"
      audiences = ["api://bb-users"]
    }
    routes = []
  },
  {
    name         = "bb-loan-overview"
    display_name = "loan-overview"
    jwt = {
      issuer    = "https://login.microsoftonline.com/<TENANT_ID>/v2.0"
      audiences = ["api://bb-loan"]
    }
    routes = [
      {
        route_key = "GET /loan-overview"
        integration = {
          type    = "VPC_LINK"
          nlb_dns = "internal-eks-svc-abc.us-east-1.elb.amazonaws.com"
          port    = 8080
          method  = "GET"
        }
      },
      {
        route_key = "POST /loan-overview/prepare"
        integration = {
          type        = "LAMBDA"
          lambda_name = "pre-proc-normalize"
        }
      }
    ]
  }
]
