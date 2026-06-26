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
└── .github/workflows/
    ├── tf-plan.yml               # Runs on every PR → terraform plan
    └── tf-apply.yml              # Runs on merge to main → terraform apply
```

Each environment layer has its own Terraform state file, its own `terraform init`, and no `-target` hacks.

---

## Setup (first time)

### Prerequisites

- AWS CLI configured (`aws configure`) with admin credentials
- Terraform >= 1.7
- Git

### Step 1 — Bootstrap (run once locally)

Bootstrap creates the S3 state bucket, DynamoDB lock table, GitHub OIDC provider, and two IAM roles (plan / apply).

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set github_repo = "Vuong-Bach/infra-102" and your region
terraform init
terraform apply
```

Note the outputs — you will need them in the next step:

```
state_bucket      = "infra102-sandbox-tfstate-<account_id>"
state_lock_table  = "infra102-sandbox-tfstate-lock"
plan_role_arn     = "arn:aws:iam::<account>:role/infra102-sandbox-ci-plan"
apply_role_arn    = "arn:aws:iam::<account>:role/infra102-sandbox-ci-apply"
```

### Step 2 — Configure GitHub repository variables

Go to **GitHub → Settings → Secrets and variables → Actions → Variables** and add:

| Variable | Value (from bootstrap output) |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | `infra102-sandbox-tfstate-<account_id>` |
| `TF_STATE_LOCK_TABLE` | `infra102-sandbox-tfstate-lock` |
| `TF_PLAN_ROLE_ARN` | ARN of the plan role |
| `TF_APPLY_ROLE_ARN` | ARN of the apply role |

> These are **Variables** (not Secrets) — they are not sensitive and are visible in workflow logs.

### Step 3 — Push to main → CI/CD runs automatically

```bash
git add .
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/Vuong-Bach/infra-102.git
git push -u origin main
```

The `tf-apply.yml` workflow will trigger and apply both layers in order.

---

## Local development

### Apply Layer 1 manually

```bash
cd environments/sandbox/1-networking
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="key=sandbox/1-networking/terraform.tfstate" \
  -backend-config="region=us-east-1" \
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
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=<TF_STATE_LOCK_TABLE>"

terraform plan \
  -var="tf_state_bucket=<TF_STATE_BUCKET>"

terraform apply \
  -var="tf_state_bucket=<TF_STATE_BUCKET>"
```

### Connect kubectl after Layer 2 applies

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name infra102-sandbox-cluster

kubectl get nodes
```

---

## CI/CD flow

```
Pull Request opened
  └── tf-plan.yml
        ├── Plan · 1-networking  (fmt check + validate + plan)
        └── Plan · 2-cluster     (fmt check + validate + plan)

Merged to main
  └── tf-apply.yml
        ├── Apply · 1-networking
        └── Apply · 2-cluster    (runs after 1-networking succeeds)
```

Authentication uses GitHub Actions OIDC — no AWS access keys are stored anywhere.

- **Plan role** — any branch/PR can assume it (read-only)
- **Apply role** — only `refs/heads/main` can assume it

---

## Extending

To add a new layer (e.g., Karpenter, Ingress, ArgoCD):

1. Create `environments/sandbox/3-platform/`
2. Add `data "terraform_remote_state" "cluster"` pointing to the `2-cluster` state key
3. Add `plan-platform` and `apply-platform` jobs in the workflow files
4. Create the module under `modules/` if needed

To add a new environment (staging/production): copy `environments/sandbox/` → `environments/staging/`, update the state keys and `name_prefix`.
