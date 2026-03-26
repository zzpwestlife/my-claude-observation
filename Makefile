.PHONY: help install start stop status logs clean test-session session-viewer

help: ## Show this help
	@echo "Claude Code Observation Project Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make install       - Run the interactive setup wizard"
	@echo "  make start         - Start the monitoring stack (Docker Compose)"
	@echo "  make stop          - Stop the monitoring stack"
	@echo "  make status        - View container status"
	@echo "  make logs          - View container logs"
	@echo "  make clean         - Stop containers and remove volumes (DELETES ALL DATA)"
	@echo "  make session-viewer- Start the Streamlit Session Viewer (http://localhost:8501)"

install: ## Run the interactive setup
	@./setup.sh

start: ## Start the monitoring stack
	@if [ ! -f .env ]; then \
		echo "Warning: .env not found. Running make install first..."; \
		./setup.sh; \
	fi
	docker compose up -d
	@echo "Monitoring stack started. Run 'make status' to check."

stop: ## Stop the monitoring stack
	docker compose stop

status: ## View container status
	docker compose ps

logs: ## View container logs
	docker compose logs -f

clean: ## Stop and remove containers and volumes
	@read -p "Are you sure you want to delete all data? [y/N] " ans && \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		docker compose down -v; \
		echo "All containers and volumes removed."; \
	else \
		echo "Aborted."; \
	fi

session-viewer: ## Start the Streamlit Session Viewer
	@echo "Starting Claude Code Session Viewer..."
	@echo "Access: http://localhost:8501"
	@echo "Press Ctrl+C to stop"
	@cd session-viewer && python3 -m streamlit run app.py
