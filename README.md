# Todo DevOps Project
## Jenkins + Maven + Docker + Kubernetes + Terraform

### Quick guide :

```bash
cd ~/Desktop/devops
```
```bash
make run      # start everything (Minikube + Jenkins)
```
```bash
make open     # open the app in browser
```
```bash
make status   # check pods are healthy
```
```bash
make deploy   # after you change code
```
```bash
make stop     # when done for the day
```
---

## Step 1 — Create the project folder structure

Run this entire block in your terminal:

```bash
mkdir -p ~/todo-devops/{src/main/{java/com/todo/{controller,model},resources},frontend,helm/todo-app/templates,terraform}
cd ~/todo-devops
```

Then copy each file from Claude's output into the correct path.

---

## Step 2 — Install all required tools

### Java 17
```bash
sudo apt update
sudo apt install -y openjdk-17-jdk
java -version
```

### Maven
```bash
sudo apt install -y maven
mvn -version
```

### Docker
```bash
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
newgrp docker
docker --version
```

### Minikube
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube version
```

### kubectl
```bash
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl
kubectl version --client
```

### Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### Terraform
```bash
sudo apt install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
terraform -version
```

### Jenkins
```bash
# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Get the initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

---

## Step 3 — Start Minikube

```bash
minikube start --driver=docker --memory=3000 --cpus=2
minikube status
```

---

## Step 4 — Test the app locally first (no K8s)

```bash
cd ~/todo-devops

# Build the JAR
mvn clean package

# Run the backend directly
java -jar target/todo-app.jar

# Open another terminal and test it
curl http://localhost:8080/todos
curl -X POST http://localhost:8080/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"My first todo"}'
curl http://localhost:8080/todos
```

---

## Step 5 — Test with Docker Compose (optional but recommended)

```bash
cd ~/todo-devops
docker-compose up --build

# Open browser: http://localhost:3000
# When done:
docker-compose down
```

---

## Step 6 — Build Docker images into Minikube

```bash
# Point your terminal's Docker at Minikube's internal Docker daemon
eval $(minikube docker-env)

# Build both images
docker build -t todo-backend:latest .
docker build -t todo-frontend:latest ./frontend

# Verify images are in Minikube
docker images | grep todo
```

---

## Step 7 — Run Terraform to create namespace + deploy via Helm

```bash
cd ~/todo-devops/terraform

# Download the Terraform providers
terraform init

# Preview what Terraform will do
terraform plan

# Apply it (creates namespace + deploys Helm chart)
terraform apply -auto-approve
```

---

## Step 8 — Check everything is running

```bash
# Check pods
kubectl get pods -n todo-app

# Check services
kubectl get services -n todo-app

# Check deployments
kubectl get deployments -n todo-app

# See pod logs (replace with your actual pod name)
kubectl logs -n todo-app deployment/todo-backend
```

---

## Step 9 — Open the app in browser

```bash
minikube service todo-frontend-service -n todo-app
```

This prints a URL and opens it automatically in your browser.

---

## Step 10 — Set up Jenkins pipeline

### 1. Open Jenkins
```
http://localhost:8080
```
Paste the password from Step 2. Install suggested plugins.

### 2. Give Jenkins access to Docker and kubectl

```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Copy your kube config so Jenkins can access Minikube
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube

# Copy minikube certs
sudo mkdir -p /var/lib/jenkins/.minikube
sudo cp -r ~/.minikube/profiles /var/lib/jenkins/.minikube/
sudo cp ~/.minikube/ca.crt /var/lib/jenkins/.minikube/
sudo chown -R jenkins:jenkins /var/lib/jenkins/.minikube
```

### 3. Create a pipeline in Jenkins

- Click **New Item**
- Name it `todo-devops`, choose **Pipeline**, click OK
- Scroll to **Pipeline** section
- Set **Definition** to `Pipeline script from SCM`
- Set **SCM** to `Git`
- Set **Repository URL** to your local path: `file:///home/YOUR_USERNAME/todo-devops`
- Set **Script Path** to `Jenkinsfile`
- Click **Save**

### 4. Initialize the folder as a git repo

```bash
cd ~/todo-devops
git init
git add .
git commit -m "initial commit"
```

### 5. Run the pipeline

- Click **Build Now** in Jenkins
- Watch each stage: Checkout → Maven → Docker → Terraform → Verify → Smoke Test

---

## Useful commands to remember

```bash
# See everything running in your namespace
kubectl get all -n todo-app

# Watch pods in real time
kubectl get pods -n todo-app -w

# Describe a pod (good for debugging)
kubectl describe pod -n todo-app <pod-name>

# See pod logs
kubectl logs -n todo-app deployment/todo-backend

# Restart a deployment (simulates a redeploy)
kubectl rollout restart deployment/todo-backend -n todo-app

# Destroy everything (Terraform tears it all down)
cd ~/todo-devops/terraform
terraform destroy -auto-approve

# Stop Minikube
minikube stop

# Delete Minikube entirely and start fresh
minikube delete
```

---

## Project folder structure (final)

```
todo-devops/
├── src/
│   └── main/
│       ├── java/com/todo/
│       │   ├── TodoApplication.java
│       │   ├── controller/TodoController.java
│       │   └── model/Todo.java
│       └── resources/
│           └── application.properties
├── frontend/
│   ├── index.html
│   ├── Dockerfile
│   └── nginx.conf
├── helm/
│   └── todo-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── backend.yaml
│           └── frontend.yaml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── Dockerfile
├── docker-compose.yml
├── Jenkinsfile
└── pom.xml
```
