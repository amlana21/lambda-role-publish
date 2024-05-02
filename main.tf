terraform {
  required_version = ">= 1.2.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.11.0"
    }

    tls = {
      source = "hashicorp/tls"
      version = "4.0.4"
    }
  } 

}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}



# ---------------------------------------for Lambda---------------------------------------------
# ------------------role
data "aws_iam_policy_document" "samplesvc-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "samplesvc_lambda_access" {
  statement {
    actions   = ["logs:*","dynamodb:*","sts:AssumeRole"]
    effect   = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role" "samplesvclambdarole" {
    name               = "sample_role"
    assume_role_policy = data.aws_iam_policy_document.samplesvc-assume-role-policy.json
    inline_policy {
        name   = "policy-867530231"
        policy = data.aws_iam_policy_document.samplesvc_lambda_access.json
    }

}
resource "aws_lambda_function" "dynamicsvc_lambda" {
  function_name = "dynamicsvc_lambda"
  role          = aws_iam_role.samplesvclambdarole.arn
  handler       = "lambda_app.lambda_handler"
  runtime       = "python3.9"
  filename      = "lambda_app.zip"
  source_code_hash = filebase64sha256("lambda_app.zip")
  timeout       = 60
  memory_size   = 128
}


# ------------------------------------------------dynamic role-----------------------------------------

data "aws_iam_policy_document" "dynamic-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${aws_iam_role.samplesvclambdarole.name}/${aws_lambda_function.dynamicsvc_lambda.function_name}"]
    }
  }
}

data "aws_iam_policy_document" "dynamic_lambda_access" {
  statement {
    actions   = ["logs:*","dynamodb:*","s3:*"]
    effect   = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role" "dynamiclambdarole" {
    name               = "dynamic_role"
    assume_role_policy = data.aws_iam_policy_document.dynamic-assume-role-policy.json
    inline_policy {
        name   = "policy-86753023111"
        policy = data.aws_iam_policy_document.dynamic_lambda_access.json
    }

}



# ----------------------------------------------dynamodb--------------------------------------------
resource "aws_dynamodb_table" "roles_table" {
  name           = "roles"
  billing_mode   = "PROVISIONED"
  read_capacity = 1
  write_capacity = 1
  hash_key       = "roleid"
  attribute {
    name = "roleid"
    type = "S"
  }
}


# ---------------sample rows
resource "aws_dynamodb_table_item" "role1" {
  table_name = aws_dynamodb_table.roles_table.name
  hash_key   = aws_dynamodb_table.roles_table.hash_key

  item = <<ITEM
{
  "roleid": {"S": "1"},
  "role_arn": {"S": "${aws_iam_role.dynamiclambdarole.arn}"}
}
ITEM
}

resource "aws_dynamodb_table_item" "role2" {
  table_name = aws_dynamodb_table.roles_table.name
  hash_key   = aws_dynamodb_table.roles_table.hash_key

  item = <<ITEM
{
  "roleid": {"S": "2"},
  "role_arn": {"S": "${aws_iam_role.dynamiclambdarole.arn}"}
}
ITEM
}



# ----------------------------------------------s3--------------------------------------------
resource "aws_s3_bucket" "test_bucket" {
  bucket_prefix = "<bucket_name>"
  
}

resource "aws_s3_bucket_object" "lambda_bucket_obj" {
  bucket = aws_s3_bucket.test_bucket.bucket
  key    = "lambda_app.zip"
  source = "lambda_app.zip"
}