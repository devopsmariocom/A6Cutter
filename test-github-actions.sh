#!/bin/bash

# Test script for GitHub Actions workflow using Docker
set -e

echo "🐳 Testing GitHub Actions workflow with Docker..."

# Build and run Docker container
docker build -f Dockerfile.test -t a6cutter-test .

# Run the test
docker run --rm a6cutter-test

echo "✅ Docker test completed!"

