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
CYAN='\033[0;36m'
BOLD='\033[1m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ==========================================================================
#  Progress bar & helpers
# ==========================================================================

TOTAL_STEPS=5
CURRENT_STEP=0
STEP_START=0

progress_init() {
    CURRENT_STEP=0
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Schema Capture — PostgreSQL Schema Docs            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

progress_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    STEP_START=$(date +%s)
    local msg="$1"
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    local bar_width=20
    local filled=$(( pct * bar_width / 100 ))
    local empty=$(( bar_width - filled ))

    printf "  ${CYAN}[%d/%d]${NC} [${BOLD}" "$CURRENT_STEP" "$TOTAL_STEPS"
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "${NC}] ${BOLD}%3d%%${NC}  %s\n" "$pct" "$msg"
}

progress_ok() {
    local elapsed=$(($(date +%s) - STEP_START))
    printf "        ${GREEN}✓${NC} Done in ${elapsed}s\n"
}

progress_info() {
    printf "        ${CYAN}ℹ${NC} %s\n" "$1"
}

# Live spinner & timer for SchemaSpy execution
run_schemaspy() {
    local log_file="$1"
    shift
    local start_ts=$(date +%s)
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    local last_line_len=0

    # Run SchemaSpy in background, output direct to log only
    "$@" >> "$log_file" 2>&1 &
    local pid=$!

    # Live spinner while SchemaSpy runs
    while kill -0 $pid 2>/dev/null; do
        local elapsed=$(($(date +%s) - start_ts))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        i=$(( (i + 1) % 10 ))
        printf "\r  ${CYAN}%s${NC}  Generating schema docs...  ${BOLD}%02d:%02d${NC}" "${spin[$i]}" "$mins" "$secs"
        sleep 0.3
    done

    # Clear spinner line
    printf "\r%${last_line_len}s\r" ""

    wait $pid
    local rc=$?

    # Check log for summary line
    local table_count=$(grep -oP 'relationships? of \K[0-9]+' "$log_file" 2>/dev/null | tail -1)
    local total_elapsed=$(($(date +%s) - start_ts))
    local mins=$((total_elapsed / 60))
    local secs=$((total_elapsed % 60))

    if [ $rc -eq 0 ]; then
        if [ -n "$table_count" ]; then
            printf "        ${GREEN}✓${NC}  ${table_count} tables documented in ${BOLD}%02d:%02d${NC}\n" "$mins" "$secs"
        else
            printf "        ${GREEN}✓${NC}  SchemaSpy completed in ${BOLD}%02d:%02d${NC}\n" "$mins" "$secs"
        fi
    else
        printf "        ${RED}✘${NC}  SchemaSpy failed after ${BOLD}%02d:%02d${NC}\n" "$mins" "$secs"
    fi

    return $rc
}

# ==========================================================================
#  Main execution
# ==========================================================================

progress_init

# ------------------------------------------------------------------
#  Step 1/5 — Load configuration
# ------------------------------------------------------------------

progress_step "Loading configuration"

if [ -z "$GITHUB_ACTIONS" ]; then
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
        progress_info "Loaded .env"
    else
        echo -e "${YELLOW}No .env found. Copy .env.example to .env and fill in your credentials.${NC}"
        exit 1
    fi
fi

for var in DB_HOST DB_PORT DB_NAME DB_USER DB_PASS; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}ERROR: $var is not set.${NC}"
        exit 1
    fi
done

SCHEMASPY_VERSION="${SCHEMASPY_VERSION:-6.2.4}"
SCHEMASPY_JAR="schemaspy-${SCHEMASPY_VERSION}.jar"
JDBC_JAR="postgresql-42.7.3.jar"

BASE_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
OUTPUT_DIR="${BASE_DIR}/generated"
LOG_FILE="${OUTPUT_DIR}/schemaspy.log"

mkdir -p "$OUTPUT_DIR"
progress_info "Output → ${OUTPUT_DIR}"
progress_ok

# ------------------------------------------------------------------
#  Step 2/5 — Ensure Java is available
# ------------------------------------------------------------------

progress_step "Preparing Java runtime"

JAVA_BIN=""

if command -v java &>/dev/null; then
    JAVA_BIN="java"
    progress_info "System Java: $(java -version 2>&1 | head -1)"
elif [ -f "${BASE_DIR}/jdk/bin/java" ]; then
    JAVA_BIN="${BASE_DIR}/jdk/bin/java"
    progress_info "Using cached portable JRE 11"
