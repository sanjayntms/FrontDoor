#!/bin/bash
set -e

RESOURCE_GROUP="fd-rg"
LOCATION="centralindia"
STORAGE_PREFIX="ntmsimages"
CONTAINER_NAME="images"
IMAGE_DIR="images"

# File to persist the storage account name
STORAGE_TRACK_FILE=".storage_name"

# Step 1: Ensure Resource Group exists
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
  echo "❌ Resource group '$RESOURCE_GROUP' not found."
  exit 1
fi

# Step 2: Resolve or create storage account
if [[ -f "$STORAGE_TRACK_FILE" ]]; then
  STORAGE_NAME=$(<"$STORAGE_TRACK_FILE")
  echo "📁 Reusing tracked storage account: $STORAGE_NAME"
else
  echo "🔍 Searching for existing storage account with prefix '$STORAGE_PREFIX'..."
  STORAGE_NAME=$(az storage account list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?starts_with(name, '$STORAGE_PREFIX')].name" \
    -o tsv | head -n1)

  if [ -z "$STORAGE_NAME" ]; then
    STORAGE_NAME="${STORAGE_PREFIX}$(openssl rand -hex 3)"
    echo "🆕 Creating new storage account: $STORAGE_NAME"
    az storage account create \
      --name "$STORAGE_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --location "$LOCATION" \
      --sku Standard_LRS \
      --kind StorageV2 \
      --allow-blob-public-access true
  else
    echo "✅ Found existing storage account: $STORAGE_NAME"
  fi

  # Persist the name
  echo "$STORAGE_NAME" > "$STORAGE_TRACK_FILE"
fi

# Step 3: Get key
echo "🔐 Getting storage key..."
STORAGE_KEY=$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_NAME" \
  --query "[0].value" -o tsv)

# Step 4: Ensure blob container
echo "📦 Ensuring container: $CONTAINER_NAME"
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_NAME" \
  --account-key "$STORAGE_KEY" \
  --public-access blob \
  --only-show-errors 1>/dev/null || true

# Step 5: Upload images
echo "📤 Uploading images from '$IMAGE_DIR/'..."
for image in "$IMAGE_DIR"/*; do
  [ -e "$image" ] || continue
  echo "🔄 Uploading: $(basename "$image")"
  az storage blob upload \
    --account-name "$STORAGE_NAME" \
    --account-key "$STORAGE_KEY" \
    --container-name "$CONTAINER_NAME" \
    --name "$(basename "$image")" \
    --file "$image" \
    --overwrite
done

echo "✅ All images uploaded to:"
echo "   https://${STORAGE_NAME}.blob.core.windows.net/${CONTAINER_NAME}/"
