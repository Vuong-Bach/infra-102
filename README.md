# infra-102

Minimal AWS base infrastructure — VPC + EKS cluster — provisioned with Terraform and deployed via GitHub Actions CI/CD using OIDC (no long-lived AWS credentials).

## Architecture

```
AWS Account
└── VPC (10.0.0.0/16, 2 AZs)
    ├── Public subnets  — Internet Gateway + NAT Gateway
    ├── Private subnets — EKS nodes + workloads
    └── EKS Cluster
        ├── Managed node group (t3.medium, ON_DEMAND)
        ├── Secrets encrypted with KMS
        ├── IMDSv2 enforced on all nodes
        └── OIDC provider (IRSA-ready)
```

## Repo layout

```
infra-102/
├── bootstrap/                    # One-time: state bucket + GitHub OIDC + IAM roles
├── modules/
│   ├── networking/               # VPC, subnets, IGW, NAT GW, VPC endpoints
│   ├── security/                 # Security groups, KMS key
│   └── eks/                      # EKS cluster, node group, IRSA OIDC provider
├── environments/
│   └── sandbox/
│       ├── 1-networking/         # Layer 1 — calls networking + security modules
│       └── 2-cluster/            # Layer 2 — calls eks module, reads Layer 1 state
├── scripts/
│   ├── local-check.sh            # Run fmt + validate locally before pushing
│   └── set-github-secrets.sh     # Set GitHub Actions secrets from bootstrap outputs
└── .github/workflows/
    ├── tf-plan.yml               # Runs on every PR → terraform plan
    ├── tf-apply.yml              # Runs on merge to main → terraform apply
    └── tf-destroy.yml            # Manual only → terraform destroy (reverse order)
```

Each environment layer has its own Terraform state file, its own `terraform init`, and no `-target` hacks.

---

## Setup (first time)

### Prerequisites

- AWS CLI configured (`aws configure`) with admin credentials
- Terraform >= 1.7
- GitHub CLI (`gh`) authenticated — `gh auth login`
- Git

### Step 1 — Bootstrap

Bootstrap creates the S3 state bucket, DynamoDB lock table, KMS key, GitHub OIDC provider, and two IAM roles (plan / apply).

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set your aws_region and github_repo
terraform init
terraform apply
```

Outputs:

```
aws_region       = "ap-southeast-1"
state_bucket     = "infra102-sandbox-tfstate-<account_id>"
state_lock_table = "infra102-sandbox-tfstate-lock"
plan_role_arn    = "arn:aws:iam::<account_id>:role/infra102-sandbox-ci-plan"
apply_role_arn   = "arn:aws:iam::<account_id>:role/infra102-sandbox-ci-apply"
```

### Step 2 — Configure GitHub secrets

Run the script to set all secrets from bootstrap outputs automatically:

```bash
./scripts/set-github-secrets.sh
```

This sets the following secrets in the repo:

| Secret | Source |
|---|---|
| `AWS_REGION` | `var.aws_region` in bootstrap |
| `TF_STATE_BUCKET` | bootstrap output |
| `TF_STATE_LOCK_TABLE` | bootstrap output |
| `TF_PLAN_ROLE_ARN` | bootstrap output |
| `TF_APPLY_ROLE_ARN` | bootstrap output |

### Step 3 — Create GitHub environment

Go to **GitHub → repo Settings → Environments → New environment**, create one named `sandbox`.

> Apply jobs run under this environment. The OIDC `sub` claim for apply jobs is `repo:<owner>/<repo>:environment:sandbox` — this is what the apply role trust policy expects.

### Step 4 — Push to main → CI/CD runs automatically

```bash
git push origin main
```

The `tf-apply.yml` workflow triggers and applies both layers in order.

---

## Local development

### Apply Layer 1 manually

```bash
cd environments/sandbox/1-networking
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="key=sandbox/1-networking/terraform.tfstate" \
  -backend-config="region=ap-southeast-1" \
  -backend-config="dynamodb_table=<TF_STATE_LOCK_TABLE>"

terraform plan
terraform apply
```

### Apply Layer 2 manually

```bash
cd environments/sandbox/2-cluster
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="key=sandbox/2-cluster/terraform.tfstate" \
  -backend-config="region=ap-southeast-1" \
  -backend-config="dynamodb_table=<TF_STATE_LOCK_TABLE>"

terraform plan -var="tf_state_bucket=<TF_STATE_BUCKET>"
terraform apply -var="tf_state_bucket=<TF_STATE_BUCKET>"
```

### Connect kubectl after Layer 2 applies

```bash
aws eks update-kubeconfig \
  --region ap-southeast-1 \
  --name infra102-sandbox-cluster

kubectl get nodes
```

---

## Local checks

Run these checks locally before pushing a change:

```bash
make check
```

---

## CI/CD flow

```
Pull Request opened
  └── tf-plan.yml
        ├── Plan · 1-networking  (fmt check + validate + plan)
        └── Plan · 2-cluster     (fmt check + validate + plan, requires layer 1 state)

Merged to main / workflow_dispatch
  └── tf-apply.yml
        ├── Apply · 1-networking
        └── Apply · 2-cluster    (runs after 1-networking succeeds)

Manual only
  └── tf-destroy.yml
        ├── Destroy · 2-cluster  (requires confirm = "destroy")
        └── Destroy · 1-networking
```

Authentication uses GitHub Actions OIDC — no AWS access keys are stored anywhere.

- **Plan role** — any branch/PR can assume it (`sub: repo:*`)
- **Apply role** — only jobs running in the `sandbox` environment can assume it (`sub: repo:*:environment:sandbox`)

> Note: `Plan · 2-cluster` will fail if layer 1 has never been applied (no remote state exists yet). Apply layer 1 first.

---

## Extending

To add a new layer (e.g., Karpenter, Ingress, ArgoCD):

1. Create `environments/sandbox/3-platform/`
2. Add `data "terraform_remote_state" "cluster"` pointing to the `2-cluster` state key
3. Add `plan-platform` and `apply-platform` jobs in the workflow files
4. Create the module under `modules/` if needed

To add a new environment (staging/production): copy `environments/sandbox/` → `environments/staging/`, update the state keys and `name_prefix`.
