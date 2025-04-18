#!/bin/bash
set -e

RESOURCE_GROUP="ntms-frontdoor-rg1"
LOCATIONS=("centralindia" "eastus" "australiaeast")
VNET_NAME="ntms-vnet"
SUBNET_NAME="websubnet"
VM_ADMIN="azureuser"
VM_PASSWORD="Ntms@12345!"
VM_IMAGE="Ubuntu2204"
VM_SIZE="Standard_B1s"
echo "📦 Checking resource group: $RESOURCE_GROUP"

if ! az group show --name $RESOURCE_GROUP &>/dev/null; then
  echo "🔹 Creating resource group: $RESOURCE_GROUP"
  az group create --name $RESOURCE_GROUP --location centralindia
else
  echo "✅ Resource group exists: $RESOURCE_GROUP"
fi


# Get subnet ID
SUBNET_ID=$(az network vnet subnet show \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $SUBNET_NAME \
  --query id -o tsv)

for REGION in "${LOCATIONS[@]}"; do
  VM_NAME="webvm-${REGION}"
  IP_NAME="pip-${VM_NAME}"
  NIC_NAME="nic-${VM_NAME}"

  echo "⚙️ Processing VM: $VM_NAME ($REGION)"

  # Public IP
  if ! az network public-ip show --resource-group $RESOURCE_GROUP --name $IP_NAME &>/dev/null; then
    echo "🔹 Creating public IP: $IP_NAME"
    az network public-ip create \
      --resource-group $RESOURCE_GROUP \
      --name $IP_NAME \
      --location $REGION \
      --allocation-method Static \
      --sku Basic
  else
    echo "✅ Public IP exists: $IP_NAME"
  fi

  # NIC
  if ! az network nic show --resource-group $RESOURCE_GROUP --name $NIC_NAME &>/dev/null; then
    echo "🔹 Creating NIC: $NIC_NAME"
    az network nic create \
      --resource-group $RESOURCE_GROUP \
      --name $NIC_NAME \
      --vnet-name $VNET_NAME \
      --subnet $SUBNET_NAME \
      --location $REGION \
      --public-ip-address $IP_NAME
  else
    echo "✅ NIC exists: $NIC_NAME"
  fi

  # VM
  if ! az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME &>/dev/null; then
    echo "🔹 Creating VM: $VM_NAME"
    az vm create \
      --resource-group $RESOURCE_GROUP \
      --name $VM_NAME \
      --location $REGION \
      --nics $NIC_NAME \
      --image $VM_IMAGE \
      --admin-username $VM_ADMIN \
      --admin-password $VM_PASSWORD \
      --authentication-type password \
      --size $VM_SIZE \
      --no-wait
  else
    echo "✅ VM already exists: $VM_NAME"
  fi
done

echo "⏳ Waiting for VMs to be ready..."
az vm wait --created --ids $(az vm list --resource-group $RESOURCE_GROUP --query "[].id" -o tsv)

# Deploy index.html content to each VM
for REGION in "${LOCATIONS[@]}"; do
  VM_NAME="webvm-${REGION}"

  echo "🌐 Installing NGINX and deploying HTML on $VM_NAME..."

  az vm run-command invoke \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --command-id RunShellScript \
    --scripts '
      sudo apt update && sudo apt install -y nginx
      echo "'"$(<index.html)"'" | sudo tee /var/www/html/index.html > /dev/null
    '
done

echo "✅ Idempotent VM deployment + UI completed!"
