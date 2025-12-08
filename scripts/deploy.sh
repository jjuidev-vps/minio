#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -eq 0 ]; then
  echo "${RED}Error: Environment parameter is required${NC}"
  echo "${YELLOW}Usage:${NC}"
  echo "${YELLOW}  yarn deploy:develop or yarn deploy:production${NC}"
  exit 1
fi

ENV=$1
if [ "$ENV" != "develop" ] && [ "$ENV" != "production" ]; then
  echo "${RED}Error: Environment must be 'develop' or 'production'${NC}"
  exit 1
fi

TARGET_BRANCH=$ENV

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "${RED}Error: You have uncommitted changes${NC}"
  echo "${RED}Please commit or stash your changes before deploying${NC}"
  exit 1
fi

show_loading() {
  local pid=$1
  local count=0
  local max_dots=30
  local dots=""
  while kill -0 $pid 2>/dev/null; do
    count=$((count + 1))
    if [ $count -gt $max_dots ]; then
      count=1
      dots=""
      printf "\r${YELLOW}%${max_dots}s${NC}" ""
    fi
    dots="${dots}."
    printf "\r${YELLOW}${dots}${NC}"
    sleep 0.75
  done
  printf "\r%${max_dots}s\r" ""
}

echo "${YELLOW}Starting deployment for environment: ${ENV}${NC}"
echo "${YELLOW}Please wait while we process the deployment${NC}"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
{
  git fetch --prune origin ${TARGET_BRANCH} >/dev/null 2>&1
  git branch -D ${TARGET_BRANCH} >/dev/null 2>&1 || true
  git checkout -b ${TARGET_BRANCH} origin/${TARGET_BRANCH} >/dev/null 2>&1 || true

  commit_message="ci: deploy to ${ENV} - $(date +'%H:%M:%S %d/%m/%Y')"
  git commit --allow-empty -m "${commit_message}" >/dev/null 2>&1
} &
DEPLOY_PID=$!
show_loading $DEPLOY_PID
wait $DEPLOY_PID || true

git push origin ${TARGET_BRANCH}
git checkout ${CURRENT_BRANCH} >/dev/null 2>&1

echo "${GREEN}========================================${NC}"
echo "${GREEN}Deployment trigger completed!${NC}"
echo "${GREEN}Build and deployment will be handled by GitHub Actions${NC}"
echo "${GREEN}Environment: ${ENV}${NC}"
echo "${GREEN}Branch: ${TARGET_BRANCH}${NC}"
echo "${GREEN}========================================${NC}"
