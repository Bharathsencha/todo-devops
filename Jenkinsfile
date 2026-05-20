pipeline {
    agent any

    environment {
        IMAGE_TAG = "build-${BUILD_NUMBER}"
        BACKEND_IMAGE  = "todo-backend"
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
                sh '''
                    eval $(minikube docker-env)
                    docker build -t ${BACKEND_IMAGE}:${IMAGE_TAG} -t ${BACKEND_IMAGE}:latest .
                '''
            }
        }

        stage('Helm Deploy') {
            steps {
                echo "Deploying to Kubernetes via Helm..."
                sh '''
                    helm upgrade --install todo-app ./helm/todo-app \
                        --namespace todo-app \
                        --create-namespace \
                        --set backend.tag=${IMAGE_TAG}
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo "Waiting for pods to be ready..."
                sh '''
                    kubectl rollout status deployment/todo-backend  -n todo-app --timeout=180s
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
            Deployment successful!
            Run 'make open' to start the local client.
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
