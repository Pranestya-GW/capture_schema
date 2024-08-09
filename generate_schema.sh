#!/bin/bash

# Define variables
SCHEMASPY_JAR="${GITHUB_WORKSPACE}/schemaspy-6.2.4.jar"
JDBC_DRIVER="${GITHUB_WORKSPACE}/postgresql.jar"
BASE_OUTPUT_DIR="${GITHUB_WORKSPACE}/generated"
LOG_FILE="${GITHUB_WORKSPACE}/schemaspy.log"

# Define database connection parameters
DB_HOST="aws-0-ap-southeast-1.pooler.supabase.com"
DB_PORT="6543"
DB_NAME="postgres"
DB_USER="postgres.rssagmjvvmvlxalvgdbk"
DB_PASS="krylliac123"

# Test database connection
echo "Testing database connection..."
if ! psql -h $DB_HOST -p $DB_PORT -d $DB_NAME -U $DB_USER -c '\q'; then
    echo "Failed to connect to the database. Please check your credentials and network connection." >> $LOG_FILE
    exit 1
fi

echo "Database connection successful."

# Ensure output directory exists
mkdir -p $BASE_OUTPUT_DIR

# Rotate old backups to keep only the last 7
cd $BASE_OUTPUT_DIR

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
mkdir -p $NEW_OUTPUT_DIR

# Run SchemaSpy with hardcoded credentials
java -jar $SCHEMASPY_JAR -t pgsql -dp $JDBC_DRIVER -host $DB_HOST -port $DB_PORT -db $DB_NAME -u $DB_USER -p $DB_PASS -s public -o $NEW_OUTPUT_DIR > $LOG_FILE 2>&1

# Check if SchemaSpy ran successfully
if [ $? -ne 0 ]; then
    echo "SchemaSpy failed to run" >> $LOG_FILE
    exit 1
fi

# Log successful completion
echo "SchemaSpy completed successfully at $(date +"%Y-%m-%d %H:%M:%S")" >> $LOG_FILE
