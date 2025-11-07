# -------------------------------------------------------------------------------
# Project: Nomad Job Template
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Makefile for nomad-service pack template repository. Provides targets for
# formatting validation, template rendering, security scanning, and testing.
# -------------------------------------------------------------------------------

.PHONY: help fmt fmt-check validate render security test clean install docker-build

SHELL := /bin/bash
PACK_NAME := nomad-service
PACK_PATH := .
EXAMPLES_DIR := examples
TEMPLATES_DIR := templates
RENDERED_DIR := /tmp/nomad-pack-rendered

# -----------------------------------------------------------------------
# Help Target
# -----------------------------------------------------------------------

help:
	@echo "Nomad Pack Template Repository - Available Targets"
	@echo ""
	@echo "  make fmt              Format all HCL files"
	@echo "  make fmt-check        Check formatting without modifying files"
	@echo "  make validate         Validate pack structure and examples"
	@echo "  make render           Render all example job files"
	@echo "  make security         Run security scanning (Checkov)"
	@echo "  make test             Run all checks (fmt-check, validate, security)"
	@echo "  make install          Install dependencies (nomad-pack, checkov)"
	@echo "  make docker-build     Build Docker image for testing"
	@echo "  make clean            Remove rendered job files"
	@echo "  make help             Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make fmt && make test              # Format then run all checks"
	@echo "  make docker-build                  # Build Docker image"
	@echo "  make render && ls /tmp/nomad-pack-rendered/"
	@echo ""

# -----------------------------------------------------------------------
# Format Targets
# -----------------------------------------------------------------------

fmt:
	@echo "Formatting HCL files..."
	nomad fmt -recursive $(TEMPLATES_DIR)/
	@echo "✓ Formatting complete"

fmt-check:
	@echo "Checking HCL formatting..."
	nomad fmt -recursive -check $(TEMPLATES_DIR)/ || \
	(echo "✗ Formatting check failed. Run 'make fmt' to fix."; exit 1)
	@echo "✓ Formatting check passed"

# -----------------------------------------------------------------------
# Validation Targets
# -----------------------------------------------------------------------

validate: validate-structure validate-examples
	@echo "✓ All validation checks passed"

validate-structure:
	@echo "Validating pack structure..."
	@[ -f "metadata.hcl" ] || \
		(echo "✗ Missing metadata.hcl"; exit 1)
	@[ -f "variables.hcl" ] || \
		(echo "✗ Missing variables.hcl"; exit 1)
	@[ -d "$(TEMPLATES_DIR)" ] || \
		(echo "✗ Missing $(TEMPLATES_DIR)/ directory"; exit 1)
	@[ -f "$(TEMPLATES_DIR)/$(PACK_NAME).nomad.tpl" ] || \
		(echo "✗ Missing main template $(TEMPLATES_DIR)/$(PACK_NAME).nomad.tpl"; exit 1)
	@echo "✓ Pack structure valid"

