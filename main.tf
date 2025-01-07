provider "aws" {
  region = var.region
}

variable "region" {
  default = "us-east-1"
}

#fecha actual
locals {
  current_date = formatdate("YYYY/MM/DD", timestamp()) # Formato de fecha: YYYY/MM/DD
}

#bucket raw

resource "aws_s3_bucket" "raw_bucket" {
  bucket = "cce-datalake-raw"
  acl    = "private"
}

#subir proveedores.csv al bucket raw
resource "aws_s3_object" "proveedores_csv" {
  bucket = aws_s3_bucket.raw_bucket.id
  key    = "proveedores/${local.current_date}/proveedores.csv"
  source = "data/proveedores.csv"
  acl    = "private"
}

#subir clientes.csv al bucket raw
resource "aws_s3_object" "clientes_csv" {
  bucket = aws_s3_bucket.raw_bucket.id
  key    = "clientes/${local.current_date}/clientes.csv"
  source = "data/clientes.csv"
  acl    = "private"
}

#subir transacciones.csv al bucket raw
resource "aws_s3_object" "transacciones_csv" {
  bucket = aws_s3_bucket.raw_bucket.id
  key    = "transacciones/${local.current_date}/transacciones.csv"
  source = "data/transacciones.csv"
  acl    = "private"
}

#bucket processed

resource "aws_s3_bucket" "processed_bucket" {
  bucket = "cce-datalake-processed"
  acl    = "private"
}

#bucket analytics

resource "aws_s3_bucket" "analytics_bucket" {
  bucket = "cce-datalake-analytics"
  acl    = "private"
}

#bucket servicios

resource "aws_s3_bucket" "service_bucket" {
  bucket = "cce-datalake-service"
  acl    = "private"
}


#db en el catalogo para raw

resource "aws_glue_catalog_database" "raw_database" {
  name = "cce_datalake_raw_db"
}

#IAM role para glue

resource "aws_iam_role" "glue_role" {
  name = "GlueServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

#asociar politica necesaria al rol

resource "aws_iam_policy_attachment" "glue_role_policy" {
  name       = "GlueRolePolicy"
  roles      = [aws_iam_role.glue_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

#politica personalizada para S3

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "GlueS3AccessPolicy"
  role = aws_iam_role.glue_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:*"
        ],
        Resource = [
          "arn:aws:s3:::cce-datalake-raw",
          "arn:aws:s3:::cce-datalake-raw/*",
          "arn:aws:s3:::cce-datalake-processed",
          "arn:aws:s3:::cce-datalake-processed/*",
          "arn:aws:s3:::cce-datalake-service",
          "arn:aws:s3:::cce-datalake-service/*"
        ]
      }
    ]
  })
}

#Crawler para el bucket raw

resource "aws_glue_crawler" "raw_crawler" {
  name          = "cce-raw-crawler"
  database_name = aws_glue_catalog_database.raw_database.name
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.raw_bucket.bucket}/"
  }

  table_prefix = "raw_"
}

#subir script raw_to_processed a s3

resource "aws_s3_object" "raw_to_processed_script" {
  bucket = aws_s3_bucket.service_bucket.id
  key    = "scripts/raw_to_processed.py"
  source = "raw_to_processed.py"
  acl    = "private"
}

#glue job proveedores

resource "aws_glue_job" "raw_to_processed_job_proveedores" {
  name     = "cce-proveedores-raw-to-processed-etl1"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "pythonshell"
    python_version  = "3.9"
    script_location = "s3://${aws_s3_bucket.service_bucket.bucket}/scripts/raw_to_processed.py"
  }

  default_arguments = {
    "--INPUT_BUCKET"  = aws_s3_bucket.raw_bucket.bucket
    "--OUTPUT_BUCKET" = aws_s3_bucket.processed_bucket.bucket
    "--PATH_KEY"      = "proveedores"
    "--TempDir"       = "s3://${aws_s3_bucket.service_bucket.bucket}/temporary/"
  }

  max_capacity = 0.0625
}

#glue job clientes

resource "aws_glue_job" "raw_to_processed_job_clientes" {
  name     = "cce-clientes-raw-to-processed-etl1"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "pythonshell"
    python_version  = "3.9"
    script_location = "s3://${aws_s3_bucket.service_bucket.bucket}/scripts/raw_to_processed.py"
  }

  default_arguments = {
    "--INPUT_BUCKET"  = aws_s3_bucket.raw_bucket.bucket
    "--OUTPUT_BUCKET" = aws_s3_bucket.processed_bucket.bucket
    "--PATH_KEY"      = "clientes"
    "--TempDir"       = "s3://${aws_s3_bucket.service_bucket.bucket}/temporary/"
  }

  max_capacity = 0.0625
}

#glue job transacciones

