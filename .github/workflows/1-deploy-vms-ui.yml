name: Deploy VMs

on:
  workflow_dispatch:

env:
  RESOURCE_GROUP: fd-rg
  IMAGE: Ubuntu2204
  VM_SIZE: Standard_B1s
  ADMIN_USERNAME: azureuser
  VM_PASSWORD: ${{ secrets.VM_PASSWORD }}
  
jobs:
  create-resources:
    runs-on: ubuntu-latest
    steps:
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: Create Resource Group
      run: |
        az group create --name $RESOURCE_GROUP --location centralindia
    
    
  deploy-vms:
    needs: create-resources
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - LOCATION: centralindia
            VM_NAME: web1
          - LOCATION: eastus
            VM_NAME: web2
          - LOCATION: australiaeast
            VM_NAME: web3

    steps:
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: Checkout repository
      uses: actions/checkout@v3

    - name: Create VM (idempotent)
      run: |
        if ! az vm show --name ${{ matrix.VM_NAME }} --resource-group $RESOURCE_GROUP &>/dev/null; then
          az vm create \
            --resource-group $RESOURCE_GROUP \
            --name ${{ matrix.VM_NAME }} \
            --image $IMAGE \
            --admin-username $ADMIN_USERNAME \
            --admin-password $VM_PASSWORD \
            --location ${{ matrix.LOCATION }} \
            --size $VM_SIZE \
            --public-ip-sku Standard \
            --authentication-type password \
            --nsg-rule SSH
         fi

         # Ensure HTTP (port 80) is also allowed
         az vm open-port --port 80 --resource-group $RESOURCE_GROUP --name ${{ matrix.VM_NAME }}
        
    

    - name: Install sshpass
      run: sudo apt-get update && sudo apt-get install -y sshpass
    
    - name: Checkout repository
      uses: actions/checkout@v3


    - name: Deploy app files to all web VMs
      run: |
          for ip in $web1_IP $web2_IP $web3_IP; do
          sshpass -p "${{ secrets.VM_PASSWORD }}" scp -o StrictHostKeyChecking=no index.html azureuser@$ip:/home/azureuser/
          sshpass -p "${{ secrets.VM_PASSWORD }}" ssh -o StrictHostKeyChecking=no azureuser@$ip << EOF
          sudo apt update
          sudo apt install -y nginx
          sudo mv /home/azureuser/index.html /var/www/html/index.html
          sudo systemctl reload nginx
          EOF
          done

       
       
    
    
