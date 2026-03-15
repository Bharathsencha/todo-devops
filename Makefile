# ─────────────────────────────────────────────
#  Todo DevOps Project
#  Usage: make <target>
# ─────────────────────────────────────────────

NAMESPACE   = todo-app
BACKEND_IMG = todo-backend
FRONTEND_IMG= todo-frontend
JENKINS_WAR = $(HOME)/jenkins.war
JENKINS_PORT= 9090

.PHONY: all setup run stop clean restart status logs help

# Default target
all: help

# ── Full setup (run once ever) ──────────────────
setup:
	@echo ""
	@echo "==> Starting Minikube..."
	minikube start --driver=docker --memory=3000 --cpus=2
	@echo ""
	@echo "==> Building Docker images inside Minikube..."
	eval $$(minikube docker-env) && \
		docker build -t $(BACKEND_IMG):latest . && \
		docker build -t $(FRONTEND_IMG):latest ./frontend
	@echo ""
	@echo "==> Running Terraform (namespace + Helm deploy)..."
	cd terraform && terraform init -input=false && terraform apply -auto-approve
	@echo ""
	@echo "==> Done! Run 'make open' to open the app."

# ── Day-to-day: start everything ───────────────
run:
	@echo ""
	@echo "==> Starting Minikube..."
	minikube start --driver=docker --memory=3000 --cpus=2
	@echo ""
	@echo "==> Starting Jenkins..."
	@if pgrep -f "jenkins.war" > /dev/null; then \
		echo "    Jenkins already running."; \
	else \
		java -jar $(JENKINS_WAR) --httpPort=$(JENKINS_PORT) > /tmp/jenkins.log 2>&1 & \
		echo "    Jenkins starting at http://localhost:$(JENKINS_PORT) ..."; \
		sleep 8; \
	fi
	@echo ""
	@echo "==> Checking pods..."
	kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "==> All systems up!"
	@echo "    App:     run 'make open'"
	@echo "    Jenkins: http://localhost:$(JENKINS_PORT)"

# ── Open the app in browser ─────────────────────
open:
	minikube service todo-frontend-service -n $(NAMESPACE)

# ── Redeploy after code changes ─────────────────
deploy:
	@echo ""
	@echo "==> Rebuilding images..."
	eval $$(minikube docker-env) && \
		docker build -t $(BACKEND_IMG):latest . && \
		docker build -t $(FRONTEND_IMG):latest ./frontend
	@echo ""
	@echo "==> Restarting pods..."
	kubectl rollout restart deployment/todo-backend  -n $(NAMESPACE)
	kubectl rollout restart deployment/todo-frontend -n $(NAMESPACE)
	kubectl rollout status  deployment/todo-backend  -n $(NAMESPACE) --timeout=90s
	kubectl rollout status  deployment/todo-frontend -n $(NAMESPACE) --timeout=90s
	@echo ""
	@echo "==> Deployed! Run 'make open' to view."

# ── Show status of everything ───────────────────
status:
	@echo ""
	@echo "==> Minikube:"
	minikube status
	@echo ""
	@echo "==> Pods:"
	kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "==> Services:"
	kubectl get services -n $(NAMESPACE)
	@echo ""
	@echo "==> Deployments:"
	kubectl get deployments -n $(NAMESPACE)

# ── Show logs ───────────────────────────────────
logs:
	@echo "==> Backend logs:"
	kubectl logs -n $(NAMESPACE) deployment/todo-backend --tail=30
	@echo ""
	@echo "==> Frontend logs:"
	kubectl logs -n $(NAMESPACE) deployment/todo-frontend --tail=20

# ── Stop everything ─────────────────────────────
stop:
	@echo "==> Stopping Jenkins..."
	@pkill -f "jenkins.war" && echo "    Jenkins stopped." || echo "    Jenkins was not running."
	@echo "==> Stopping Minikube..."
	minikube stop
	@echo "==> All stopped."

# ── Destroy everything (nuclear option) ─────────
clean:
	@echo "==> Destroying Terraform resources..."
	cd terraform && terraform destroy -auto-approve || true
	@echo "==> Deleting Minikube cluster..."
	minikube delete
	@echo "==> Clean done. Run 'make setup' to start fresh."

# ── Restart pods only ───────────────────────────
restart:
	kubectl rollout restart deployment/todo-backend  -n $(NAMESPACE)
	kubectl rollout restart deployment/todo-frontend -n $(NAMESPACE)
	@echo "==> Pods restarting..."

# ── Help ────────────────────────────────────────
help:
	@echo ""
	@echo "  Todo DevOps Project — available commands:"
	@echo ""
	@echo "  make setup    — first time setup (Minikube + Docker + Terraform)"
	@echo "  make run      — start Minikube + Jenkins (daily use)"
	@echo "  make open     — open the app in browser"
	@echo "  make deploy   — rebuild images and redeploy to K8s"
	@echo "  make status   — show pods, services, deployments"
	@echo "  make logs     — tail logs from backend and frontend"
	@echo "  make restart  — restart pods without rebuilding"
	@echo "  make stop     — stop Minikube and Jenkins"
	@echo "  make clean    — destroy everything and start fresh"
	@echo ""
