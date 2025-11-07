# -------------------------------------------------------------------------------
# Project: Nomad Job Template
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Root Makefile for shared nomad-pack-builder Docker image. Handles building,
# security scanning (Checkov, Trivy), and local testing of the container.
# -------------------------------------------------------------------------------

.PHONY: help docker-build docker-checkov docker-trivy docker-trivy-image docker-test docker-run clean

SHELL := /bin/bash
IMAGE_NAME := nomad-pack-builder
IMAGE_TAG := latest
IMAGE_FULL := $(IMAGE_NAME):$(IMAGE_TAG)

# -----------------------------------------------------------------------
# Help Target
# -----------------------------------------------------------------------

help:
	@echo "Nomad Pack Registry - Docker Build Targets"
	@echo ""
	@echo "  make docker-build       Build Docker image"
	@echo "  make docker-checkov     Run Checkov security scan on Dockerfile"
	@echo "  make docker-trivy       Run Trivy scan on Dockerfile"
	@echo "  make docker-trivy-image Run Trivy scan on built image"
	@echo "  make docker-test        Run all checks (checkov, trivy, build, trivy-image)"
	@echo "  make docker-run         Run container interactively"
	@echo "  make clean              Remove Docker image"
	@echo "  make help               Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make docker-test                   # Build and scan everything"
	@echo "  make docker-run                    # Run container shell"
	@echo ""

# -----------------------------------------------------------------------
# Docker Build Target
# -----------------------------------------------------------------------

docker-build:
	@echo "Building Docker image..."
	docker build -t $(IMAGE_FULL) .
	@echo "✓ Docker image built: $(IMAGE_FULL)"
	@docker images $(IMAGE_NAME)

# -----------------------------------------------------------------------
# Security Scanning Targets
# -----------------------------------------------------------------------

docker-checkov:
	@echo "Running Checkov on Dockerfile..."
	@command -v checkov > /dev/null || \
		(echo "✗ checkov not installed. Install with: pip3 install checkov"; exit 1)
	checkov -f Dockerfile \
		--framework dockerfile \
		--quiet \
		--soft-fail || true
	@echo "✓ Checkov scan complete"

docker-trivy:
	@echo "Scanning Dockerfile with Trivy..."
	@command -v trivy > /dev/null || \
		(echo "✗ trivy not installed. Install from: https://github.com/aquasecurity/trivy"; exit 1)
	trivy config Dockerfile --severity HIGH,CRITICAL --exit-code 0 || true
	@echo "✓ Trivy config scan complete"

docker-trivy-image: docker-build
	@echo "Scanning Docker image with Trivy..."
	@command -v trivy > /dev/null || \
		(echo "✗ trivy not installed. Install from: https://github.com/aquasecurity/trivy"; exit 1)
	trivy image $(IMAGE_FULL) --severity HIGH,CRITICAL --exit-code 0 || true
	@echo "✓ Trivy image scan complete"

# -----------------------------------------------------------------------
# Comprehensive Testing
# -----------------------------------------------------------------------

docker-test: docker-checkov docker-trivy docker-build docker-trivy-image
	@echo ""
	@echo "=========================================="
	@echo "Docker image ready for testing"
	@echo "Image: $(IMAGE_FULL)"
	@echo "=========================================="
	@echo ""
	@echo "To run tests in pack:"
	@echo "  cd nomad-service && make test"
	@echo ""

# -----------------------------------------------------------------------
# Docker Runtime Target
# -----------------------------------------------------------------------

docker-run: docker-build
	@echo "Running container..."
	docker run --rm -it \
		-v $$(pwd):/workspace \
		--workdir /workspace \
		$(IMAGE_FULL) \
		/bin/bash

# -----------------------------------------------------------------------
# Cleanup Target
# -----------------------------------------------------------------------

clean:
	@echo "Cleaning up Docker image..."
	docker rmi -f $(IMAGE_FULL) 2>/dev/null || true
	@echo "✓ Cleanup complete"
