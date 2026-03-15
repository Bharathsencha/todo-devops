pipeline {
    agent any

    environment {
        IMAGE_TAG = "build-${BUILD_NUMBER}"
        BACKEND_IMAGE  = "todo-backend"
        FRONTEND_IMAGE = "todo-frontend"
    }

    stages {

        stage('Checkout') {
            steps {
                echo "Checking out source code..."
                checkout scm
            }
        }

        stage('Build & Test (Maven)') {
            steps {
                echo "Building and testing with Maven..."
                sh 'mvn clean package -q'
                echo "Build successful. JAR created."
            }
            post {
                failure {
                    echo "Maven build failed! Fix compilation errors or failing tests."
                }
            }
        }

        stage('Docker Build') {
            steps {
                echo "Building Docker images..."
                // Load images directly into Minikube's Docker daemon
                sh '''
                    eval $(minikube docker-env)
                    docker build -t ${BACKEND_IMAGE}:${IMAGE_TAG}  -t ${BACKEND_IMAGE}:latest .
                    docker build -t ${FRONTEND_IMAGE}:${IMAGE_TAG} -t ${FRONTEND_IMAGE}:latest ./frontend
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                echo "Initialising Terraform..."
                dir('terraform') {
                    sh 'terraform init -input=false'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                echo "Applying infrastructure with Terraform..."
                dir('terraform') {
                    sh 'terraform apply -auto-approve -var="image_tag=${IMAGE_TAG}"'
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                echo "Waiting for pods to be ready..."
                sh '''
                    kubectl rollout status deployment/todo-backend  -n todo-app --timeout=90s
                    kubectl rollout status deployment/todo-frontend -n todo-app --timeout=90s
                '''
                echo "All pods are running!"
            }
        }

        stage('Smoke Test') {
            steps {
                echo "Running smoke test against backend health endpoint..."
                sh '''
                    kubectl exec -n todo-app deployment/todo-backend -- wget -qO- http://localhost:8080/todos/health
                    echo "Health check passed!"
                '''
            }
        }
    }

    post {
        success {
            echo """
            ============================================
            Deployment successful!
            Run: minikube service todo-frontend-service -n todo-app
            to open the app in your browser.
            ============================================
            """
        }
        failure {
            echo "Pipeline failed. Check the logs above for details."
        }
        always {
            echo "Pipeline finished. Build #${BUILD_NUMBER}"
        }
    }
}
