variable "connection_arn" { type = string }

provider "aws" { region = "us-east-1" }

# S3 for App
resource "aws_s3_bucket" "app" {
  bucket        = "demo-app-${random_id.id.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "web" {
  bucket = aws_s3_bucket.app.id
  index_document {
    suffix = "index.html"
  }
}

# S3 for Pipeline Artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket        = "artifacts-${random_id.id.hex}"
  force_destroy = true
}

resource "random_id" "id" {
  byte_length = 4
}

# CodeBuild Project
resource "aws_codebuild_project" "build" {
  name          = "Build-Test"
  service_role  = aws_iam_role.role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# Pipeline V2 (Triggered by Release Tags)
resource "aws_codepipeline" "pipe" {
  name          = "Automated-Release-Pipeline"
  pipeline_type = "V2"
  role_arn      = aws_iam_role.role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        tags {
          includes = ["v*"]
        }
      }
    }
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["src"]
      configuration = {
        ConnectionArn    = var.connection_arn
        FullRepositoryId = "shivaprasad0356/ci-cd"
        BranchName       = "main"
        DetectChanges    = false
      }
    }
  }

  stage {
    name = "Build_And_Test"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["src"]
      output_artifacts = ["bin"]
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      version         = "1"
      input_artifacts = ["bin"]
      configuration = {
        BucketName = aws_s3_bucket.app.bucket
        Extract    = "true"
      }
    }
  }
}

# IAM Role 
resource "aws_iam_role" "role" {
  name = "automation-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = ["codepipeline.amazonaws.com", "codebuild.amazonaws.com"]
      }
    }]
  })
}

resource "aws_iam_role_policy" "policy" {
  role = aws_iam_role.role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "*",
      Resource = "*",
      Effect   = "Allow"
    }]
  })
}

output "app_url" {
  value = aws_s3_bucket_website_configuration.web.website_endpoint
}
