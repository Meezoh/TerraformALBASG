pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
    }

    stages {

        stage('Checkout') {
            steps {
                echo "Checking out repo"
                git branch: 'main', url: 'https://github.com/Meezoh/TerraformALBASG.git'
            }
        }

        stage('Bootstrap Backend') {
            steps {
                dir('environments') {
                    sh '''
                        terragrunt backend bootstrap -input=false
                    '''
                }
            }
        }

        stage('Init Backend') {
            steps {
                dir('environments') {
                    sh '''
                        terragrunt run-all init -input=false
                    '''
                }
            }
        }

        stage('Apply VPC') {
            steps {
                dir('environments/vpc') {
                    sh '''
                        terragrunt apply -input=false -auto-approve
                    '''
                }
            }
        }

        stage('Apply EC2 Fleet') {
            steps {
                dir('environments/ec2_fleet') {
                    sh '''
                        terragrunt apply -input=false -auto-approve
                    '''
                }
            }
        }

    }

    post {
        success {
            echo "Deployment successful"
        }
        failure {
            echo "Deployment failed"
        }
    }
}