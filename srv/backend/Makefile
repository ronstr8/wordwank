.PHONY: deps test clean run help

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

deps: ## Install CPAN dependencies
	cpanm --installdeps .

test: ## Run tests
	prove -lr t/

clean: ## Clean up temporary files
	rm -rf local/
	find . -name '*.bak' -delete
	find . -name '*~' -delete

run: ## Run the backend server (development mode)
	morbo script/wordwank

dev: deps ## Setup for development (install deps)
	@echo "Development environment ready!"

all: deps test ## Install dependencies and run tests (default)

.DEFAULT_GOAL := all
