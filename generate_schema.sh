#!/bin/bash

# Define variables
SCHEMASPY_JAR="${GITHUB_WORKSPACE}/schemaspy-6.2.4.jar"
JDBC_DRIVER="${GITHUB_WORKSPACE}/postgresql.jar"
BASE_OUTPUT_DIR="${GITHUB_WORKSPACE}/generated"
LOG_FILE="${BASE_OUTPUT_DIR}/schemaspy.log"  # Log file location

# Define database connection parameters using GitHub Actions secrets
DB_HOST="${DB_HOST:-${{ secrets.DB_HOST }}}"
DB_PORT="${DB_PORT:-${{ secrets.DB_PORT }}}"
DB_NAME="${DB_NAME:-${{ secrets.DB_NAME }}}"
DB_USER="${DB_USER:-${{ secrets.DB_USER }}}"
DB_PASS="${DB_PASS:-${{ secrets.DB_PASS }}}"

# Set the PGPASSWORD environment variable using the repository variable
export PGPASSWORD="$DB_PASS"

# Create log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Test database connection
echo "Testing database connection..."
if ! psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -c '\q'; then
    echo "Failed to connect to the database. Please check your credentials and network connection." >> "$LOG_FILE"
    exit 1
fi

echo "Database connection successful."

# Ensure output directory exists
mkdir -p "$BASE_OUTPUT_DIR"

# Rotate old backups to keep only the last 7
cd "$BASE_OUTPUT_DIR"

# Check if any directories exist before rotating backups
if [ "$(ls -d */ 2>/dev/null)" ]; then
  # Rotate old backups if directories exist
  ls -dt */ | tail -n +8 | xargs rm -rf
else
  # Create the first backup directory
  echo "No directories found. Creating the first backup directory."
  TIMESTAMP=$(date +"%Y-%m-%d-%H:%M")
  mkdir -p "${BASE_OUTPUT_DIR}/${TIMESTAMP}"
fi

# Generate new output directory with timestamp
TIMESTAMP=$(date +"%Y-%m-%d-%H:%M")
NEW_OUTPUT_DIR="${BASE_OUTPUT_DIR}/${TIMESTAMP}"
mkdir -p "$NEW_OUTPUT_DIR"

# Run SchemaSpy with environment variables
java -jar "$SCHEMASPY_JAR" -t pgsql -dp "$JDBC_DRIVER" -host "$DB_HOST" -port "$DB_PORT" -db "$DB_NAME" -u "$DB_USER" -p "$DB_PASS" -s public -o "$NEW_OUTPUT_DIR" > "$LOG_FILE" 2>&1

# Check if SchemaSpy ran successfully
if [ $? -ne 0 ]; then
    echo "SchemaSpy failed to run" >> "$LOG_FILE"
    exit 1
fi

# Log successful completion
echo "SchemaSpy completed successfully at $(date +"%Y-%m-%d %H:%M:%S")" >> "$LOG_FILE"
