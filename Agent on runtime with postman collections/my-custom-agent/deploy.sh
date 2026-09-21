#!/usr/bin/env bash
# ==============================================================================
# AgentCore Runtime Deployment Script
# Automatically configures, builds, and deploys the Bedrock AgentCore agent.
# ==============================================================================

set -e

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE} 🚀 Deploying Agent to AWS Bedrock AgentCore Runtime ${NC}"
echo -e "${BLUE}====================================================${NC}"

AGENT_NAME="healthcare_agent"
ENTRYPOINT="agent.py"
REGION="${AWS_REGION:-us-east-1}"

# 1. Check prerequisites
echo -e "\n${YELLOW}[1/4] Checking prerequisites...${NC}"

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

echo -e "${GREEN}✓ Using Python: $($PYTHON_BIN --version 2>&1)${NC}"

export PYTHONIOENCODING="utf-8"
export PYTHONUTF8="1"
export AGENTCORE_SUPPRESS_RECOMMENDATION=1

# Check if Python starter toolkit is installed; if not, install it
if ! "$PYTHON_BIN" -m bedrock_agentcore_starter_toolkit.cli.cli --help &> /dev/null; then
    echo -e "${YELLOW}Installing 'bedrock-agentcore-starter-toolkit'...${NC}"
    "$PYTHON_BIN" -m pip install bedrock-agentcore-starter-toolkit
fi

AGENTCORE_CMD="$PYTHON_BIN -m bedrock_agentcore_starter_toolkit.cli.cli"
echo -e "${GREEN}✓ Bedrock AgentCore Starter Toolkit CLI is ready.${NC}"

# Check AWS Credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ Unable to verify AWS credentials.${NC}"
    echo "Please configure your AWS credentials using 'aws configure' or export AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ Authenticated with AWS Account: ${ACCOUNT_ID} (Region: ${REGION})${NC}"

# 2. Configure AgentCore Project
echo -e "\n${YELLOW}[2/4] Configuring AgentCore project settings...${NC}"

CONFIGURE_FLAG=""
if [ ! -f ".bedrock_agentcore.yaml" ]; then
    CONFIGURE_FLAG="-c"
fi

$AGENTCORE_CMD configure \
    $CONFIGURE_FLAG \
    -n "${AGENT_NAME}" \
    -e "${ENTRYPOINT}" \
    -ni \
    --deployment-type container \
    --region "${REGION}"

# Ensure ECR Repository auto-creation is enabled in .bedrock_agentcore.yaml
if [ -f ".bedrock_agentcore.yaml" ]; then
    sed -i 's/ecr_auto_create: false/ecr_auto_create: true/g' .bedrock_agentcore.yaml 2>/dev/null || \
    sed -i '' 's/ecr_auto_create: false/ecr_auto_create: true/g' .bedrock_agentcore.yaml 2>/dev/null || true
    echo -e "${GREEN}✓ Enabled ECR auto-creation in .bedrock_agentcore.yaml${NC}"
fi

# 3. Deploy Agent to Bedrock AgentCore Runtime
echo -e "\n${YELLOW}[3/4] Deploying agent container via AWS CodeBuild & AgentCore Runtime...${NC}"
echo -e "${BLUE}This process builds ARM64 containers in the cloud and registers your endpoint.${NC}"

$AGENTCORE_CMD deploy

# 4. Verify & Test Deployment
echo -e "\n${YELLOW}[4/4] Verifying deployment with a test invocation...${NC}"

echo -e "${BLUE}Sending test prompt to deployed agent...${NC}"
$AGENTCORE_CMD invoke '{"prompt": "What is the stock price of Apple (AAPL)?"}'

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN} 🎉 Deployment completed successfully!${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "You can invoke your agent anytime using:"
echo -e "  ${YELLOW}${AGENTCORE_CMD} invoke '{\"prompt\": \"What is the stock price of TSLA?\"}'${NC}"