else
    progress_info "Downloading portable JRE 11 (~30 MB)..."
    JDK_URL="https://api.adoptium.net/v3/binary/latest/11/ga/linux/x64/jre/hotspot/normal/eclipse"
    mkdir -p "${BASE_DIR}/jdk"
    curl -# -o "${BASE_DIR}/jdk.tar.gz" "$JDK_URL"
    tar -xzf "${BASE_DIR}/jdk.tar.gz" -C "${BASE_DIR}/jdk" --strip-components=1
    rm -f "${BASE_DIR}/jdk.tar.gz"
    JAVA_BIN="${BASE_DIR}/jdk/bin/java"
    progress_info "Portable JRE 11 ready"
fi

cd "$BASE_DIR"
progress_ok

# ------------------------------------------------------------------
#  Step 3/5 — Check dependencies (SchemaSpy JAR + JDBC driver)
# ------------------------------------------------------------------

progress_step "Checking dependencies"

if [ ! -f "$SCHEMASPY_JAR" ]; then
    progress_info "Downloading SchemaSpy ${SCHEMASPY_VERSION}..."
    curl -# -L -o "$SCHEMASPY_JAR" \
        "https://github.com/schemaspy/schemaspy/releases/download/v${SCHEMASPY_VERSION}/schemaspy-${SCHEMASPY_VERSION}.jar"
else
    progress_info "SchemaSpy JAR ✓"
fi

if [ ! -f "$JDBC_JAR" ]; then
    progress_info "Downloading PostgreSQL JDBC driver..."
    curl -# -L -o "$JDBC_JAR" \
        "https://jdbc.postgresql.org/download/postgresql-42.7.3.jar"
else
    progress_info "JDBC driver ✓"
fi

if ! command -v dot &>/dev/null; then
    progress_info "Installing Graphviz..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq graphviz
    elif command -v brew &>/dev/null; then
        brew install graphviz
    else
        echo -e "${RED}Please install Graphviz manually: https://graphviz.org/download/${NC}"
        exit 1
    fi
else
    progress_info "Graphviz ✓"
fi

progress_ok

# ------------------------------------------------------------------
#  Step 4/5 — Run SchemaSpy
# ------------------------------------------------------------------

progress_step "Generating schema documentation"

TIMESTAMP=$(date +"%Y-%m-%d-%H%M")
REPORT_DIR="${OUTPUT_DIR}/${TIMESTAMP}"
mkdir -p "$REPORT_DIR"
progress_info "Host: ${DB_HOST}:${DB_PORT}  DB: ${DB_NAME}"
progress_info "Output: ${REPORT_DIR}/"

echo ""
run_schemaspy "$LOG_FILE" \
    "$JAVA_BIN" -jar "$SCHEMASPY_JAR" \
    -t pgsql \
    -dp "$JDBC_JAR" \
    -host "$DB_HOST" \
    -port "$DB_PORT" \
    -db "$DB_NAME" \
    -u "$DB_USER" \
    -p "$DB_PASS" \
    -s public \
    -o "$REPORT_DIR"
_SCHEMASPY_EXIT=$?
echo ""

if [ $_SCHEMASPY_EXIT -ne 0 ]; then
    echo -e "${RED}✗ SchemaSpy failed. Check log: $LOG_FILE${NC}"
    tail -20 "$LOG_FILE"
    exit 1
fi

progress_ok

# ------------------------------------------------------------------
#  Step 5/5 — Create symlink & summary
# ------------------------------------------------------------------

progress_step "Finalizing"

rm -f "${OUTPUT_DIR}/latest"
ln -sf "$(basename "$REPORT_DIR")" "${OUTPUT_DIR}/latest"

progress_info "Report:  ${REPORT_DIR}/index.html"
progress_info "Latest:  ${OUTPUT_DIR}/latest/index.html"
progress_info "Log:     ${LOG_FILE}"
progress_ok

# ==========================================================================
#  Done
# ==========================================================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Schema documentation generated successfully!     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Open:${NC}  ${REPORT_DIR}/index.html"
echo -e "  ${BOLD}Latest:${NC} ${OUTPUT_DIR}/latest/index.html"
echo ""

# Open in browser if running locally
if [ -z "$GITHUB_ACTIONS" ]; then
    if command -v xdg-open &>/dev/null; then
        xdg-open "${REPORT_DIR}/index.html" 2>/dev/null || true
    elif command -v open &>/dev/null; then
        open "${REPORT_DIR}/index.html" 2>/dev/null || true
    fi
fi