resource "aws_glue_job" "raw_to_processed_job_transacciones" {
  name     = "cce-transacciones-raw-to-processed-etl1"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "pythonshell"
    python_version  = "3.9"
    script_location = "s3://${aws_s3_bucket.service_bucket.bucket}/scripts/raw_to_processed.py"
  }

  default_arguments = {
    "--INPUT_BUCKET"  = aws_s3_bucket.raw_bucket.bucket
    "--OUTPUT_BUCKET" = aws_s3_bucket.processed_bucket.bucket
    "--PATH_KEY"      = "transacciones"
    "--TempDir"       = "s3://${aws_s3_bucket.service_bucket.bucket}/temporary/"
  }

  max_capacity = 0.0625
}

#db en el catalogo para processed

resource "aws_glue_catalog_database" "processed_database" {
  name = "cce_datalake_processed_db"
}

#crawler para el bucket processed

resource "aws_glue_crawler" "processed_crawler" {
  name          = "cce-processed-crawler"
  database_name = aws_glue_catalog_database.processed_database.name
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.processed_bucket.bucket}/"
  }

  table_prefix = "processed_"
}

#subir script run_glue_job a s3

resource "aws_s3_object" "run_glue_job_script" {
  bucket = aws_s3_bucket.service_bucket.id
  key    = "scripts/run_glue_job.zip"
  source = "run_glue_job.zip"
  acl    = "private"

  etag = filemd5("run_glue_job.zip")
}

#lambda que consume el script y ejecuta los jobs

resource "aws_lambda_function" "run_glue_job_lambda" {
  function_name = "run-glue-job"
  role          = aws_iam_role.lambda_role.arn
  handler       = "run_glue_job.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
  memory_size   = 128

  s3_bucket = aws_s3_bucket.service_bucket.id
  s3_key    = "scripts/run_glue_job.zip"

  source_code_hash = filebase64sha256("run_glue_job.zip")
}

#subir script execute_athena_querys a s3

resource "aws_s3_object" "execute_athena_querys_script" {
  bucket = aws_s3_bucket.service_bucket.id
  key    = "scripts/execute_athena_querys.zip"
  source = "execute_athena_querys.zip"
  acl    = "private"

  etag = filemd5("execute_athena_querys.zip")
}

#lambda que consume el script y ejecuta consultas en athena con python

resource "aws_lambda_function" "execute_athena_querys_lambda" {
  function_name = "execute_athena_querys"
  role          = aws_iam_role.lambda_role.arn
  handler       = "execute_athena_querys.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
  memory_size   = 128

  s3_bucket = aws_s3_bucket.service_bucket.id
  s3_key    = "scripts/execute_athena_querys.zip"

  source_code_hash = filebase64sha256("execute_athena_querys.zip")
}

#role necesario para las lambdas

resource "aws_iam_role" "lambda_role" {
  name = "LambdaGlueExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "scheduler.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_glue_access" {
  name       = "LambdaGlueAccessPolicy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "athena_s3_access" {
  name = "AthenaS3AccessPolicy"
  role = aws_iam_role.lambda_role.name

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:*"
        ],
        "Resource" : [
          "arn:aws:s3:::cce-datalake-analytics",
          "arn:aws:s3:::cce-datalake-analytics/*",
          "arn:aws:s3:::cce-datalake-processed",
          "arn:aws:s3:::cce-datalake-processed/*",
          "arn:aws:s3:::cce-datalake-service",
          "arn:aws:s3:::cce-datalake-service/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:GetPartitions"
        ],
        "Resource" : [
          "arn:aws:glue:us-east-1:913524903676:catalog",
          "arn:aws:glue:us-east-1:913524903676:database/cce-datalake-processed-db",
          "arn:aws:glue:us-east-1:913524903676:table/cce-datalake-processed-db/*"
        ]
      }
    ]
  })
}

#role para el scheduler

resource "aws_iam_role" "scheduler_invoke_lambda_role" {
  name = "EventBridgeSchedulerInvokeLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "scheduler.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

#politica para invocar la lambda desde eventbridge

resource "aws_iam_policy" "scheduler_invoke_lambda_policy" {
  name = "SchedulerInvokeLambdaPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        Resource = aws_lambda_function.run_glue_job_lambda.arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "scheduler_invoke_lambda_policy_attachment" {
  name       = "SchedulerInvokeLambdaPolicyAttachment"
  roles      = [aws_iam_role.scheduler_invoke_lambda_role.name]
  policy_arn = aws_iam_policy.scheduler_invoke_lambda_policy.arn
}

#scheduler para invocar la lambda y correr los jobs

resource "aws_scheduler_schedule" "glue_job_scheduler" {
  name                = "run-glue-job-scheduler"
  schedule_expression = "cron(0 11 * * ? *)"
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.run_glue_job_lambda.arn
    role_arn = aws_iam_role.scheduler_invoke_lambda_role.arn
    input = jsonencode({
      "jobs" : [
        "cce-proveedores-raw-to-processed-etl1",
        "cce-clientes-raw-to-processed-etl1",
        "cce-transacciones-raw-to-processed-etl1"
      ]
    })
  }
}
