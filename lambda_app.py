

import json
import boto3

def lambda_handler(event, context):
    sts_client = boto3.client('sts')
    # query dynamodb with roleid =1
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('roles')
    response = table.get_item(
        Key={
            'roleid': "1"
        }
    )
    role_arn = response['Item']['role_arn']
    print(role_arn)
    
    # assume another role here
    response = sts_client.assume_role(
        RoleArn=role_arn,
        RoleSessionName="AssumedRoleSession",
        DurationSeconds=900
    )
    # above call gets a temporary access key, secret key and session token
    access_key = response['Credentials']['AccessKeyId']
    secret_key = response['Credentials']['SecretAccessKey']
    session_token = response['Credentials']['SessionToken']

    # to test here its listing S3 buckets
    s3_client = boto3.client(
        's3',
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        aws_session_token=session_token,
    )
    response = s3_client.list_buckets()
    buckets = [bucket['Name'] for bucket in response['Buckets']]
    print(buckets)
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }