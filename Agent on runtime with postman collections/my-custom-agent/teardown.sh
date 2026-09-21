#!/usr/bin/env bash
# ==============================================================================
# AgentCore Runtime Teardown & Resource Cleanup Script
# Safely tears down and deletes all deployed AWS Bedrock AgentCore resources.
# ==============================================================================

set -e

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}====================================================${NC}"
echo -e "${RED} 🧹 Teardown Bedrock AgentCore Runtime Resources    ${NC}"
echo -e "${RED}====================================================${NC}"

AGENT_NAME="healthcare_agent"

# Resolve Python executable
PYTHON_BIN=""
for cmd in python python3 py; do
    if command -v "$cmd" &> /dev/null; then
        PYTHON_BIN="$cmd"
        break
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    echo -e "${RED}❌ Python is not installed or not found in PATH.${NC}"
    exit 1
fi

export PYTHONIOENCODING="utf-8"
export PYTHONUTF8="1"
export AGENTCORE_SUPPRESS_RECOMMENDATION=1
AGENTCORE_CMD="$PYTHON_BIN -m bedrock_agentcore_starter_toolkit.cli.cli"

# Check AWS Credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ Unable to verify AWS credentials.${NC}"
    echo "Please configure your AWS credentials using 'aws configure' before running teardown."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${YELLOW}Target AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${YELLOW}Target Agent: ${AGENT_NAME}${NC}"

# Optional prompt confirmation if interactive
if [ -t 0 ]; then
    read -p "Are you sure you want to destroy all resources for '${AGENT_NAME}'? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${BLUE}Teardown cancelled.${NC}"
        exit 0
    fi
fi

echo -e "\n${YELLOW}Destroying Bedrock AgentCore endpoint, agent runtime, CodeBuild project, and ECR repository...${NC}"

$AGENTCORE_CMD destroy --agent "${AGENT_NAME}" --force --delete-ecr-repo

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN} ✅ Teardown completed successfully!${NC}"
echo -e "${GREEN}====================================================${NC}"
