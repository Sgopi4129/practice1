pipeline {
    agent any

    environment {
        // Define environment variables (e.g., GitHub repo, Terraform, etc.)
        GITHUB_REPO = 'https://github.com/your-username/your-repo.git'
        TERRAFORM_DIR = 'terraform'  // Path to your Terraform files
        AWS_CREDENTIALS = 'aws-credentials-id'  // AWS credentials stored in Jenkins
        SSH_CREDENTIALS = 'ec2-ssh-credentials'  // SSH credentials for EC2 instance
        SONARQUBE_CREDENTIALS = 'sonarqube-auth-token'  // Your SonarQube authentication token
    }

    stages {
        stage('Checkout Code from GitHub') {
            steps {
                script {
                    // Checkout the source code from GitHub repository
                    git url: GITHUB_REPO, branch: 'main'
                }
            }
        }

        stage('Static Code Analysis') {
            steps {
                script {
                    // Run SonarQube static code analysis
                    withSonarQubeEnv('SonarQube') {
                        sh 'sonar-scanner -Dsonar.projectKey=your-project-key -Dsonar.sources=.'
                    }
                }
            }
        }

        stage('Quality Gate Check') {
            steps {
                script {
                    // Wait for SonarQube analysis to complete and check if the quality gate passed
                    timeout(time: 10, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
            }
        }

        stage('Terraform Provisioning') {
            steps {
                script {
                    // Execute Terraform script to provision infrastructure (VPC, EC2, API Gateway)
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: AWS_CREDENTIALS]]) {
                        dir(TERRAFORM_DIR) {
                            sh 'terraform init'
                            sh 'terraform apply -auto-approve'
                        }
                    }
                }
            }
        }

        stage('Deployment & Load Balancing') {
            steps {
                script {
                    // SSH into EC2 and start the FastAPI application
                    withCredentials([sshUserPrivateKey(credentialsId: SSH_CREDENTIALS, keyFileVariable: 'EC2_SSH_KEY')]) {
                        sh """
                            ssh -i \${EC2_SSH_KEY} ec2-user@<EC2_PUBLIC_IP> 'cd /path/to/fastapi && uvicorn main:app --host 0.0.0.0 --port 8000 --reload'
                        """
                    }

                    // Configure Elastic Load Balancer for controlling traffic
                    sh """
                        aws elbv2 create-load-balancer --name my-load-balancer --subnets subnet-xxxxx subnet-yyyyy --security-groups sg-xxxxxx --scheme internet-facing --load-balancer-type application
                        aws elbv2 create-target-group --name my-target-group --protocol HTTP --port 8000 --vpc-id vpc-xxxxxx
                        aws elbv2 register-targets --target-group-arn <target-group-arn> --targets Id=<EC2_INSTANCE_ID>
                        aws elbv2 create-listener --load-balancer-arn <load-balancer-arn> --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=<target-group-arn>
                    """
                }
            }
        }
    }

    post {
        always {
            // Clean up or post-pipeline actions
            cleanWs()  // Clean up the workspace after the pipeline run
        }
    }
}
