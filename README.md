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
