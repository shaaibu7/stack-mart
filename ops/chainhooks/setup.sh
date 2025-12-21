#!/bin/bash

# StackMart Chainhooks Setup Script
# This script helps set up Hiro Chainhooks for monitoring StackMart events

set -e

echo "🔧 StackMart Chainhooks Setup"
echo "=============================="
echo ""

# Check if chainhook CLI is installed
if ! command -v chainhook &> /dev/null; then
    echo "❌ Chainhook CLI not found!"
    echo ""
    echo "Install it with:"
    echo "  cargo install --git https://github.com/hirosystems/chainhook.git chainhook-cli"
    echo ""
    exit 1
fi

# Determine network
read -p "Select network (mainnet/testnet) [testnet]: " NETWORK
NETWORK=${NETWORK:-testnet}

if [ "$NETWORK" != "mainnet" ] && [ "$NETWORK" != "testnet" ]; then
    echo "❌ Invalid network. Must be 'mainnet' or 'testnet'"
    exit 1
fi

CONFIG_FILE="stack-mart-${NETWORK}.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

echo ""
echo "📋 Configuration file: $CONFIG_FILE"
echo ""

# Check if webhook URL is set
WEBHOOK_URL=$(grep -A 1 "delivery:" "$CONFIG_FILE" | grep "url:" | awk '{print $2}')

if [[ "$WEBHOOK_URL" == *"your-service.example.com"* ]] || [[ "$WEBHOOK_URL" == *"localhost"* ]]; then
    echo "⚠️  Warning: Webhook URL appears to be a placeholder"
    echo "   Current URL: $WEBHOOK_URL"
    read -p "   Enter your webhook server URL: " NEW_URL
    
    if [ -n "$NEW_URL" ]; then
        # Update the URL in the config file
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|url:.*|url: $NEW_URL|" "$CONFIG_FILE"
        else
            sed -i "s|url:.*|url: $NEW_URL|" "$CONFIG_FILE"
        fi
        echo "✅ Updated webhook URL to: $NEW_URL"
    fi
fi

# Check for secret
SECRET=$(grep "secret:" "$CONFIG_FILE" | awk '{print $2}')

if [[ "$SECRET" == *"<SHARED_SECRET>"* ]] || [ -z "$SECRET" ]; then
    echo ""
    echo "🔐 Generating shared secret..."
    NEW_SECRET=$(openssl rand -hex 32)
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|secret:.*|secret: \"$NEW_SECRET\"|" "$CONFIG_FILE"
    else
        sed -i "s|secret:.*|secret: \"$NEW_SECRET\"|" "$CONFIG_FILE"
    fi
    
    echo "✅ Generated and set shared secret"
    echo "   Save this secret for your webhook server: $NEW_SECRET"
    echo ""
fi

echo ""
echo "📝 Reviewing configuration..."
echo ""
cat "$CONFIG_FILE"
echo ""

read -p "Register this chainhook? (y/n) [y]: " CONFIRM
CONFIRM=${CONFIRM:-y}

if [ "$CONFIRM" != "y" ]; then
    echo "❌ Cancelled"
    exit 0
fi

echo ""
echo "🚀 Registering chainhook..."
chainhook register "$CONFIG_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Chainhook registered successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Make sure your webhook server is running and accessible"
    echo "2. Set CHAINHOOK_SECRET environment variable on your server"
    echo "3. Monitor events at: http://your-server/api/events"
else
    echo ""
    echo "❌ Failed to register chainhook"
    exit 1
fi

