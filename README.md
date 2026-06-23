# Schema Capture — PostgreSQL Schema Documentation Generator

> Auto-generate beautiful HTML documentation of your PostgreSQL database schema using SchemaSpy. Run locally with one command or automate via GitHub Actions. Includes ER diagrams, table relationships, column details, and constraints.

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [What It Generates](#what-it-generates)
- [How It Works](#how-it-works)
- [Local Usage](#local-usage)
- [GitHub Actions Setup](#github-actions-setup)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [GitHub Secrets](#github-secrets)
- [Troubleshooting](#troubleshooting)

---

## Overview

Schema Capture uses [SchemaSpy](https://github.com/schemaspy/schemaspy) to analyze your PostgreSQL database and generate a static HTML site documenting every table, column, index, constraint, and relationship — complete with interactive ER diagrams powered by Graphviz.

```
┌──────────────────┐     ┌──────────────┐     ┌────────────────────┐
│  PostgreSQL DB    │────▶│  SchemaSpy   │────▶│  HTML Documentation │
│                  │     │  + Graphviz  │     │  • Table listings   │
│  Host: db.prod   │     │              │     │  • ER diagrams      │
│  Port: 5432      │     │  Java-based  │     │  • Column details   │
│  DB:   mydb      │     │  analysis    │     │  • FK relationships │
└──────────────────┘     └──────────────┘     │  • Indexes          │
                                               │  • Constraints      │
                                               └────────────────────┘
```

### Why Use This?

| Problem | Solution |
|---------|----------|
| No up-to-date schema docs | Auto-generated on every push to main |
| Manual documentation is stale | Fresh every Monday + on-demand triggers |
| Hard to visualize relationships | Interactive ER diagrams auto-generated |
| Onboarding new devs takes time | Self-contained HTML docs they can browse |
| Multiple environments to document | Works against any PostgreSQL instance |

---

## Quick Start

### Prerequisites

- **Java JRE 11+** (`sudo apt install default-jre`)
- **Graphviz** (`sudo apt install graphviz`)
- **PostgreSQL database** to document
- **Bash** (Linux, macOS, or WSL)

### 1. Configure

```bash
cp .env.example .env
# Edit .env with your database credentials
```

### 2. Run

```bash
chmod +x generate_schema.sh
./generate_schema.sh
```

The script:
1. Loads credentials from `.env`
2. Downloads SchemaSpy + JDBC driver (if not present)
3. Connects to your database and generates docs
4. Opens the report in your browser

### 3. View

```bash
open generated/latest/index.html
# or
xdg-open generated/latest/index.html
```

---

## What It Generates

SchemaSpy produces a full HTML site. Key pages:

| Page | Content |
|------|---------|
| **Tables** | Alphabetical list with row counts, comments |
| **Relationships** | ER diagram showing all FK relationships |
| **Columns** | Every column with type, nullable, default, comments |
| **Constraints** | Primary keys, foreign keys, unique, check |
| **Indexes** | All indexes with column lists |
| **Anomalies** | Tables without PKs, implied relationships, null uniqueness |
| **Routines** | Stored procedures and functions |

### Sample ER Diagram

The generated diagram uses Graphviz to draw table relationships:

```
┌──────────┐       ┌──────────┐
│ customers │──────<│  orders  │
└──────────┘       └────┬─────┘
                         │
                   ┌─────┴─────┐
                   │ order_items│
                   └───────────┘
```

---

## How It Works

```
1. generate_schema.sh starts
   │
   ├── Loads .env (local) or GitHub Secrets (CI)
   │
   ├── Downloads SchemaSpy JAR + PostgreSQL JDBC driver
   │   (cached — only downloads once)
   │
   ├── Installs Graphviz if missing
   │
   ├── Runs SchemaSpy:
   │   java -jar schemaspy.jar
   │     -t pgsql              (database type)
   │     -host / -port / -db    (connection)
   │     -u / -p               (credentials)
   │     -s public             (schema)
   │     -o generated/YYYY-MM-DD-HHMM/
   │
   ├── Creates generated/latest → symlink to newest
   │
   └── Opens browser (local only)
```

---

## Local Usage

### One-time setup

```bash
git clone https://github.com/Pranestya-GW/capture_schema.git
cd capture_schema
cp .env.example .env
nano .env   # Fill in your database credentials
chmod +x generate_schema.sh
```

### Run manually

```bash
./generate_schema.sh
```

### Run on a schedule (cron)

```bash
# Daily at 6 AM
crontab -e
0 6 * * * cd /path/to/capture_schema && ./generate_schema.sh
```

### Document a different schema

```bash
# Edit generate_schema.sh line with -s public:
# Change -s public to -s your_schema
```

### Document multiple databases

```bash
# Create separate .env files
cp .env .env.prod
cp .env .env.staging

# Run with specific config
source .env.prod && ./generate_schema.sh
```

---

## GitHub Actions Setup

The included workflow auto-generates docs on every push to `main`, every Monday, or manually.

### 1. Add GitHub Secrets

Go to your repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret | Description |
|--------|-------------|
| `DB_HOST` | Database hostname/IP |
| `DB_PORT` | Database port (usually `5432`) |
| `DB_NAME` | Database name |
| `DB_USER` | Database user (read-only recommended) |
| `DB_PASS` | Database password |

### 2. Push to main

```bash
git add .
git commit -m "Initial schema capture setup"
git push origin main
```

### 3. View results

The workflow runs automatically. Generated docs appear in the `generated/` folder in your repo. View them via GitHub Pages:

1. **Settings** → **Pages** → **Source:** `Deploy from a branch`
2. **Branch:** `main` → folder: `/generated/latest`
3. **Save** → your docs are live at `https://<user>.github.io/capture_schema/`

### 4. Manual trigger

**Actions** → **Generate Database Schema Docs** → **Run workflow**

### Pipeline Schedule

| Trigger | Frequency |
|---------|-----------|
| Push to `main` | Every commit |
| Cron | Every Monday at 2 AM UTC |
| Manual | On-demand via GitHub UI |

---

## Project Structure

```
capture_schema/
├── README.md                        # This documentation
├── generate_schema.sh               # Main script (local + CI)
├── .env.example                     # Template for credentials
├── .gitignore                       # Ignores .env, JARs, generated/
│
├── .github/
│   └── workflows/
│       └── main.yml                 # GitHub Actions pipeline
│
└── generated/                       # Output directory
    ├── 2025-06-23-1430/             # Timestamped reports
    │   ├── index.html               # Main documentation page
    │   ├── tables/                  # Per-table detail pages
    │   ├── diagrams/                # ER diagrams (PNG)
    │   └── ...
    └── latest -> 2025-06-23-1430/   # Symlink to newest
```

> ⚠ `generated/` is gitignored locally but committed by CI. JARs are downloaded on-demand and never committed.

---

## Configuration

### `.env` Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | _(required)_ | Database name |
| `DB_USER` | _(required)_ | Database user (read-only is fine) |
| `DB_PASS` | _(required)_ | Database password |
| `SCHEMASPY_VERSION` | `6.2.4` | SchemaSpy version |

### Recommended: Read-Only User

For security, create a read-only PostgreSQL user for SchemaSpy:

```sql
CREATE USER schemaspy WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE mydb TO schemaspy;
GRANT USAGE ON SCHEMA public TO schemaspy;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO schemaspy;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO schemaspy;
```

---

## GitHub Secrets

| Secret | Required | Example |
|--------|----------|---------|
| `DB_HOST` | Yes | `db.example.com` |
| `DB_PORT` | Yes | `5432` |
| `DB_NAME` | Yes | `production_db` |
| `DB_USER` | Yes | `schemaspy_readonly` |
| `DB_PASS` | Yes | `s3cur3_p4ss` |

> 💡 Use a **read-only** database user for CI. Never use production admin credentials.

### Security Best Practices

- Rotate the DB password every 90 days
- Use an environment-specific read-only user
- Consider using GitHub Environment secrets for staging vs production
- Add IP allowlisting if your DB is behind a firewall (GitHub Actions IPs: `api.github.com/meta`)

---

## Troubleshooting

### SchemaSpy fails to connect

```bash
# Test connectivity first
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1"

# Check the log
cat generated/schemaspy.log
```

### Graphviz not found

```bash
sudo apt-get install -y graphviz   # Debian/Ubuntu
brew install graphviz               # macOS
```

### Java version error

SchemaSpy 6.x requires Java 11+. Check your version:

```bash
java -version
# Should show 11 or higher
```

### Empty schema output

SchemaSpy only documents tables in the specified schema. Ensure your tables are in the `public` schema (or change `-s public` in the script).

### GitHub Actions can't connect

- Verify the database is accessible from the internet (or use a self-hosted runner inside your network)
- Check GitHub Actions IP ranges if using a firewall
- Verify secrets are set correctly in repo settings

---

## License

MIT
