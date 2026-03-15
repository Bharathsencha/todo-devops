terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# Points to your local Minikube cluster
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "minikube"
  }
}

# Create the namespace
resource "kubernetes_namespace" "todo_app" {
  metadata {
    name = "todo-app"
    labels = {
      managed-by = "terraform"
      project    = "todo-devops"
    }
  }
}

# Deploy the Helm chart
resource "helm_release" "todo_app" {
  name       = "todo-app"
  chart      = "${path.module}/../helm/todo-app"
  namespace  = kubernetes_namespace.todo_app.metadata[0].name

  set {
    name  = "backend.tag"
    value = var.image_tag
  }

  set {
    name  = "frontend.tag"
    value = var.image_tag
  }

  depends_on = [kubernetes_namespace.todo_app]
}
