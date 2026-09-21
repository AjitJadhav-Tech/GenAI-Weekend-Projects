from bedrock_agentcore import BedrockAgentCoreApp
import boto3
import yfinance as yf
import json
import os

app = BedrockAgentCoreApp()

# Initialize Bedrock client
bedrock = boto3.client('bedrock-runtime', region_name=os.getenv('AWS_REGION', 'us-east-1'))

# ============================================
# CONFIGURATION
# ============================================

MODEL_ID = os.getenv("BEDROCK_MODEL_ID", "us.amazon.nova-lite-v1:0")

SYSTEM_PROMPT = """You are a helpful financial AI assistant.
You have access to a tool that fetches real-time stock prices and market data using Yahoo Finance (yfinance).
When users ask about a stock, company price, market cap, or ticker, always call the `get_stock_price` tool to fetch accurate live data.
Be concise, clear, and professional in your financial responses."""

# ============================================
# SINGLE TOOL: YAHOO FINANCE STOCK LOOKUP
# ============================================

def get_stock_price(ticker: str) -> dict:
    """Fetch live stock price and company details from Yahoo Finance (yfinance)."""
    clean_ticker = ticker.strip().upper()
    try:
        stock = yf.Ticker(clean_ticker)
        info = stock.info
        
        price = info.get("currentPrice") or info.get("regularMarketPrice")
        if price is None:
            hist = stock.history(period="1d")
            if not hist.empty:
                price = round(float(hist["Close"].iloc[-1]), 2)
                
        if price is None:
            return {"error": f"Could not retrieve stock price for ticker symbol '{clean_ticker}'."}
            
        return {
            "ticker": clean_ticker,
            "company_name": info.get("longName") or info.get("shortName") or clean_ticker,
            "current_price": price,
            "currency": info.get("currency", "USD"),
            "market_cap": info.get("marketCap"),
            "fiftyTwoWeekHigh": info.get("fiftyTwoWeekHigh"),
            "fiftyTwoWeekLow": info.get("fiftyTwoWeekLow"),
            "summary": (info.get("longBusinessSummary") or "")[:200]
        }
    except Exception as e:
        return {"error": f"Failed to fetch Yahoo Finance data for '{clean_ticker}': {str(e)}"}


# Bedrock Tool Specification
TOOLS_SPEC = [
    {
        "toolSpec": {
            "name": "get_stock_price",
            "description": "Fetch real-time stock price, currency, market cap, and company info for a stock ticker symbol (e.g. AAPL, GOOGL, MSFT, AMZN, TSLA).",
            "inputSchema": {
                "json": {
                    "type": "object",
                    "properties": {
                        "ticker": {
                            "type": "string",
                            "description": "Stock ticker symbol, e.g. AAPL, GOOGL, MSFT, NVDA"
                        }
                    },
                    "required": ["ticker"]
                }
            }
        }
    }
]


def execute_tool(tool_name: str, tool_args: dict) -> dict:
    """Execute the requested tool."""
    if tool_name == "get_stock_price":
        ticker = tool_args.get("ticker", "")
        return get_stock_price(ticker)
    return {"error": f"Unknown tool: {tool_name}"}


# ============================================
# AGENT ENTRYPOINT
# ============================================

@app.entrypoint
def invoke(payload: dict):
    """AI Financial Agent with yfinance live stock data tool & AgentCore Runtime support"""
    user_input = payload.get("prompt") or payload.get("inputText") or payload.get("input", "Hello!")
    
    session_attributes = payload.get("sessionAttributes", {})
    memory_summary = session_attributes.get("memorySummary", "")
    
    prompt_text = user_input
    if memory_summary:
        prompt_text = f"Previous Conversation Summary:\n{memory_summary}\n\nCurrent User Request:\n{user_input}"
        
    messages = [
        {
            "role": "user",
            "content": [{"text": prompt_text}]
        }
    ]
    
    tools_executed = []
    
    try:
        # Loop for Converse API tool execution
        for _ in range(5):
            response = bedrock.converse(
                modelId=MODEL_ID,
                system=[{"text": SYSTEM_PROMPT}],
                messages=messages,
                toolConfig={"tools": TOOLS_SPEC},
                inferenceConfig={
                    "maxTokens": 1024,
                    "temperature": 0.5
                }
            )
            
            output_message = response['output']['message']
            messages.append(output_message)
            stop_reason = response.get('stopReason')
            
            if stop_reason == 'tool_use':
                tool_results_content = []
                for content_block in output_message.get('content', []):
                    if 'toolUse' in content_block:
                        tool_use = content_block['toolUse']
                        tool_use_id = tool_use['toolUseId']
                        tool_name = tool_use['name']
                        tool_args = tool_use['input']
                        
                        # Execute yfinance tool
                        result_data = execute_tool(tool_name, tool_args)
                        tools_executed.append({
                            "name": tool_name,
                            "input": tool_args,
                            "output": result_data
                        })
                        
                        tool_results_content.append({
                            "toolResult": {
                                "toolUseId": tool_use_id,
                                "content": [{"json": result_data}]
                            }
                        })
                
                messages.append({
                    "role": "user",
                    "content": tool_results_content
                })
            else:
                final_text = ""
                for block in output_message.get('content', []):
                    if 'text' in block:
                        final_text += block['text']
                        
                return {
                    "result": final_text,
                    "model": MODEL_ID,
                    "toolsExecuted": tools_executed,
                    "hasMemoryContext": bool(memory_summary)
                }
                
        return {
            "result": "Agent completed maximum tool execution iterations.",
            "model": MODEL_ID,
            "toolsExecuted": tools_executed
        }
        
    except Exception as e:
        return {
            "error": str(e),
            "model": MODEL_ID,
            "toolsExecuted": tools_executed
        }

if __name__ == "__main__":
    app.run()
