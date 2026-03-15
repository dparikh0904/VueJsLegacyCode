#!/bin/bash

# Vue Argon Design System - Docker + EC2 Deployment Script
# Usage:
#   Local machine: ./deploy-ec2-docker.sh        -> builds & pushes image to ECR
#   EC2 instance:  ./deploy-ec2-docker.sh --run   -> pulls image from ECR & runs
#   EC2 instance:  ./deploy-ec2-docker.sh --git   -> git pull + docker build on EC2 (no ECR needed)

# ── MODE: --git (FIRST — no AWS credentials required) ────────────────────────
if [ "$1" = "--git" ]; then
    set -e
    REPO_URL="${REPO_URL:-https://github.com/dparikh0904/VueJsLegacyCode.git}"
    APP_DIR="${APP_DIR:-$HOME/VueJsLegacyCode}"
    ECR_REPO="vue-argon-design-system"
    IMAGE_TAG="${IMAGE_TAG:-latest}"
    CONTAINER_NAME="vue-argon"
    HOST_PORT="${HOST_PORT:-8080}"

    echo "=========================================="
    echo "  Vue Argon - Git + Docker Deploy"
    echo "  (no AWS credentials needed)"
    echo "=========================================="

    echo ""
    echo "📦 Installing Docker and Git (if not present)..."

    if ! command -v docker &> /dev/null; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [ "$ID" = "amzn" ]; then
                sudo yum update -y
                sudo yum install -y docker git
            elif [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
                sudo apt-get update -y
                sudo apt-get install -y docker.io git
            fi
        fi
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker "$USER"
    fi

    echo "✓ Docker : $(docker --version)"
    echo "✓ Git    : $(git --version)"

    echo ""
    if [ -d "$APP_DIR/.git" ]; then
        echo "📥 Pulling latest code..."
        git -C "$APP_DIR" pull
    else
        echo "📥 Cloning repository..."
        git clone "$REPO_URL" "$APP_DIR"
    fi

    echo ""
    echo "🔨 Building Docker image on EC2..."
    sudo docker build -t "${ECR_REPO}:${IMAGE_TAG}" "$APP_DIR"

    echo ""
    echo "🛑 Stopping existing container (if any)..."
    sudo docker stop "$CONTAINER_NAME" 2>/dev/null || true
    sudo docker rm   "$CONTAINER_NAME" 2>/dev/null || true

    echo ""
    echo "🚀 Starting container..."
    sudo docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${HOST_PORT}:80" \
        "${ECR_REPO}:${IMAGE_TAG}"

    echo ""
    echo "=========================================="
    echo "  ✅ Container running (built from Git)!"
    echo "=========================================="
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")
    echo "  URL: http://${PUBLIC_IP}:${HOST_PORT}"
    echo ""
    echo "  Useful commands:"
    echo "    sudo docker ps                        - Check container status"
    echo "    sudo docker logs $CONTAINER_NAME       - View logs"
    echo "    sudo docker restart $CONTAINER_NAME    - Restart"
    echo "    sudo docker stop $CONTAINER_NAME       - Stop"
    echo "=========================================="
    exit 0
fi

set -e

# ─── Configuration (ECR modes only) ────────────────────────────────────────────
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPO="vue-argon-design-system"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="vue-argon"
HOST_PORT="${HOST_PORT:-8080}"
CONTAINER_PORT=80
# ───────────────────────────────────────────────────────────────────────────────

echo "=========================================="
echo "  Vue Argon - Docker/EC2 Deployment"
echo "=========================================="

# ── MODE: --run (run on EC2) ──────────────────────────────────────────────────
if [ "$1" = "--run" ]; then
    AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
    ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
    echo "  ECR URI   : $ECR_URI:$IMAGE_TAG"
    echo "  Region    : $AWS_REGION"
    echo "=========================================="
    echo ""
    echo "📦 Installing Docker (if not present)..."

    if ! command -v docker &> /dev/null; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [ "$ID" = "amzn" ]; then
                sudo yum update -y
                sudo yum install -y docker
            elif [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
                sudo apt-get update -y
                sudo apt-get install -y docker.io
            fi
        fi
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker "$USER"
    fi

    echo "✓ Docker: $(docker --version)"

    echo ""
    echo "🔑 Authenticating with ECR..."
    aws ecr get-login-password --region "$AWS_REGION" \
        | sudo docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    echo ""
    echo "📥 Pulling image from ECR..."
    sudo docker pull "${ECR_URI}:${IMAGE_TAG}"

    echo ""
    echo "🛑 Stopping existing container (if any)..."
    sudo docker stop "$CONTAINER_NAME" 2>/dev/null || true
    sudo docker rm   "$CONTAINER_NAME" 2>/dev/null || true

    echo ""
    echo "🚀 Starting container..."
    sudo docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${HOST_PORT}:${CONTAINER_PORT}" \
        "${ECR_URI}:${IMAGE_TAG}"

    echo ""
    echo "=========================================="
    echo "  ✅ Container running!"
    echo "=========================================="
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")
    echo "  URL: http://${PUBLIC_IP}:${HOST_PORT}"
    echo ""
    echo "  Useful commands:"
    echo "    sudo docker ps                  - Check container status"
    echo "    sudo docker logs $CONTAINER_NAME - View logs"
    echo "    sudo docker restart $CONTAINER_NAME - Restart"
    echo "    sudo docker stop $CONTAINER_NAME    - Stop"
    echo "=========================================="
    exit 0
fi

# ── MODE: --git (clone/pull repo on EC2, build & run there) ────────────────────
if [ "$1" = "--git" ]; then
    echo "  Mode      : git pull + docker build (no AWS credentials needed)"
    echo "=========================================="
    REPO_URL="${REPO_URL:-https://github.com/dparikh0904/VueJsLegacyCode.git}"
    APP_DIR="${APP_DIR:-$HOME/VueJsLegacyCode}"

    echo ""
    echo "📦 Installing Docker and Git (if not present)..."

    if ! command -v docker &> /dev/null; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [ "$ID" = "amzn" ]; then
                sudo yum update -y
                sudo yum install -y docker git
            elif [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
                sudo apt-get update -y
                sudo apt-get install -y docker.io git
            fi
        fi
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker "$USER"
    fi

    echo "✓ Docker : $(docker --version)"
    echo "✓ Git    : $(git --version)"

    echo ""
    if [ -d "$APP_DIR/.git" ]; then
        echo "📥 Pulling latest code..."
        git -C "$APP_DIR" pull
    else
        echo "📥 Cloning repository..."
        git clone "$REPO_URL" "$APP_DIR"
    fi

    echo ""
    echo "🔨 Building Docker image on EC2..."
    sudo docker build -t "${ECR_REPO}:${IMAGE_TAG}" "$APP_DIR"

    echo ""
    echo "🛑 Stopping existing container (if any)..."
    sudo docker stop "$CONTAINER_NAME" 2>/dev/null || true
    sudo docker rm   "$CONTAINER_NAME" 2>/dev/null || true

    echo ""
    echo "🚀 Starting container..."
    sudo docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${HOST_PORT}:${CONTAINER_PORT}" \
        "${ECR_REPO}:${IMAGE_TAG}"

    echo ""
    echo "=========================================="
    echo "  ✅ Container running (built from Git)!"
    echo "=========================================="
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")
    echo "  URL: http://${PUBLIC_IP}:${HOST_PORT}"
    echo ""
    echo "  Useful commands:"
    echo "    sudo docker ps                   - Check container status"
    echo "    sudo docker logs $CONTAINER_NAME  - View logs"
    echo "    sudo docker restart $CONTAINER_NAME - Restart"
    echo "    sudo docker stop $CONTAINER_NAME    - Stop"
    echo "=========================================="
    exit 0
fi

# ── MODE: default (build & push from local machine) ──────────────────────────
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
echo "  ECR URI   : $ECR_URI:$IMAGE_TAG"
echo "  Region    : $AWS_REGION"
echo "=========================================="

echo ""
echo "🔍 Checking prerequisites..."
command -v docker  &>/dev/null || { echo "❌ Docker not found. Install Docker Desktop first."; exit 1; }
command -v aws     &>/dev/null || { echo "❌ AWS CLI not found. Install from https://aws.amazon.com/cli/"; exit 1; }

echo ""
echo "📦 Creating ECR repository (if it doesn't exist)..."
aws ecr describe-repositories \
    --repository-names "$ECR_REPO" \
    --region "$AWS_REGION" &>/dev/null \
|| aws ecr create-repository \
    --repository-name "$ECR_REPO" \
    --region "$AWS_REGION" \
    --image-scanning-configuration scanOnPush=true

echo ""
echo "🔑 Authenticating with ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo ""
echo "🔨 Building Docker image..."
docker build -t "${ECR_REPO}:${IMAGE_TAG}" .

echo ""
echo "🏷️  Tagging image..."
docker tag "${ECR_REPO}:${IMAGE_TAG}" "${ECR_URI}:${IMAGE_TAG}"

echo ""
echo "📤 Pushing image to ECR..."
docker push "${ECR_URI}:${IMAGE_TAG}"

echo ""
echo "=========================================="
echo "  ✅ Image pushed to ECR!"
echo "=========================================="
echo ""
echo "  Image: ${ECR_URI}:${IMAGE_TAG}"
echo ""
echo "  ─── Next: Deploy to EC2 ───────────────"
echo "  1. SSH into your EC2 instance"
echo "  2. Copy this script to the instance:"
echo "       scp deploy-ec2-docker.sh ec2-user@<EC2_IP>:~/"
echo "  3. On the EC2 instance, set env vars and run:"
echo "       export AWS_REGION=$AWS_REGION"
echo "       export AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID"
echo "       chmod +x deploy-ec2-docker.sh"
echo "       ./deploy-ec2-docker.sh --run"
echo ""
echo "  ⚠️  EC2 IAM role needs: ecr:GetAuthorizationToken,"
echo "      ecr:BatchGetImage, ecr:GetDownloadUrlForLayer"
echo "  ⚠️  Security Group: open port ${HOST_PORT} inbound"
echo "=========================================="
