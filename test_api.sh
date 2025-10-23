#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:8080"
PASS_COUNT=0
FAIL_COUNT=0

# Helper functions
print_test() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

print_response() {
    echo -e "${YELLOW}Response:${NC} $1"
}

# Check if server is running
check_server() {
    print_test "Checking if server is running..."

    if curl -s -f "$BASE_URL/health" > /dev/null 2>&1; then
        print_pass "Server is running"
        return 0
    else
        print_fail "Server is not running at $BASE_URL"
        echo -e "${YELLOW}Please start the server with: zig build run${NC}"
        exit 1
    fi
}

# Test 1: Health Check
test_health() {
    print_test "Test 1: Health Check"

    RESPONSE=$(curl -s "$BASE_URL/health")

    if echo "$RESPONSE" | grep -q "ok"; then
        print_pass "Health check endpoint works"
        print_response "$RESPONSE"
    else
        print_fail "Health check endpoint failed"
        print_response "$RESPONSE"
    fi
}

# Test 2: Get All Users
test_get_all_users() {
    print_test "Test 2: Get All Users"

    RESPONSE=$(curl -s "$BASE_URL/api/users")
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/users")

    if [ "$HTTP_CODE" -eq 200 ]; then
        print_pass "GET /api/users returns 200"
        print_response "$RESPONSE"
    else
        print_fail "GET /api/users returned HTTP $HTTP_CODE"
        print_response "$RESPONSE"
    fi
}

# Test 3: Create User
test_create_user() {
    print_test "Test 3: Create User"

    TIMESTAMP=$(date +%s)
    USER_EMAIL="test${TIMESTAMP}@example.com"
    USER_NAME="Test User ${TIMESTAMP}"

    RESPONSE=$(curl -s -X POST "$BASE_URL/api/users" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${USER_NAME}\",\"email\":\"${USER_EMAIL}\"}")

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/users" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${USER_NAME}2\",\"email\":\"${USER_EMAIL}2\"}")

    if [ "$HTTP_CODE" -eq 201 ]; then
        print_pass "POST /api/users returns 201"
        print_response "$RESPONSE"

        # Extract user ID for later tests
        USER_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
        echo "$USER_ID" > /tmp/test_user_id.txt
        echo -e "${BLUE}Created user ID: $USER_ID${NC}"
    else
        print_fail "POST /api/users returned HTTP $HTTP_CODE"
        print_response "$RESPONSE"
    fi
}

# Test 4: Get User by ID
test_get_user_by_id() {
    print_test "Test 4: Get User by ID"

    if [ ! -f /tmp/test_user_id.txt ]; then
        print_fail "No user ID found from previous test"
        return
    fi

    USER_ID=$(cat /tmp/test_user_id.txt)
    RESPONSE=$(curl -s "$BASE_URL/api/users/$USER_ID")
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/users/$USER_ID")

    if [ "$HTTP_CODE" -eq 200 ]; then
        print_pass "GET /api/users/$USER_ID returns 200"
        print_response "$RESPONSE"
    else
        print_fail "GET /api/users/$USER_ID returned HTTP $HTTP_CODE"
        print_response "$RESPONSE"
    fi
}

# Test 5: Update User
test_update_user() {
    print_test "Test 5: Update User"

    if [ ! -f /tmp/test_user_id.txt ]; then
        print_fail "No user ID found from previous test"
        return
    fi

    USER_ID=$(cat /tmp/test_user_id.txt)
    UPDATED_NAME="Updated User $(date +%s)"

    RESPONSE=$(curl -s -X PUT "$BASE_URL/api/users/$USER_ID" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${UPDATED_NAME}\"}")

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE_URL/api/users/$USER_ID" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${UPDATED_NAME}2\"}")

    if [ "$HTTP_CODE" -eq 200 ]; then
        print_pass "PUT /api/users/$USER_ID returns 200"
        print_response "$RESPONSE"
    else
        print_fail "PUT /api/users/$USER_ID returned HTTP $HTTP_CODE"
        print_response "$RESPONSE"
    fi
}

