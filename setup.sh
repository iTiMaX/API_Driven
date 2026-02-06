#!/bin/bash

# Configuration globale
REGION="us-east-1"
API_NAME="EC2ControllerAPI"
LAMBDA_NAME="ManageEC2"
IMAGE_ID="ami-ff000000"
CODESPACE_URL="https://${CODESPACE_NAME}-4566.app.github.dev/"
gh codespace ports visibility 4566:public -c "$CODESPACE_NAME"

# Couleurs pour la lisibilite des logs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Demarrage du deploiement (Support Navigateur/GET)...${NC}"

# 0. Verification de LocalStack
echo -n "Verification de LocalStack... "
if ! curl -s localhost:4566/_localstack/health > /dev/null; then
    echo -e "\n${YELLOW}Erreur : LocalStack non demarre (Port 4566 inaccessible).${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# 1. Generation du code Lambda (Support JSON Body + URL Parameters)
echo -e "${BLUE}Generation du code Lambda...${NC}"
cat <<EOF > lambda_function.py
import boto3
import json
import os

def lambda_handler(event, context):
    public_endpoint = "${CODESPACE_URL}"
    # Configuration du client avec l'URL publique
    ec2 = boto3.client('ec2', endpoint_url=public_endpoint, region_name="${REGION}")
    
    # 1. Tentative de lecture du Body (requete POST / Makefile)
    try:
        body = json.loads(event.get('body', '{}'))
    except:
        body = {}
        
    # 2. Tentative de lecture de l'URL (requete GET / Navigateur)
    qs = event.get('queryStringParameters') or {}
    
    # Priorite aux donnees du body, fallback sur l'URL
    action = body.get('action') or qs.get('action')
    instance_id = body.get('instance_id') or qs.get('instance_id')
    
    if not instance_id:
        return {'statusCode': 400, 'body': json.dumps({'error': 'instance_id manquant'})}

    try:
        msg = ""
        if action == 'start':
            ec2.start_instances(InstanceIds=[instance_id])
            msg = f"Instance {instance_id} demarree."
        elif action == 'stop':
            ec2.stop_instances(InstanceIds=[instance_id])
            msg = f"Instance {instance_id} arretee."
        elif action == 'status':
             res = ec2.describe_instances(InstanceIds=[instance_id])
             state = res['Reservations'][0]['Instances'][0]['State']['Name']
             msg = f"Instance {instance_id} est : {state.upper()}"
        else:
            return {'statusCode': 400, 'body': json.dumps({'error': 'Action inconnue'})}
            
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'status': 'success', 'message': msg})
        }
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
EOF

rm -f function.zip && zip -q function.zip lambda_function.py

# 2. Configuration EC2
echo -e "${BLUE}Configuration de l'instance EC2...${NC}"
EXISTING_INSTANCE=$(awslocal ec2 describe-instances --region $REGION --query "Reservations[].Instances[?State.Name!='terminated'].InstanceId" --output text)

if [ -n "$EXISTING_INSTANCE" ] && [ "$EXISTING_INSTANCE" != "None" ]; then
    INSTANCE_ID=$EXISTING_INSTANCE
    echo -e "   Instance existante : ${GREEN}$INSTANCE_ID${NC}"
else
    INSTANCE_ID=$(awslocal ec2 run-instances --image-id $IMAGE_ID --count 1 --instance-type t2.micro --key-name my-key --region $REGION | jq -r '.Instances[0].InstanceId')
    echo -e "   Nouvelle instance : ${GREEN}$INSTANCE_ID${NC}"
fi

# 3. Configuration Lambda
echo -e "${BLUE}Configuration de la Lambda...${NC}"
if awslocal lambda get-function --function-name $LAMBDA_NAME --region $REGION > /dev/null 2>&1; then
    awslocal lambda update-function-code --function-name $LAMBDA_NAME --zip-file fileb://function.zip --region $REGION > /dev/null
else
    awslocal lambda create-function --function-name $LAMBDA_NAME --zip-file fileb://function.zip --handler lambda_function.lambda_handler --runtime python3.9 --role arn:aws:iam::000000000000:role/lambda-role --region $REGION > /dev/null
fi

# 4. Configuration API Gateway
echo -e "${BLUE}Configuration de l'API Gateway...${NC}"
EXISTING_API_ID=$(awslocal apigateway get-rest-apis --region $REGION | jq -r ".items[] | select(.name == \"$API_NAME\") | .id")

if [ -n "$EXISTING_API_ID" ]; then
    awslocal apigateway delete-rest-api --rest-api-id $EXISTING_API_ID --region $REGION
fi

API_ID=$(awslocal apigateway create-rest-api --name "$API_NAME" --region $REGION | jq -r '.id')
PARENT_ID=$(awslocal apigateway get-resources --rest-api-id $API_ID --region $REGION | jq -r '.items[0].id')
RESOURCE_ID=$(awslocal apigateway create-resource --rest-api-id $API_ID --parent-id $PARENT_ID --path-part manage --region $REGION | jq -r '.id')

# Utilisation de ANY pour supporter GET (navigateur) et POST (curl)
awslocal apigateway put-method --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method ANY --authorization-type "NONE" --region $REGION > /dev/null
awslocal apigateway put-integration --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method ANY --type AWS_PROXY --integration-http-method POST --uri arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:000000000000:function:$LAMBDA_NAME/invocations --region $REGION > /dev/null

awslocal apigateway create-deployment --rest-api-id $API_ID --stage-name prod --region $REGION > /dev/null

# 5. Affichage des resultats
BASE_URL="${CODESPACE_URL}restapis/${API_ID}/prod/_user_request_/manage"

# Sauvegarde de l'etat
echo "INSTANCE_ID=$INSTANCE_ID" > .env.state
echo "API_URL=$BASE_URL" >> .env.state

echo "------------------------------------------------"
echo -e "${GREEN}DEPLOIEMENT TERMINE${NC}"
echo "------------------------------------------------"
echo "Instance ID : $INSTANCE_ID"
echo ""
echo "Liens de controle direct (Navigateur) :"
echo -e "START  : ${BLUE}${BASE_URL}?action=start&instance_id=${INSTANCE_ID}${NC}"
echo -e "STOP   : ${BLUE}${BASE_URL}?action=stop&instance_id=${INSTANCE_ID}${NC}"
echo -e "STATUS : ${BLUE}${BASE_URL}?action=status&instance_id=${INSTANCE_ID}${NC}"
echo "------------------------------------------------"