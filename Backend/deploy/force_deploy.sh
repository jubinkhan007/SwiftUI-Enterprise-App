#!/bin/bash
set -e

echo "🛑 Stopping Vapor..."
docker-compose down -v

echo "🧹 Clearing Docker build cache and old images to FORCE a clean rebuild..."
docker rmi backend_app:latest || true
docker builder prune -a -f || true

echo "🔄 Pulling latest code..."
git pull origin main

echo "🔨 Building Vapor from scratch (this will take 10-15 mins, please be patient)..."
docker-compose build --no-cache app

echo "🚀 Starting server..."
docker-compose up -d app

echo "✅ Deployment complete! Check the logs using: docker-compose logs -f app"
