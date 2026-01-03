#!/bin/bash

# MyAI Project - Complete Verification Script
# Run this to verify everything is working

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        MyAI Project - Integration Verification             ║"
echo "║                  2026-01-03                                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

# Test function
test_step() {
    local name=$1
    local command=$2
    echo ""
    echo -e "${BLUE}Testing: ${name}${NC}"
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: ${name}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: ${name}"
        ((FAILED++))
    fi
}

# ============================================================================
# SYSTEM CHECKS
# ============================================================================

echo ""
echo -e "${BLUE}═══ SYSTEM REQUIREMENTS ═══${NC}"

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓${NC} Node.js installed: ${NODE_VERSION}"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Node.js NOT found. Please install from nodejs.org"
    ((FAILED++))
fi

# Check npm
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm -v)
    echo -e "${GREEN}✓${NC} npm installed: ${NPM_VERSION}"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} npm NOT found"
    ((FAILED++))
fi

# Check Flutter
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n1)
    echo -e "${GREEN}✓${NC} Flutter installed: ${FLUTTER_VERSION}"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Flutter NOT found. Please install from flutter.dev"
    ((FAILED++))
fi

# ============================================================================
# BACKEND CHECKS
# ============================================================================

echo ""
echo -e "${BLUE}═══ BACKEND CHECKS ═══${NC}"

# Check backend folder exists
if [ -d "backend" ]; then
    echo -e "${GREEN}✓${NC} backend/ folder exists"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} backend/ folder NOT found"
    ((FAILED++))
fi

# Check server.js exists
if [ -f "backend/server.js" ]; then
    echo -e "${GREEN}✓${NC} backend/server.js exists"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} backend/server.js NOT found"
    ((FAILED++))
fi

# Check .env exists
if [ -f "backend/.env" ]; then
    echo -e "${GREEN}✓${NC} backend/.env file exists"
    ((PASSED++))
    
    # Check for required env vars
    if grep -q "GROQ_API_KEY" backend/.env; then
        echo -e "  ${GREEN}✓${NC} GROQ_API_KEY is set"
    else
        echo -e "  ${YELLOW}⚠${NC} GROQ_API_KEY not found in .env"
    fi
    
    if grep -q "tavily=" backend/.env; then
        echo -e "  ${GREEN}✓${NC} tavily key is set"
    else
        echo -e "  ${YELLOW}⚠${NC} tavily key not found in .env"
    fi
    
    if grep -q "geminiapikey" backend/.env; then
        echo -e "  ${GREEN}✓${NC} geminiapikey is set"
    else
        echo -e "  ${YELLOW}⚠${NC} geminiapikey not found in .env"
    fi
else
    echo -e "${RED}✗${NC} backend/.env file NOT found - create it with:"
    echo "    PORT=3000"
    echo "    GROQ_API_KEY=<your-key>"
    echo "    tavily=<your-key>"
    echo "    geminiapikey=<your-key>"
    ((FAILED++))
fi

# Check package.json
if [ -f "backend/package.json" ]; then
    echo -e "${GREEN}✓${NC} backend/package.json exists"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} backend/package.json NOT found"
    ((FAILED++))
fi

# Check node_modules
if [ -d "backend/node_modules" ]; then
    echo -e "${GREEN}✓${NC} backend/node_modules installed"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} backend/node_modules not found"
    echo "   Run: cd backend && npm install"
    ((FAILED++))
fi

# ============================================================================
# FRONTEND CHECKS
# ============================================================================

echo ""
echo -e "${BLUE}═══ FRONTEND CHECKS ═══${NC}"

# Check pubspec.yaml
if [ -f "pubspec.yaml" ]; then
    echo -e "${GREEN}✓${NC} pubspec.yaml exists"
    ((PASSED++))
    
    # Check for key dependencies
    if grep -q "http:" pubspec.yaml; then
        echo -e "  ${GREEN}✓${NC} http dependency present"
    else
        echo -e "  ${RED}✗${NC} http dependency missing"
    fi
    
    if grep -q "firebase_core:" pubspec.yaml; then
        echo -e "  ${GREEN}✓${NC} firebase_core dependency present"
    else
        echo -e "  ${RED}✗${NC} firebase_core dependency missing"
    fi
    
    if grep -q "image_picker:" pubspec.yaml; then
        echo -e "  ${GREEN}✓${NC} image_picker dependency present"
    else
        echo -e "  ${RED}✗${NC} image_picker dependency missing"
    fi
