.PHONY: setup run clean clean_then_setup install_model uninstall_model init stop

# Include .env file
include ./config/.env
# Set default values (will be overridden by .env or shell exports)
HOST ?= localhost
PORT ?= 3000

# Default model if not specified
MODEL ?= qwen:0.5b

# all: setup run

clean_then_setup: clean setup

setup:
	@if [ ! -d "LibreChat" ]; then \
		echo "Cloning LibreChat repository..."; \
		git clone https://github.com/danny-avila/LibreChat.git; \
	else \
		echo "LibreChat directory already exists. Skipping clone."; \
	fi

	@if [ -z "$(ANTHROPIC_API_KEY)" ]; then \
		echo "Error: ANTHROPIC_API_KEY is not set. Please export it first."; \
		exit 1; \
	fi

	@echo "Copying configuration files..."
	cp ./config/.env.template ./config/.env
	# sed -i 's/ANTHROPIC_API_KEY=user_provided/ANTHROPIC_API_KEY=$(ANTHROPIC_API_KEY)/' ./config/.env  # For Linux
	sed -i '' 's/ANTHROPIC_API_KEY=user_provided/ANTHROPIC_API_KEY=$(ANTHROPIC_API_KEY)/' ./config/.env # For MacOS
	cp ./config/.env ./LibreChat/.env
	@echo ".env copied successfully."
	cp ./config/docker-compose.yml ./LibreChat/
	@echo "docker-compose.yml copied successfully."
	cp ./config/docker-compose.override.yml ./LibreChat/
	@echo "docker-compose.override.yml file copied successfully."
	cp ./config/librechat.yaml ./LibreChat/
	@echo "librechat.yaml file copied successfully."

init:
	@if [ -d "LibreChat" ]; then \
		cd LibreChat && \
		if docker compose ps --services --filter "status=running" 2>/dev/null | grep -q -E "api|meilisearch|mongodb|ollama|rag_api|vectordb"; then \
			echo "LibreChat services are already running. Skipping docker compose up."; \
			echo "Running services:"; \
			docker compose ps --services --filter "status=running" 2>/dev/null; \
		else \
			echo "Starting LibreChat services..."; \
			docker compose up -d; \
		fi; \
	else \
		echo "Error: LibreChat directory not found. Please run setup first."; \
		exit 1; \
	fi

	@echo "Installing LLMs on ollama..."
	$(MAKE) install_model  # Default model
	$(MAKE) install_model MODEL=llama2:7b
	# @cd LibreChat && docker exec -it ollama /bin/bash && ollama run qwen:0.5b && \bye

install_model:
	@if [ -d "LibreChat" ]; then \
		cd LibreChat && \
		if ! docker exec ollama ollama list | grep -q "$(MODEL)"; then \
			echo "Installing $(MODEL) model..."; \
			pwd; \
			docker exec ollama pwd; \
			docker exec ollama ollama pull $(MODEL); \
			while ! docker exec ollama ollama list | grep -q "$(MODEL)"; do \
				echo "Waiting for model to finish downloading..."; \
				sleep 10; \
			done; \
			echo "$(MODEL) model has been installed."; \
		else \
			echo "$(MODEL) model is already installed."; \
		fi; \
	else \
		echo "Error: LibreChat directory not found. Please run setup first."; \
		exit 1; \
	fi

uninstall_model:
	@if [ -d "LibreChat" ]; then \
		cd LibreChat && \
		if docker exec ollama ollama list | grep -q "$(MODEL)"; then \
			echo "Uninstalling $(MODEL) model..."; \
			docker exec ollama ollama rm $(MODEL); \
			while docker exec ollama ollama list | grep -q "$(MODEL)"; do \
				echo "Waiting for model to finish uninstalling..."; \
				sleep 5; \
			done; \
			echo "$(MODEL) model has been uninstalled."; \
		else \
			echo "$(MODEL) model is not installed."; \
		fi; \
	else \
		echo "Error: LibreChat directory not found. Please run setup first."; \
		exit 1; \
	fi

run:
	@cd LibreChat && docker compose up -d

stop:
	@cd project && docker compose down

clean:
	rm -rf LibreChat
	rm -f ./config/.env