# helloworldfull
A Hello World app with end to end flow

## Run locally
npm start

Then open http://localhost:3000

## Build and run with Docker
Build:
docker build -t click-counter-app .

Run:
docker run -p 3000:3000 click-counter-app

## For AKS practice
Once the container runs locally, you can push it to a container registry and deploy it to AKS.

## Terraform for AKS and ACR
From the Terraform environment folder:

```bash
cd terraform/environments/dev
terraform init -backend-config="resource_group_name=rg-terraform-state" -backend-config="storage_account_name=tfstateacctdemo" -backend-config="container_name=tfstate" -backend-config="key=dev.terraform.tfstate"
terraform plan
terraform apply -auto-approve
```

You can override names if needed:

```bash
terraform apply -auto-approve -var="resource_group_name=rg-aks-demo" -var="aks_name=aks-demo" -var="acr_name_prefix=acraks"
```

> Make sure the Azure Storage Account and Blob container for the backend already exist before running Terraform.
>
> For a cleaner CI pipeline, assign the Azure AD service principal used by GitHub Actions the `Storage Blob Data Contributor` role on the storage account once, outside the workflow. This avoids adding RBAC setup logic to every run.
>
> The backend storage account name is intentionally stable per repository, so the same RBAC assignment remains valid across workflow runs.

## One-time Azure bootstrap for GitHub Actions
These commands are meant to be run once to prepare Azure for the workflow.

### 1. Create the app registration and service principal
```bash
APP_NAME="github-actions-helloworldfull"
SUBSCRIPTION_ID="<subscription-id>"
TENANT_ID="<tenant-id>"

az ad app create --display-name "$APP_NAME" --sign-in-audience "AzureADMyOrg"
APP_OBJECT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].id" -o tsv)
APP_CLIENT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

az ad sp create --id "$APP_CLIENT_ID"
SP_OBJECT_ID=$(az ad sp show --id "$APP_CLIENT_ID" --query id -o tsv)
```

### 2. Add federated credential for GitHub OIDC
```bash
az ad app federated-credential create \
  --id "$APP_OBJECT_ID" \
  --parameters '{
    "name":"github-env-dev",
    "issuer":"https://token.actions.githubusercontent.com",
    "subject":"repo:<owner>/<repo>:environment:dev",
    "audiences":["api://AzureADTokenExchange"]
  }'
```

### 3. Grant Azure RBAC roles
```bash
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/<tf-state-resource-group>/providers/Microsoft.Storage/storageAccounts/<tf-state-storage-account>"
```

### 4. Create the Terraform backend storage account and container
```bash
RESOURCE_GROUP="<tf-state-resource-group>"
STORAGE_ACCOUNT="<tf-state-storage-account>"
CONTAINER_NAME="terraform"
LOCATION="eastus"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --https-only true
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login
```

These setup steps are a good fit for a README because they are operational prerequisites for the project and are easier to reuse than hiding them in a workflow or a one-off shell history.

## Branch protection baseline (recommended)
Apply these settings to the main branch:

- Require a pull request before merging.
- Require at least 1 approval for all changes.
- Dismiss stale approvals when new commits are pushed.
- Require status checks to pass before merging.
- Set required check to: PR Validation / terraform-validate.
- Set required check to: Enforce Action Pinning / check-pinned-actions.
- Include administrators in branch protection.
- Restrict force pushes and branch deletion.

This keeps terraform format, validate, and plan checks mandatory before code reaches deploy.

## CI supply chain hardening
GitHub Actions in these workflows are pinned to immutable commit SHAs:

- .github/workflows/pr-validation.yml
- .github/workflows/deploy.yml

Review and update those SHA pins on a regular cadence (for example, monthly) to pull in upstream security fixes in a controlled way.

This repository includes an automated monthly updater workflow:

- .github/workflows/action-sha-update.yml

It runs on a monthly schedule and can also be run manually. When newer SHAs are available for the pinned action major tags, it opens a pull request with the updates.

The SHA rotation scope includes:

- .github/workflows/deploy.yml
- .github/workflows/pr-validation.yml
- .github/workflows/terraform-drift-detection.yml

## Security gates added
- PR validation includes a tfsec scan that fails on HIGH severity Terraform findings.
- PR validation installs Conftest from the official GitHub release and verifies SHA256 before running policy checks.
- PR validation includes Conftest policy checks for Kubernetes manifests under `policy/kubernetes`.
- PR and deploy workflows publish SARIF scan findings to the GitHub Security tab.
- Deploy workflow builds and pushes the image, then constructs an immutable digest reference.
- Deploy workflow signs the digest-pinned image with Cosign keyless signing (GitHub OIDC identity).
- Deploy workflow verifies the Cosign signature and issuer identity before AKS deployment, pinned to `.github/workflows/deploy.yml@refs/heads/main`.
- Deploy workflow ensures Kyverno is installed on AKS and applies a ClusterPolicy that admits `click-counter` Pods only when image signatures come from `.github/workflows/deploy.yml@refs/heads/main` via GitHub OIDC issuer.
- Deploy workflow generates an SBOM for the digest-pinned image and uploads it as an artifact.
- Deploy workflow runs Trivy against the pushed image and fails on HIGH or CRITICAL vulnerabilities.
- AKS deployment is blocked unless the image reference is digest-pinned (`@sha256:...`).

## Drift detection
- .github/workflows/terraform-drift-detection.yml runs nightly and on demand.
- It executes `terraform plan -detailed-exitcode` in `terraform/environments/dev`.
- Exit code `2` (drift detected) fails the workflow and uploads `terraform-drift-dev` artifacts for review.

## Multi-environment promotion (build once)
- `.github/workflows/deploy.yml` is split into staged jobs: `terraform-plan` -> `terraform-apply` -> `build-and-sign` -> `deploy-dev` -> `deploy-stage` -> `deploy-prod`.
- Container build, scanning, SBOM generation, and signing run once in `build-and-sign`.
- The immutable digest reference is published as an artifact (`image-release`) and promoted unchanged across environments.
- `deploy-dev`, `deploy-stage`, and `deploy-prod` call reusable workflow `.github/workflows/deploy-environment.yml` to keep deployment logic centralized.
- Each environment deployment verifies the signature again before cluster apply.
- On rollout health or smoke-test failure, deployment is automatically rolled back (`kubectl rollout undo`) and the job fails.
- Configure GitHub Environments `dev`, `stage`, and `prod` with required reviewers to enforce promotion approvals.
- Each deploy stage uses its own namespace (`dev`, `stage`, `prod`) and per-environment concurrency group.
    