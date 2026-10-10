#!/bin/bash
set -e

KEY_PATH="$HOME/Downloads/taskbridge-key.pem"
EC2_HOST="ubuntu@13.60.35.78"
REMOTE_DIR="/var/www/taskbridge"

echo "=========================================="
echo "🚀 TaskBridge AWS EC2 One-Click Deployment"
echo "=========================================="

if [ ! -f "$KEY_PATH" ]; then
    echo "❌ Error: SSH key not found at $KEY_PATH"
    exit 1
fi

chmod 400 "$KEY_PATH" 2>/dev/null || true

echo "🔨 [1/5] Compiling and publishing self-contained Linux binary..."
dotnet publish backend.Api/backend.Api.csproj -c Release -r linux-x64 --self-contained true -o backend.Api/publish

echo "📦 [2/5] Creating deployment package..."
tar -czf /tmp/backend-update.tar.gz -C backend.Api/publish .

echo "📤 [3/5] Uploading release package to AWS EC2 ($EC2_HOST)..."
scp -o StrictHostKeyChecking=no -i "$KEY_PATH" /tmp/backend-update.tar.gz "$EC2_HOST":/tmp/

echo "🔄 [4/5] Deploying files and restarting systemd service on AWS..."
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$EC2_HOST" "
    sudo systemctl stop taskbridge &&
    sudo tar --overwrite -xzf /tmp/backend-update.tar.gz -C $REMOTE_DIR &&
    sudo chown -R ubuntu:ubuntu $REMOTE_DIR &&
    sudo systemctl start taskbridge &&
    rm -f /tmp/backend-update.tar.gz
"

echo "🧹 [5/5] Cleaning temporary build files..."
rm -f /tmp/backend-update.tar.gz
rm -rf backend.Api/publish

echo "🩺 Verifying live API health..."
sleep 2
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://13.60.35.78/api/providers || echo "000")

if [ "$STATUS" = "200" ]; then
    echo "=========================================="
    echo "🎉 SUCCESS: TaskBridge Backend is LIVE on AWS!"
    echo "🌐 API Base URL: http://13.60.35.78"
    echo "📚 Swagger Docs: http://13.60.35.78/swagger"
    echo "=========================================="
else
    echo "⚠️ Deployment finished with HTTP status $STATUS."
fi
