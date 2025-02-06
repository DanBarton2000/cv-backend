terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "eu-west-2"
}

resource "local_file" "lambda_code" {
  content  = file("${path.module}/lambda_handler.py")
  filename = "${path.module}/lambda_handler.py"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local_file.lambda_code.filename
  output_path = "${path.module}/lambda.zip"
}

# API Gateway (HTTP API)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "CounterAPI"
  protocol_type = "HTTP"
}

# Lambda Integration with API Gateway
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambda.invoke_arn
  payload_format_version = "2.0"
}

# Route: GET /Counter
resource "aws_apigatewayv2_route" "get_counter_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /Counter"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Stage with Auto-Deploy ($default)
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Lambda Permission to Allow API Gateway to Invoke
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# 8Output the API Endpoint
output "api_endpoint" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

resource "aws_lambda_function" "lambda" {
  function_name = "CounterProcessor"
  handler       = "lambda_handler.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_execution.arn
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.dynamodb_table.name
    }
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_iam_role" "lambda_execution" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_dynamodb_table" "dynamodb_table" {
  name         = "PersonalWebsiteCounter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Count"

  attribute {
    name = "Count"
    type = "N"
  }
}

resource "aws_iam_policy" "dynamodb_access" {
  name        = "LambdaDynamoDBAccess"
  description = "Allows Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Scan", "dynamodb:Query"]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.dynamodb_table.arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_dynamodb_attachment" {
  name       = "lambda-dynamodb-attachment"
  roles      = [aws_iam_role.lambda_execution.name]
  policy_arn = aws_iam_policy.dynamodb_access.arn
}