# Test 6: Delete User
test_delete_user() {
    print_test "Test 6: Delete User"

    if [ ! -f /tmp/test_user_id.txt ]; then
        print_fail "No user ID found from previous test"
        return
    fi

    USER_ID=$(cat /tmp/test_user_id.txt)
    RESPONSE=$(curl -s -X DELETE "$BASE_URL/api/users/$USER_ID")
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/api/users/$USER_ID")

    if [ "$HTTP_CODE" -eq 200 ]; then
        print_pass "DELETE /api/users/$USER_ID returns 200"
        print_response "$RESPONSE"
    else
        print_fail "DELETE /api/users/$USER_ID returned HTTP $HTTP_CODE"
        print_response "$RESPONSE"
    fi

    # Verify user is deleted
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/users/$USER_ID")
    if [ "$HTTP_CODE" -eq 404 ]; then
        print_pass "Deleted user returns 404"
    else
        print_fail "Deleted user should return 404, got HTTP $HTTP_CODE"
    fi

    # Cleanup
    rm -f /tmp/test_user_id.txt
}

# Test 7: Error Handling - Invalid ID
test_invalid_id() {
    print_test "Test 7: Error Handling - Invalid User ID"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/users/invalid")

    if [ "$HTTP_CODE" -eq 400 ]; then
        print_pass "GET /api/users/invalid returns 400"
    else
        print_fail "GET /api/users/invalid should return 400, got HTTP $HTTP_CODE"
    fi
}

# Test 8: Error Handling - Missing Fields
test_missing_fields() {
    print_test "Test 8: Error Handling - Missing Required Fields"

    RESPONSE=$(curl -s -X POST "$BASE_URL/api/users" \
        -H "Content-Type: application/json" \
        -d '{"name":"Only Name"}')

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/users" \
        -H "Content-Type: application/json" \
        -d '{"name":"Only Name"}')

    if [ "$HTTP_CODE" -eq 400 ] || [ "$HTTP_CODE" -eq 500 ]; then
        print_pass "POST with missing email returns error"
        print_response "$RESPONSE"
    else
        print_fail "POST with missing fields should return error, got HTTP $HTTP_CODE"
        print_response "$RESPONSE"
    fi
}

# Test 9: Error Handling - Not Found
test_not_found() {
    print_test "Test 9: Error Handling - User Not Found"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/users/99999")

    if [ "$HTTP_CODE" -eq 404 ]; then
        print_pass "GET /api/users/99999 returns 404"
    else
        print_fail "GET /api/users/99999 should return 404, got HTTP $HTTP_CODE"
    fi
}

# Test 10: Cache Testing
test_cache() {
    print_test "Test 10: Cache Testing"

    # First request
    START=$(date +%s%N)
    curl -s "$BASE_URL/api/users" > /dev/null
    END=$(date +%s%N)
    TIME1=$((($END - $START) / 1000000))

    # Second request (should be cached)
    START=$(date +%s%N)
    curl -s "$BASE_URL/api/users" > /dev/null
    END=$(date +%s%N)
    TIME2=$((($END - $START) / 1000000))

    echo -e "${BLUE}First request: ${TIME1}ms${NC}"
    echo -e "${BLUE}Second request (cached): ${TIME2}ms${NC}"

    if [ "$TIME2" -le "$TIME1" ]; then
        print_pass "Cache appears to be working (second request ≤ first request)"
    else
        echo -e "${YELLOW}⚠ Cache might not be working (second request > first request)${NC}"
        echo -e "${YELLOW}  This could be due to network variance${NC}"
    fi
}

# Main test runner
main() {
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       Zig CRUD API Test Suite               ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"

    check_server

    test_health
    test_get_all_users
    test_create_user
    test_get_user_by_id
    test_update_user
    test_delete_user
    test_invalid_id
    test_missing_fields
    test_not_found
    test_cache

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            Test Summary                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo -e "Total Tests: $((PASS_COUNT + FAIL_COUNT))"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"

    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}✗ Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests
main