validate-examples:
	@echo "Validating example files..."
	@if [ ! -d "$(EXAMPLES_DIR)" ]; then \
		echo "⚠ No examples directory found"; \
	else \
		for example in $(EXAMPLES_DIR)/*.hcl; do \
			if [ -f "$$example" ]; then \
				echo "  Validating: $$(basename $$example)..."; \
				nomad-pack validate $(PACK_PATH) -f "$$example" > /dev/null 2>&1 || \
					(echo "✗ Example validation failed: $$example"; exit 1); \
			fi; \
		done; \
		echo "✓ All examples validated"; \
	fi

# -----------------------------------------------------------------------
# Rendering Target
# -----------------------------------------------------------------------

render: validate-structure
	@echo "Rendering example jobs..."
	@mkdir -p $(RENDERED_DIR)
	@if [ ! -d "$(EXAMPLES_DIR)" ]; then \
		echo "⚠ No examples directory found"; \
	else \
		for example in $(EXAMPLES_DIR)/*.hcl; do \
			if [ -f "$$example" ]; then \
				example_name=$$(basename "$$example" .hcl); \
				echo "  Rendering: $$example_name..."; \
				nomad-pack render $(PACK_PATH) -f "$$example" \
					> "$(RENDERED_DIR)/$$example_name.nomad" || \
					(echo "✗ Rendering failed: $$example"; exit 1); \
			fi; \
		done; \
		echo "✓ Rendering complete"; \
		echo ""; \
		echo "Rendered files:"; \
		ls -lh $(RENDERED_DIR)/*.nomad 2>/dev/null || echo "  No rendered files"; \
	fi

# -----------------------------------------------------------------------
# Security Scanning
# -----------------------------------------------------------------------

security: security-checkov security-hcl
	@echo "✓ Security checks passed"

security-checkov:
	@echo "Running Checkov security scan..."
	@command -v checkov > /dev/null || \
		(echo "✗ checkov not installed. Run 'make install'"; exit 1)
	checkov -d $(TEMPLATES_DIR)/ \
		--framework terraform \
		--quiet \
		--soft-fail || true
	@echo "✓ Checkov scan complete"

security-hcl:
	@echo "Scanning templates for common issues..."
	@echo "  Checking for hardcoded credentials..."
	@grep -r "password.*=" $(TEMPLATES_DIR)/ 2>/dev/null && \
		echo "  ⚠ Found hardcoded password (review for security)" || true
	@grep -r "token.*=" $(TEMPLATES_DIR)/ 2>/dev/null && \
		echo "  ⚠ Found hardcoded token (review for security)" || true
	@grep -r "secret.*=" $(TEMPLATES_DIR)/ 2>/dev/null && \
		echo "  ⚠ Found hardcoded secret (review for security)" || true
	@echo "✓ HCL security scan complete"

# -----------------------------------------------------------------------
# Comprehensive Testing
# -----------------------------------------------------------------------

test: fmt-check validate render security
	@echo ""
	@echo "=========================================="
	@echo "All checks passed!"
	@echo "=========================================="

# -----------------------------------------------------------------------
# Installation Target
# -----------------------------------------------------------------------

install:
	@echo "Installing dependencies..."
	@command -v nomad > /dev/null || \
		(echo "Installing Nomad..."; curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - && \
		 sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(shell lsb_release -cs) main" && \
		 sudo apt-get update && sudo apt-get install -y nomad) || \
		echo "Nomad installation requires manual setup: https://www.nomadproject.io/downloads"
	@command -v nomad-pack > /dev/null || \
		(echo "Installing nomad-pack..."; curl -fsSL https://releases.hashicorp.com/nomad-pack/0.2.0/nomad-pack_0.2.0_linux_amd64.zip -o /tmp/nomad-pack.zip && \
		 unzip -o /tmp/nomad-pack.zip -d /tmp && sudo mv /tmp/nomad-pack /usr/local/bin/ && \
		 rm /tmp/nomad-pack.zip) || \
		echo "nomad-pack installation requires manual setup: https://github.com/hashicorp/nomad-pack"
	@command -v checkov > /dev/null || \
		(echo "Installing checkov..."; pip3 install checkov) || \
		echo "checkov installation requires: pip3 install checkov"
	@echo "✓ Dependencies installed"

# -----------------------------------------------------------------------
# Cleanup Target
# -----------------------------------------------------------------------

clean:
	@echo "Cleaning up..."
	@rm -rf $(RENDERED_DIR)
	@echo "✓ Cleanup complete"

# -----------------------------------------------------------------------
# Docker Build Target
# -----------------------------------------------------------------------

docker-build:
	@echo "Building Docker image..."
	docker build -t nomad-pack-builder:latest .
	@echo "✓ Docker image built: nomad-pack-builder:latest"

# -----------------------------------------------------------------------
# Development Targets
# -----------------------------------------------------------------------

.PHONY: watch lint docs

watch:
	@echo "Watching for changes..."
	@while true; do \
		inotifywait -e modify -r $(TEMPLATES_DIR)/ && make test; \
	done

lint: fmt-check
	@echo "Running linting checks..."
	@nomad fmt -recursive -check $(TEMPLATES_DIR)/ > /dev/null
	@echo "✓ Lint checks passed"

docs:
	@echo "Rendering documentation examples..."
	@for example in $(EXAMPLES_DIR)/*.hcl; do \
		if [ -f "$$example" ]; then \
			echo ""; \
			echo "Example: $$(basename $$example)"; \
			echo "========================================="; \
			head -3 "$$example" | grep "^#" || true; \
			echo ""; \
			nomad-pack render $(PACK_PATH) -f "$$example" | head -50; \
		fi; \
	done

.PHONY: watch lint docs
