#!/bin/bash

# Define variables
SCHEMASPY_JAR="${GITHUB_WORKSPACE}/schemaspy-6.2.4.jar"
JDBC_DRIVER="${GITHUB_WORKSPACE}/postgresql.jar"
BASE_OUTPUT_DIR="${GITHUB_WORKSPACE}/generated"
LOG_FILE="${GITHUB_WORKSPACE}/schemaspy.log"

# Use environment variables for database credentials
DB_HOST="${DB_HOST}"
DB_PORT="${DB_PORT}"
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASS}"

# Ensure output directory exists
mkdir -p $BASE_OUTPUT_DIR

# Rotate old backups to keep only the last 7
cd $BASE_OUTPUT_DIR
ls -dt */ | tail -n +7 | xargs rm -rf

# Generate new output directory with timestamp
TIMESTAMP=$(date +"%Y-%m-%d-%H:%M")
NEW_OUTPUT_DIR="${BASE_OUTPUT_DIR}/${TIMESTAMP}"
mkdir -p $NEW_OUTPUT_DIR

# Run SchemaSpy
java -jar $SCHEMASPY_JAR -t pgsql -dp $JDBC_DRIVER -host $DB_HOST -port $DB_PORT -db $DB_NAME -u $DB_USER -p $DB_PASSWORD -s public -o $NEW_OUTPUT_DIR > $LOG_FILE 2>&1

# Check if SchemaSpy ran successfully
if [ $? -ne 0 ]; then
    echo "SchemaSpy failed to run" >> $LOG_FILE
    exit 1
fi

# Log successful completion
echo "SchemaSpy completed successfully at $(date +"%Y-%m-%d %H:%M:%S")" >> $LOG_FILE
