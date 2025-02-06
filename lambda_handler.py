import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('PersonalWebsiteCounter')

def lambda_handler(event, context):
    response = table.update_item(
        Key={'Count': 0},
        UpdateExpression='SET #val = if_not_exists(#val, :zero) + :incr',
        ExpressionAttributeNames={'#val': 'Value'},
        ExpressionAttributeValues={':incr': 1, ':zero': 0},
        ReturnValues='UPDATED_NEW'  # Returns the new counter value
    )

    updated_value = response['Attributes']['Value']

    return {
        'statusCode': 200,
        'headers': {
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET"
        },
        'body': updated_value
    }