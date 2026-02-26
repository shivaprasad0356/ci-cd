terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

# 1. S3 BUCKETS (App Hosting & Artifacts)
resource "aws_s3_bucket" "app_bucket" {
  bucket        = "app-deployment-2026" 
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "app_config" {
  bucket = aws_s3_bucket.app_bucket.id
  index_document { suffix = "index.html" }
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "pipeline-artifacts-2026"
  force_destroy = true
}

# 2. IAM ROLES (Permissions)
resource "aws_iam_role" "pipeline_role" {
  name = "pipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "pipeline_policy" {
  role = aws_iam_role.pipeline_role.name
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{ Action = "*", Resource = "*", Effect = "Allow" }] # Note: Narrow this down for Production
  })
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{ Action = "*", Resource = "*", Effect = "Allow" }]
  })
}

# 3. CODEBUILD (Build & Test Stage)
resource "aws_codebuild_project" "build_test" {
  name          = "Build-Test"
  service_role  = aws_iam_role.codebuild_role.arn
  artifacts     { type = "CODEPIPELINE" }
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

# 4. THE PIPELINE (V2 - Automated Release Trigger)
resource "aws_codepipeline" "pipeline" {
  name          = "Fully-Automated-Release-Pipeline"
  pipeline_type = "V2" # Enables advanced triggers
  role_arn      = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # THIS AUTOMATES THE "RELEASE CHANGE" REQUIREMENT
  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        tags { includes = ["v*"] } # ONLY starts if you tag code v1.0, v2.0, etc.
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
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = "arn:aws:codestar-connections:us-east-1:877520723193:connection/657f0d88-5a56-40b8-8032-05edf774ec73"
        FullRepositoryId = "shivaprasad0356/ci-cd"
        BranchName       = "main"
        DetectChanges    = false
      }
    }
  }

  stage {
    name = "Build_And_Test"
    action {
      name             = "BuildAndTest"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration    = { ProjectName = aws_codebuild_project.build_test.name }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "DeployToS3"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      version         = "1"
      input_artifacts = ["build_output"]
      configuration = {
        BucketName = aws_s3_bucket.app_bucket.bucket
        Extract    = "true"
      }
    }
  }
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.app_config.website_endpoint
}
