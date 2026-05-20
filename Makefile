NAMESPACE   = todo-app
BACKEND_IMG = todo-backend
JENKINS_WAR = $(HOME)/jenkins.war
JENKINS_PORT= 8080
BACKEND_LOCAL_PORT = 8081

.PHONY: all setup run stop clean restart status logs help check-prereqs

# Default target
all: help

check-prereqs:
	@missing_tools=""; \
	for tool in minikube kubectl helm docker mvn; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			missing_tools="$$missing_tools $$tool"; \
		fi; \
	done; \
	if [ -n "$$missing_tools" ]; then \
		echo "Missing required tools:$$missing_tools"; \
		echo "Install them before running make setup. See README.md for the setup commands."; \
		exit 1; \
	fi; \
	if ! docker info >/dev/null 2>&1; then \
		echo "Docker is installed, but the daemon is not reachable from this shell."; \
		echo "Fix Docker access first, for example: sudo usermod -aG docker \$$USER && newgrp docker"; \
		exit 1; \
	fi

setup:
	@$(MAKE) --no-print-directory check-prereqs
	@echo ""
	@echo "==> Starting Minikube..."
	minikube start --driver=docker --memory=3000 --cpus=2
	@echo ""
	@echo "==> Building Maven project..."
	mvn clean package -DskipTests -q
	@echo "==> Building Docker image on host and loading it into Minikube..."
	eval $$(minikube docker-env -u) && \
		docker build -t $(BACKEND_IMG):latest . && \
		minikube image load $(BACKEND_IMG):latest
	@echo ""
	@echo "==> Deploying with Helm..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(NAMESPACE) ./helm/todo-app -n $(NAMESPACE)
	kubectl rollout status deployment/todo-backend -n $(NAMESPACE) --timeout=180s
	@echo ""
	@echo "==> Done! Run 'make open' to open the app."

run:
	@$(MAKE) --no-print-directory check-prereqs
	@echo ""
	@echo "==> Starting Minikube..."
	minikube start --driver=docker --memory=3000 --cpus=2
	@echo ""
	@echo "==> Starting Jenkins..."
	@if ss -ltn | grep -q :$(JENKINS_PORT); then \
		echo "    Jenkins already running."; \
	else \
		java -jar $(JENKINS_WAR) --httpPort=$(JENKINS_PORT) > /tmp/jenkins.log 2>&1 & \
		echo "    Jenkins starting at http://localhost:$(JENKINS_PORT) ..."; \
		sleep 8; \
	fi
	@echo ""
	@echo "==> Checking pods..."
	kubectl get pods -n $(NAMESPACE) 2>/dev/null || echo "    No pods yet — run 'make setup' first"
	@echo ""
	@echo "==> All systems up!"
	@echo "    App:     run 'make open'"
	@echo "    Jenkins: http://localhost:$(JENKINS_PORT)"
open:
	@echo "==> Ensuring Jenkins is running..."
	@if ss -ltn | grep -q :$(JENKINS_PORT); then \
		echo "    Jenkins already running."; \
	else \
		if [ -f $(JENKINS_WAR) ]; then \
			echo "    Starting Jenkins from $(JENKINS_WAR)"; \
			java -jar $(JENKINS_WAR) --httpPort=$(JENKINS_PORT) > /tmp/jenkins.log 2>&1 & \
			sleep 5; \
		else \
			echo "    Jenkins not running. Start it with 'make run' or 'sudo systemctl start jenkins'"; \
		fi; \
	fi
	@echo "==> Opening Jenkins..."
	-xdg-open http://localhost:$(JENKINS_PORT) >/dev/null 2>&1 &
	@echo "==> Opening Backend Tunnel & Client..."
	-pkill -f "kubectl port-forward.*$(BACKEND_LOCAL_PORT):8080" || true
	kubectl port-forward -n $(NAMESPACE) svc/todo-backend-service $(BACKEND_LOCAL_PORT):8080 >/dev/null 2>&1 &
	@echo "==> Waiting for backend API to be available on localhost:$(BACKEND_LOCAL_PORT)..."
	@until curl -s -f -o /dev/null "http://127.0.0.1:$(BACKEND_LOCAL_PORT)/todos/health"; do sleep 1; done
	@echo "==> Connected! Launching JavaFX..."
	mvn exec:java -Dexec.mainClass="com.todo.client.TodoClientLauncher"

deploy:
	@$(MAKE) --no-print-directory check-prereqs
	@echo ""
	@echo "==> Rebuilding images..."
	mvn clean package -DskipTests -q
	eval $$(minikube docker-env -u) && \
		docker build -t $(BACKEND_IMG):latest . && \
		minikube image load $(BACKEND_IMG):latest
	@echo ""
	@echo "==> Deploying changes with Helm..."
	helm upgrade --install $(NAMESPACE) ./helm/todo-app -n $(NAMESPACE)
	kubectl rollout status  deployment/todo-backend  -n $(NAMESPACE) --timeout=180s
	@echo ""
	@echo "==> Deployed! Run 'make open' to view."

status:
	@$(MAKE) --no-print-directory check-prereqs
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

logs:
	@$(MAKE) --no-print-directory check-prereqs
	@echo "==> Backend logs:"
	kubectl logs -n $(NAMESPACE) deployment/todo-backend --tail=50

stop:
	@$(MAKE) --no-print-directory check-prereqs
	@echo "==> Stopping Jenkins..."
	@kill $$(lsof -t -i:$(JENKINS_PORT)) 2>/dev/null && echo "    Jenkins stopped." || echo "    Jenkins was not running."
	@echo "==> Stopping Port-Forward..."
	-pkill -f "kubectl port-forward.*$(BACKEND_LOCAL_PORT):8080" || true
	@echo "==> Stopping Minikube..."
	minikube stop
	@echo "==> All stopped."

clean:
	@$(MAKE) --no-print-directory check-prereqs
	@echo "==> Deleting Minikube cluster..."
	minikube delete
	@echo "==> Clean done. Run 'make setup' to start fresh."

restart:
	@$(MAKE) --no-print-directory check-prereqs
	kubectl rollout restart deployment/todo-backend  -n $(NAMESPACE)
	kubectl rollout status  deployment/todo-backend  -n $(NAMESPACE) --timeout=90s
	@echo "==> Pods restarted and ready!"

help:
	@echo ""
	@echo "  Todo DevOps Project — available commands:"
	@echo ""
	@echo "  make setup    — first time setup (Minikube + Docker)"
	@echo "  make run      — start everything (Minikube + Jenkins + pods)"
	@echo "  make open     — open the app in browser"
	@echo "  make deploy   — rebuild images and redeploy to K8s"
	@echo "  make status   — show pods, services, deployments"
	@echo "  make logs     — tail logs from backend and frontend"
	@echo "  make restart  — restart pods without rebuilding"
	@echo "  make stop     — stop Minikube and Jenkins"
	@echo "  make clean    — destroy everything and start fresh"
	@echo ""
