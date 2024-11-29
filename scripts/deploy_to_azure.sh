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

echo -e "\033[0;32mCreating resource group if it doesn't exists already\033[0m"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo -e "\033[0;32mCreating azure container registry if it doesn't exists already\033[0m"
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true
rm ~/.docker/config.json
az acr login --name $ACR_NAME

echo -e "\033[0;32mBuilding and pushing docker image to azure container registry\033[0m"
docker build -t $ACR_NAME.azurecr.io/${CONTAINER_APP_NAME}:latest -f docker/Dockerfile .
docker push $ACR_NAME.azurecr.io/${CONTAINER_APP_NAME}:latest

echo -e "\033[0;32mChecking if container app environment exists\033[0m"
if ! az containerapp env show --name "$CONTAINER_APP_NAME-env" --resource-group $RESOURCE_GROUP > /dev/null 2>&1; then
    echo -e "\033[0;32mCreating container app environment\033[0m"
    az containerapp env create \
      --name "$CONTAINER_APP_NAME-env" \
      --resource-group $RESOURCE_GROUP \
      --location $LOCATION
else
    echo -e "\033[0;32mContainer app environment already exists\033[0m"
fi

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
  --cpu 1 \
  --memory 2Gi \
  --min-replicas 0 \
  --max-replicas 2 \
  --env-vars OPENAI_API_KEY=$OPENAI_API_KEY

echo -e "\033[0;32mSetting up session affinity\033[0m"
az containerapp ingress sticky-sessions set \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --affinity sticky

echo -e "\033[0;32mFetching your Azure Container App's hosted URL\033[0m"
FQDN=$(az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
echo -e "\033[0;32mYour Azure Container App's hosted URL is: https://$FQDN\033[0m"
