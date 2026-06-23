#!/bin/bash
# ============================================================================
# Schema Capture — PostgreSQL Schema Documentation Generator
#
# Uses SchemaSpy to generate HTML documentation of a PostgreSQL database
# schema, including table relationships, column details, and ER diagrams.
#
# Works both locally (loads .env) and in GitHub Actions (uses secrets).
# ============================================================================
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Schema Capture — PostgreSQL Schema Docs${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ==========================================================================
#  1. Load configuration
# ==========================================================================

# In GitHub Actions, secrets are already env vars.
# Locally, load from .env file.
if [ -z "$GITHUB_ACTIONS" ]; then
    if [ -f ".env" ]; then
        echo -e "${GREEN}Loading .env...${NC}"
        set -a
        source .env
        set +a
    else
        echo -e "${YELLOW}No .env found. Copy .env.example to .env and fill in your credentials.${NC}"
        exit 1
    fi
fi

# Validate required variables
for var in DB_HOST DB_PORT DB_NAME DB_USER DB_PASS; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}ERROR: $var is not set.${NC}"
        exit 1
    fi
done

SCHEMASPY_VERSION="${SCHEMASPY_VERSION:-6.2.4}"
SCHEMASPY_JAR="schemaspy-${SCHEMASPY_VERSION}.jar"
JDBC_JAR="postgresql-42.7.3.jar"

# Determine base directory (repo root or current dir)
BASE_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
OUTPUT_DIR="${BASE_DIR}/generated"
LOG_FILE="${OUTPUT_DIR}/schemaspy.log"

mkdir -p "$OUTPUT_DIR"

# ==========================================================================
#  2. Download SchemaSpy + JDBC driver (if not present)
# ==========================================================================

cd "$BASE_DIR"

if [ ! -f "$SCHEMASPY_JAR" ]; then
    echo -e "${YELLOW}Downloading SchemaSpy ${SCHEMASPY_VERSION}...${NC}"
    curl -L -o "$SCHEMASPY_JAR" \
        "https://github.com/schemaspy/schemaspy/releases/download/v${SCHEMASPY_VERSION}/schemaspy-${SCHEMASPY_VERSION}.jar"
    echo -e "${GREEN}✓ SchemaSpy downloaded${NC}"
else
    echo -e "${GREEN}✓ SchemaSpy JAR found${NC}"
fi

if [ ! -f "$JDBC_JAR" ]; then
    echo -e "${YELLOW}Downloading PostgreSQL JDBC driver...${NC}"
    curl -L -o "$JDBC_JAR" \
        "https://jdbc.postgresql.org/download/postgresql-42.7.3.jar"
    echo -e "${GREEN}✓ JDBC driver downloaded${NC}"
else
    echo -e "${GREEN}✓ JDBC driver found${NC}"
fi

# ==========================================================================
#  3. Install Graphviz (required for ER diagrams)
# ==========================================================================

if ! command -v dot &>/dev/null; then
    echo -e "${YELLOW}Installing Graphviz...${NC}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq graphviz
    elif command -v brew &>/dev/null; then
        brew install graphviz
    else
        echo -e "${RED}Please install Graphviz manually: https://graphviz.org/download/${NC}"
        exit 1
    fi
fi

# ==========================================================================
#  4. Run SchemaSpy
# ==========================================================================

# Generate timestamped output directory
TIMESTAMP=$(date +"%Y-%m-%d-%H%M")
REPORT_DIR="${OUTPUT_DIR}/${TIMESTAMP}"
mkdir -p "$REPORT_DIR"

echo ""
echo -e "${BLUE}Connecting to PostgreSQL...${NC}"
echo "  Host: $DB_HOST:$DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

java -jar "$SCHEMASPY_JAR" \
    -t pgsql \
    -dp "$JDBC_JAR" \
    -host "$DB_HOST" \
    -port "$DB_PORT" \
    -db "$DB_NAME" \
    -u "$DB_USER" \
    -p "$DB_PASS" \
    -s public \
    -o "$REPORT_DIR" \
    > "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ SchemaSpy failed. Check log: $LOG_FILE${NC}"
    tail -20 "$LOG_FILE"
    exit 1
fi

# ==========================================================================
#  5. Create latest symlink
# ==========================================================================

rm -f "${OUTPUT_DIR}/latest"
ln -sf "$(basename "$REPORT_DIR")" "${OUTPUT_DIR}/latest"

# ==========================================================================
#  6. Summary
# ==========================================================================

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Schema documentation generated!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  Report:  ${REPORT_DIR}/index.html"
echo "  Latest:  ${OUTPUT_DIR}/latest/index.html"
echo "  Log:     ${LOG_FILE}"
echo ""

# Open in browser if running locally
if [ -z "$GITHUB_ACTIONS" ]; then
    echo -e "${BLUE}Opening in browser...${NC}"
    if command -v xdg-open &>/dev/null; then
        xdg-open "${REPORT_DIR}/index.html" 2>/dev/null || true
    elif command -v open &>/dev/null; then
        open "${REPORT_DIR}/index.html" 2>/dev/null || true
    fi
fi
