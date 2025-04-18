#!/bin/bash

# Variables
RESOURCE_GROUP="ntms-frontdoor-rg"
LOCATION1="centralindia"
LOCATION2="eastus"
VM_NAME_PREFIX="webvm"
VNET_NAME="ntms-vnet"
SUBNET_NAME="websubnet"
USERNAME="azureuser"
PASSWORD="123#ntms123#" # Replace with Key Vault-based auth in production

# Create Resource Group
az group create --name $RESOURCE_GROUP --location $LOCATION1

# Create VNet + Subnet
az network vnet create \
  --name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION1 \
  --address-prefix 10.0.0.0/16 \
  --subnet-name $SUBNET_NAME \
  --subnet-prefix 10.0.1.0/24

# Deploy 2 VMs in different regions
for LOCATION in $LOCATION1 $LOCATION2; do
  VM_NAME="${VM_NAME_PREFIX}-${LOCATION}"
  
  az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --image Ubuntu2204 \
    --admin-username $USERNAME \
    --admin-password "$PASSWORD" \
    --vnet-name $VNET_NAME \
    --subnet $SUBNET_NAME \
    --public-ip-sku Standard \
    --location $LOCATION \
    --nics ""

  # Open port 80
  az vm open-port --resource-group $RESOURCE_GROUP --name $VM_NAME --port 80

  # Install NGINX + deploy index.html
  IP=$(az vm show -d -g $RESOURCE_GROUP -n $VM_NAME --query publicIps -o tsv)

  scp -o StrictHostKeyChecking=no index.html $USERNAME@$IP:/tmp/index.html
  ssh -o StrictHostKeyChecking=no $USERNAME@$IP << EOF
    sudo apt update
    sudo apt install -y nginx
    sudo mv /tmp/index.html /var/www/html/index.html
    sudo systemctl restart nginx
EOF
done
