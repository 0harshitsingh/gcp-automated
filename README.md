# GCP Shared VPC Lab
- State bucket: gs://singh-tf-state (prefixes: bootstrap, host/host-prj, spoke/service-prj)
- Apply order: bootstrap -> host -> spoke
- Copy terraform.tfvars.example to terraform.tfvars and fill in real values

## np/ (dev and qa host/spoke projects)

`np/folders` creates the nonprod folders. State prefix is hardcoded: `np/folders`.

`np/env` is one code folder used for every environment. The state prefix is passed at init,
so each env gets its own state. Always re-run `init -reconfigure` when switching env.

Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in real values (this file is gitignored).

### dev (billing linked)
    cd np/env
    terraform init -reconfigure -backend-config="bucket=singh-tf-state" -backend-config="prefix=np/dev"
    terraform plan -var env=dev -var link_billing=true

### qa (project only, no billing; billing account is capped at 5 projects)
    cd np/env
    terraform init -reconfigure -backend-config="bucket=singh-tf-state" -backend-config="prefix=np/qa"
    terraform plan -var env=qa -var link_billing=false

WARNING: running qa with link_billing=true (the default) will plan to attach billing.
