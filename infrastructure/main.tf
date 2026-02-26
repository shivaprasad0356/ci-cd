# 1. Pipeline Resource with Tag Trigger
resource "aws_codepipeline" "automated_pipeline" {
  name          = "Professional-Release-Pipeline"
  pipeline_type = "V2" # Required for advanced triggers
  role_arn      = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # THIS IS THE PART THAT AUTOMATES TRIGGERING BY RELEASE
  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        tags {
          includes = ["v*"] # Only triggers if you push a tag like v1.0
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
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = "PASTE_YOUR_CODESTAR_CONNECTION_ARN"
        FullRepositoryId = "your-user/your-repo"
        BranchName       = "main"
        DetectChanges    = false # IMPORTANT: Disables auto-trigger on commit
      }
    }
  }

  # Build/Test and Deploy stages follow here...
}
