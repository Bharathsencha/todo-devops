output "namespace" {
  value = kubernetes_namespace.todo_app.metadata[0].name
}

output "app_url" {
  value = "Run: minikube service todo-frontend-service -n todo-app"
}