else
    echo -e "${RED}✗${NC} pubspec.yaml NOT found"
    ((FAILED++))
fi

# Check main.dart
if [ -f "lib/main.dart" ]; then
    echo -e "${GREEN}✓${NC} lib/main.dart exists"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} lib/main.dart NOT found"
    ((FAILED++))
fi

# Check services exist
echo ""
echo -e "${BLUE}Checking service files:${NC}"

services=("api_service.dart" "gemini_services.dart" "web_search_service.dart" "chat_storage_service.dart" "auth_services.dart")

for service in "${services[@]}"; do
    if [ -f "lib/services/$service" ]; then
        echo -e "  ${GREEN}✓${NC} lib/services/$service"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} lib/services/$service NOT found"
        ((FAILED++))
    fi
done

# Check screens exist
echo ""
echo -e "${BLUE}Checking screen files:${NC}"

screens=("online_ai_screen.dart" "ai_screen.dart" "study_plan_screen.dart")

for screen in "${screens[@]}"; do
    if [ -f "lib/screens/$screen" ]; then
        echo -e "  ${GREEN}✓${NC} lib/screens/$screen"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} lib/screens/$screen NOT found"
        ((FAILED++))
    fi
done

# ============================================================================
# API ENDPOINT CHECKS (only if backend is running)
# ============================================================================

echo ""
echo -e "${BLUE}═══ BACKEND ENDPOINT CHECKS ═══${NC}"
echo -e "${YELLOW}Note: These tests require backend running on http://localhost:3000${NC}"
echo ""

# Check if localhost is responding
if timeout 2 bash -c "cat < /dev/null > /dev/tcp/localhost/3000" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Backend running on localhost:3000"
    
    # Test root endpoint
    if curl -s http://localhost:3000/ | grep -q "Backend alive"; then
        echo -e "${GREEN}✓${NC} Root endpoint (/) responding"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Root endpoint (/) not responding correctly"
        ((FAILED++))
    fi
    
    # Test chat endpoint
    CHAT_RESPONSE=$(curl -s -X POST http://localhost:3000/api/ask \
        -H "Content-Type: application/json" \
        -d '{"type":"chat","data":{"message":"Hello"}}' 2>/dev/null)
    
    if echo "$CHAT_RESPONSE" | grep -q '"provider":"groq"'; then
        echo -e "${GREEN}✓${NC} Chat endpoint (/api/ask?type=chat) working"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Chat endpoint not responding correctly"
        echo "   Response: $CHAT_RESPONSE"
        ((FAILED++))
    fi
    
    # Test search endpoint
    SEARCH_RESPONSE=$(curl -s -X POST http://localhost:3000/api/ask \
        -H "Content-Type: application/json" \
        -d '{"type":"search","data":{"query":"Flutter"}}' 2>/dev/null)
    
    if echo "$SEARCH_RESPONSE" | grep -q '"provider":"tavily"'; then
        echo -e "${GREEN}✓${NC} Search endpoint (/api/ask?type=search) working"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Search endpoint not responding correctly"
        echo "   Response: $SEARCH_RESPONSE"
        ((FAILED++))
    fi
    
    # Test image endpoint
    IMAGE_RESPONSE=$(curl -s -X POST http://localhost:3000/api/ask \
        -H "Content-Type: application/json" \
        -d '{"type":"image","data":{"imageUrl":"https://example.com/test.jpg","prompt":"test"}}' 2>/dev/null)
    
    if echo "$IMAGE_RESPONSE" | grep -q '"provider":"gemini"'; then
        echo -e "${GREEN}✓${NC} Image endpoint (/api/ask?type=image) working"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Image endpoint not responding correctly"
        echo "   Response: $IMAGE_RESPONSE"
        ((FAILED++))
    fi
else
    echo -e "${YELLOW}⚠${NC} Backend not running on localhost:3000"
    echo "   To test, run: cd backend && node server.js"
    echo "   Then rerun this script"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                       TEST SUMMARY                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ ALL CHECKS PASSED - Ready to run!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Make sure backend is running: cd backend && node server.js"
    echo "2. In another terminal, run: flutter run"
    echo "3. Test chat, search, and image features in the app"
    echo ""
    exit 0
else
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}✗ SOME CHECKS FAILED - Please fix above issues${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "- Install missing dependencies"
    echo "- Set environment variables in backend/.env"
    echo "- Run: npm install (in backend folder)"
    echo "- Run: flutter pub get"
    echo ""
    exit 1
fi
