.PHONY: help setup-target setup-source start-target start-source stop-all logs-target logs-source clean

help:
	@echo "CFS Migration Tool - Makefile Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make setup-target    - Setup target server configuration"
	@echo "  make setup-source    - Setup source server configuration"
	@echo ""
	@echo "Start/Stop:"
	@echo "  make start-target    - Start target server"
	@echo "  make start-source    - Start source server"
	@echo "  make stop-all        - Stop all services"
	@echo ""
	@echo "Monitor:"
	@echo "  make logs-target     - View target server logs"
	@echo "  make logs-source     - View source server logs"
	@echo "  make status          - Show all services status"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean           - Remove all containers and volumes"

setup-target:
	@./deploy.sh target setup

setup-source:
	@./deploy.sh source setup

start-target:
	@./deploy.sh target start

start-source:
	@./deploy.sh source start

stop-all:
	@cd target && docker-compose down || true
	@cd source && docker-compose down || true

logs-target:
	@./deploy.sh target logs

logs-source:
	@./deploy.sh source logs

status:
	@echo "=== Target Server ==="
	@cd target && docker-compose ps || echo "Not running"
	@echo ""
	@echo "=== Source Server ==="
	@cd source && docker-compose ps || echo "Not running"

clean:
	@echo "WARNING: This will remove all containers and volumes!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd target && docker-compose down -v || true; \
		cd ../source && docker-compose down -v || true; \
		echo "✓ Cleaned up"; \
	fi
