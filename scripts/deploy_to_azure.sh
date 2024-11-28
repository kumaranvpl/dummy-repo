#!/bin/bash

# Script to deploy to Azure Container Apps using Azure CLI

# Variables
RESOURCE_GROUP="new-my-fastagency-app-rg"
CONTAINER_APP_NAME="new-my-fastagency-app"
LOCATION="westeurope"
ACR_NAME="newmyfastagencyacr"


echo -e "\033[0;32mChecking if already logged into Azure\033[0m"
if ! az account show > /dev/null 2>&1; then
    echo -e "\033[0;32mLogging into Azure\033[0m"
    az login
else
    echo -e "\033[0;32mAlready logged into Azure\033[0m"
fi

# az extension add --name containerapp --upgrade
# az provider register --namespace Microsoft.App
# az provider register --namespace Microsoft.OperationalInsights

echo -e "\033[0;32mCreating resource group if it doesn't exists already\033[0m"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo -e "\033[0;32mCreating azure container registry if it doesn't exists already\033[0m"
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true
rm ~/.docker/config.json
az acr login --name $ACR_NAME

echo -e "\033[0;32mBuilding and pushing docker image to azure container registry\033[0m"
docker build -t $ACR_NAME.azurecr.io/${CONTAINER_APP_NAME}:latest -f docker/Dockerfile .
docker push $ACR_NAME.azurecr.io/${CONTAINER_APP_NAME}:latest

echo -e "\033[0;32mCreating container app environment\033[0m"
az containerapp env create \
  --name "$CONTAINER_APP_NAME-env" \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

echo -e "\033[0;32mCreating container app\033[0m"
az containerapp create \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment "$CONTAINER_APP_NAME-env" \
  --image $ACR_NAME.azurecr.io/${CONTAINER_APP_NAME}:latest \
  --target-port 8888 \
  --ingress 'external' \
  --query properties.configuration.ingress.fqdn \
  --registry-server $ACR_NAME.azurecr.io \
  --cpu 0.5 \
  --memory 1Gi \
  --min-replicas 0 \
  --max-replicas 1 \
  --env-vars OPENAI_API_KEY=$OPENAI_API_KEY

# echo -e "\033[0;32mUpdating container app\033[0m"
# az containerapp update \
#   --name $CONTAINER_APP_NAME \
#   --resource-group $RESOURCE_GROUP \
#   --add-ports 8008
