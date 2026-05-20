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
                    # Prefer building inside Minikube's Docker daemon when available
                    if command -v minikube >/dev/null 2>&1; then
                        if minikube status >/dev/null 2>&1; then
                            echo "Using Minikube's Docker daemon"
                            eval $(minikube docker-env)
                        else
                            echo "Minikube is installed but not running; attempting host Docker build"
                        fi
                    else
                        echo "Minikube is not installed; attempting host Docker build"
                    fi

                    docker build -t ${BACKEND_IMAGE}:${IMAGE_TAG} -t ${BACKEND_IMAGE}:latest . || {
                        echo "Docker build failed. If this is a permissions error, ensure the Jenkins user can access the Docker socket or run 'scripts/jenkins-setup.sh' as your user to copy Minikube/Kube configs and add Jenkins to the docker group.";
                        exit 1;
                    }
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
