import boto3
import json
import os

def lambda_handler(event, context):
    public_endpoint = "https://vigilant-space-goldfish-gjq5xpx6qjpf95rg-4566.app.github.dev/"
    ec2 = boto3.client('ec2', endpoint_url=public_endpoint, region_name="us-east-1")
    
    # 1. Essai de recuperation via Body (POST/Makefile)
    try:
        body = json.loads(event.get('body', '{}'))
    except:
        body = {}
        
    # 2. Essai de recuperation via URL (GET/Navigateur)
    qs = event.get('queryStringParameters') or {}
    
    # Priorite au body, sinon URL
    action = body.get('action') or qs.get('action')
    instance_id = body.get('instance_id') or qs.get('instance_id')
    
    if not instance_id:
        return {'statusCode': 400, 'body': json.dumps({'error': 'instance_id manquant'})}

    try:
        msg = ""
        if action == 'start':
            ec2.start_instances(InstanceIds=[instance_id])
            msg = f"Instance {instance_id} demarree (START)."
        elif action == 'stop':
            ec2.stop_instances(InstanceIds=[instance_id])
            msg = f"Instance {instance_id} arretee (STOP)."
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
