# Project Structure & Technical Steering Guide

## 📌 Project Overview
This repository contains a production-ready AI Agent built for **Amazon Bedrock AgentCore Runtime**. The agent leverages **Amazon Bedrock Converse API** (`us.amazon.nova-lite-v1:0` model) and integrates real-time external tools (such as **Yahoo Finance `yfinance`** data fetching). It can be developed locally, deployed serverlessly to AWS Cloud, invoked via CLI/Postman, and torn down cleanly.

---

## 📂 File Directory & Architecture

```
my-custom-agent/
├── agent.py                                 # Main Agent Entrypoint & Tool Execution Loop
├── deploy.sh                                # Automated One-Command AWS Deployment Script
├── teardown.sh                              # Automated Resource Cleanup / Destruction Script
├── Dockerfile                               # Container Image Specification for MicroVM
├── requirements.txt                         # Python Dependencies
├── .bedrock_agentcore.yaml                  # Bedrock AgentCore Configuration Manifest
├── Bedrock_AgentCore_Postman_Collection.json# Standalone Postman API Testing Collection (SigV4)
└── PROJECT_STRUCTURE.md                     # Technical Architecture & Steering Guide
```

---

## 🛠️ File Specifications

### 1. `agent.py`
- **Role**: Application entrypoint decorated with `@app.entrypoint`.
- **Framework**: `bedrock_agentcore.BedrockAgentCoreApp`
- **AI Model**: `us.amazon.nova-lite-v1:0` (Amazon Nova Lite via Bedrock Runtime)
- **Tools Included**:
  - `get_stock_price(ticker)`: Uses `yfinance` to retrieve real-time stock prices, market cap, currency, and 52-week ranges.
- **Orchestration**: Uses Bedrock `converse()` API with automated `stopReason == "tool_use"` execution loop.

### 2. `deploy.sh`
- **Role**: Shell script to automate environment checks, project configuration, CodeBuild container builds, and deployment to Amazon Bedrock AgentCore Runtime.
- **Commands Executed**:
  - `aws sts get-caller-identity` (Authentication validation)
  - `python -m bedrock_agentcore_starter_toolkit configure` (Config generation)
  - `python -m bedrock_agentcore_starter_toolkit deploy` (Cloud CodeBuild & AgentCore provisioning)
  - `python -m bedrock_agentcore_starter_toolkit invoke` (Automated post-deployment verification)

### 3. `teardown.sh`
- **Role**: Safe automated teardown of all cloud infrastructure.
- **Resources Cleaned**: AgentCore Endpoint, Agent Runtime, ECR Images/Repository, CodeBuild Builder, IAM Execution Roles.
- **Command Executed**: `python -m bedrock_agentcore_starter_toolkit destroy --agent healthcare_agent --force --delete-ecr-repo`

### 4. `Dockerfile`
- **Base Image**: `python:3.11-slim`
- **Role**: Packages requirements and `agent.py` into an ARM64 container compatible with AgentCore MicroVM runtime.

### 5. `requirements.txt`
- Dependencies:
  - `bedrock-agentcore` (AgentCore App SDK)
  - `boto3` (AWS SDK for Python)
  - `yfinance` (Real-time Yahoo Finance market data)

### 6. `.bedrock_agentcore.yaml`
- AgentCore project manifest specifying agent entrypoint, deployment type (`container`), platform (`linux/arm64`), AWS Account ID, Region, memory retention settings, and `ecr_auto_create: true`.

### 7. `Bedrock_AgentCore_Postman_Collection.json`
- Postman Collection v2.1.0 containing direct HTTPS REST requests (`POST https://bedrock-agentcore.us-east-1.amazonaws.com/runtimes/.../invocations`).
- Pre-configured with **AWS Signature (SigV4)** authentication (`service: bedrock-agentcore`, `region: us-east-1`).

---

## ⚙️ Steering Guidelines for Development & Modifications

### Adding New Tools
1. Define the Python function in `agent.py` (e.g. `def my_new_tool(...)`).
2. Add the tool JSON Schema to `TOOLS_SPEC` in `agent.py`.
3. Update `execute_tool()` function mapping to dispatch requests to your function.
4. Add any new Python package requirements to `requirements.txt`.

### Deployment & Lifecycle Execution
- **Deploy to AWS**: `bash deploy.sh`
- **Invoke Deployed Agent**: `python -m bedrock_agentcore_starter_toolkit invoke '{"prompt": "..."}'`
- **Clean Up AWS Resources**: `bash teardown.sh`

