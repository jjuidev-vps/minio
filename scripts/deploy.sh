#!/usr/bin/env bash
set -euo pipefail

#
# Script dùng để deploy lên môi trường develop|production
# Script chỉ có thể chạy ở branch deploy-develop|deploy-production
# Nếu git current branch có code change thì script tự commit và push, ngược lại chỉ push.
#
# Script sẽ build images (Dockerfile) và push lên Docker hub (cần chạy docker và credentials)
# Sau push code lên deploy-develop|deploy-production để trigger deploy (github workflow) tương ứng
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate git current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
IFS="-" read _ ENV <<< "${CURRENT_BRANCH}"

if [ "$CURRENT_BRANCH" != "deploy-develop" ] && [ "$CURRENT_BRANCH" != "deploy-production" ]; then
  echo -e "${RED}Error: Environment parameter is required${NC}"
  echo "Usage script in deploy-develop or deploy-production branch:
        - scripts/deploy.sh [develop|production]
        - yarn deploy:dev
        - yarn deploy:prod
        "
  exit 1
fi

# Verify docker daemon is running
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}Error: Docker daemon is not running${NC}"
  exit 1
fi

echo -e "${GREEN}Starting deployment for environment: ${ENV}${NC}"

echo -e "${YELLOW}Step 1: Building Docker image...${NC}"
docker compose -f docker/docker-compose.yml build

if [ $? != 0 ]; then
  exit 1
fi

echo -e "${GREEN}✓ Docker image built successfully${NC}"

echo -e "${YELLOW}Step 2: Pushing Docker image to registry...${NC}"

DOCKER_IMAGE_NAME="jjuidev/job-runner-s3:latest"
if ! docker push ${DOCKER_IMAGE_NAME} >/dev/null 2>&1; then
  echo -e "${RED}Error: Docker push failed, please check your Docker credentials and try again${NC}"
  echo "Usage:
        - docker login
        "
  exit 1
fi

echo -e "${GREEN}✓ Docker image pushed successfully${NC}"

echo -e "${YELLOW}Step 3: Pushing to ${CURRENT_BRANCH} branch...${NC}"

commit_message="ci: deploy to ${ENV} - $(date +'%H:%M:%S %d/%m/%Y')" # Standard Vietnamese format
if git diff --quiet && git diff --cached --quiet; then
  echo -e "${YELLOW}No changes to commit, creating empty commit to trigger CI/CD...${NC}"
  git commit --allow-empty -m "${commit_message}" >/dev/null 2>&1
else
  git add .
  git commit -m "${commit_message}" >/dev/null 2>&1
fi

echo -e "${GREEN}✓ Commit created successfully to trigger CI/CD${NC}"

git push -u origin ${CURRENT_BRANCH}

echo -e "${GREEN}✓ Pushed to ${CURRENT_BRANCH} branch successfully${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Environment: ${ENV}${NC}"
echo -e "${GREEN}========================================${NC}"

