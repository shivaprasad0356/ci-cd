# ci-cd

├── app/
│   ├── index.html       # Your website
│   └── package.json     # Automated test definitions
├── infrastructure/
│   └── main.tf          # Terraform: The Pipeline Infrastructure
└── buildspec.yml        # AWS CodeBuild: Build & Test Instructions
