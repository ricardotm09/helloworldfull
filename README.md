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
