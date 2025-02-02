import json
import boto3

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('PersonalWebsiteCounter')

    response = table.get_item(
        Key={
            'Count': 0
        }
    )
    
    value = response['Item']['Value']
    value += 1
    
    table.update_item(
        Key={
            'Count': 0
        },
        UpdateExpression='SET #val = :val1',
        ExpressionAttributeNames={
            "#val": "Value"
        },
        ExpressionAttributeValues={
            ':val1': value
        }
    )

    return {
        'statusCode': 200,
        'headers': {
            "Access-Control-Allow-Headers" : "Content-Type",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET"
        },
        'body': value
    }