#!/bin/bash

RESOURCE_GROUP="fd-rg"
STORAGE_NAME="ntmsimages$(openssl rand -hex 3)"
LOCATION="centralindia"
CONTAINER_NAME="images"

# Create Storage Account
az storage account create \
  --name $STORAGE_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2

# Get key
STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_NAME --query "[0].value" -o tsv)

# Create Blob Container
echo "Creating container: $CONTAINER_NAME in account: $STORAGE_NAME"
container_create_output=$(az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_NAME" \
  --account-key "$STORAGE_KEY" \
  --public-access blob 2>&1)

if [[ $? -ne 0 ]]; then
  echo "❌ Failed to create container: $container_create_output"
  exit 1
else
  echo "✅ Container ensured: $CONTAINER_NAME"
fi


# Upload all images from local /images folder
for image in images/*; do
  az storage blob upload \
    --account-name $STORAGE_NAME \
    --account-key $STORAGE_KEY \
    --container-name $CONTAINER_NAME \
    --name $(basename $image) \
    --file $image
done
