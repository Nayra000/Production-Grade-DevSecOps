pipeline {

    agent {
        kubernetes {
            label 'jenkins-agent'
        }
    }

    environment {
        AWS_REGION     = 'us-east-1'
        ECR_REPO       = 'myapp'
        IMAGE_TAG      = "${BUILD_NUMBER}.0.0"

        AWS_ACCOUNT_ID = "054892330771"

        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        IMAGE_FULL     = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
    }

    stages {

        stage('Clone Repo') {
            steps {
                git branch: 'main',
                url: 'https://github.com/Nayra000/demo_project.git'
            }
        }
        

        stage('SonarQube Analysis') {

            steps {

                container('sonar-scanner') {

                    withSonarQubeEnv('sonarqube') {

                        sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=myapp \
                        -Dsonar.sources=.
                        '''
                    }
                }
            }
        }


        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    script {
                        def qg = waitForQualityGate()

                        if (qg.status != 'OK') {
                            error "Pipeline aborted due to Quality Gate failure: ${qg.status}"
                        }
                    }
                }
            }
        }

        stage('Build & Push with Kaniko') {

            steps {

                container('kaniko') {

                    sh """
                    /kaniko/executor \
                      --context=dir://${WORKSPACE} \
                      --dockerfile=${WORKSPACE}/Dockerfile \
                      --destination=${IMAGE_FULL} \
                      --cache=true
                    """
                }
            }
        }
    }

    post {

        success {
            echo "Image pushed successfully: ${IMAGE_FULL}"
        }

        failure {
            echo "Pipeline failed."
        }

    }
}