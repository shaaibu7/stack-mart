#!/bin/bash

# SIP-090 NFT Contract Test Runner Script
# This script runs all SIP-090 related tests with proper reporting

set -e

echo "🚀 Starting SIP-090 NFT Contract Test Suite"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if npm is available
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed or not in PATH"
    exit 1
fi

# Check if package.json exists
if [ ! -f "package.json" ]; then
    print_error "package.json not found. Please run from project root."
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    print_status "Installing dependencies..."
    npm install
fi

print_status "Running SIP-090 NFT Contract Tests..."
echo ""

# Test categories
declare -a test_files=(
    "tests/sip-090-nft.test.ts"
    "tests/sip-090-edge-cases.test.ts"
    "tests/sip-090-integration.test.ts"
    "tests/sip-090-performance.test.ts"
    "tests/sip-090-security.test.ts"
    "tests/sip-090-compliance.test.ts"
    "tests/sip-090-events.test.ts"
)

declare -a test_names=(
    "Core Functionality Tests"
    "Edge Cases Tests"
    "Integration Tests"
    "Performance Tests"
    "Security Tests"
    "Compliance Tests"
    "Event Emission Tests"
)

# Run individual test suites
failed_tests=0
total_tests=${#test_files[@]}

for i in "${!test_files[@]}"; do
    test_file="${test_files[$i]}"
    test_name="${test_names[$i]}"
    
    echo "📋 Running: $test_name"
    echo "   File: $test_file"
    
    if npm test -- "$test_file" --reporter=verbose; then
        print_success "✅ $test_name passed"
    else
        print_error "❌ $test_name failed"
        ((failed_tests++))
    fi
    echo ""
done

# Run all SIP-090 tests together
echo "🔄 Running Complete SIP-090 Test Suite..."
if npm test -- "tests/sip-090-*.test.ts" --reporter=verbose; then
    print_success "✅ Complete test suite passed"
else
    print_error "❌ Complete test suite failed"
    ((failed_tests++))
fi

# Generate coverage report if requested
if [ "$1" = "--coverage" ]; then
    echo ""
    print_status "Generating coverage report..."
    npm test -- "tests/sip-090-*.test.ts" --coverage
fi

# Summary
echo ""
echo "=========================================="
echo "🏁 Test Suite Summary"
echo "=========================================="

if [ $failed_tests -eq 0 ]; then
    print_success "All SIP-090 tests passed! 🎉"
    echo "✅ Core Functionality: PASSED"
    echo "✅ Edge Cases: PASSED"
    echo "✅ Integration: PASSED"
    echo "✅ Performance: PASSED"
    echo "✅ Security: PASSED"
    echo "✅ Compliance: PASSED"
    echo "✅ Events: PASSED"
    echo ""
    print_success "SIP-090 NFT Contract is ready for deployment! 🚀"
    exit 0
else
    print_error "$failed_tests test suite(s) failed"
    echo ""
    print_warning "Please fix failing tests before deployment"
    exit 1
fi