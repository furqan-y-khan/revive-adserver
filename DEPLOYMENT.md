# Revive Adserver - Deployment Guide

Complete guide for deploying Revive Adserver to **Docker** (local) and **GCP Cloud Run** (production).

---

## Table of Contents

1. [Local Development with Docker](#local-development-with-docker)
2. [GCP Cloud Run Deployment](#gcp-cloud-run-deployment)
3. [Environment Variables](#environment-variables)
4. [Troubleshooting](#troubleshooting)

---

## Local Development with Docker

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed
- At least 4GB RAM available for Docker

### Quick Start

```bash
# Clone the repository (if not already done)
cd revive-adserver

# Build and start all services
docker-compose up --build

# Access the application
# Revive Adserver: http://localhost:8080
# PHPMyAdmin: http://localhost:8081
```

### Database Credentials (Local)

| Setting | Value |
|---------|-------|
| Host | `mysql` (or `localhost:3306` from host) |
| Database | `revive_adserver` |
| Username | `revive` |
| Password | `revive_password` |

### Stop Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (deletes database data)
docker-compose down -v
```

---

## GCP Cloud Run Deployment

### Prerequisites

1. [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed
2. A GCP project with billing enabled
3. Owner or Editor role on the project

### Step 1: Initial GCP Setup

```bash
# Login to GCP
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    sqladmin.googleapis.com \
    artifactregistry.googleapis.com \
    secretmanager.googleapis.com
```

### Step 2: Create Artifact Registry Repository

```bash
# Create Docker repository
gcloud artifacts repositories create revive-repo \
    --repository-format=docker \
    --location=us-central1 \
    --description="Revive Adserver Docker images"
```

### Step 3: Create Cloud SQL Instance

```bash
# Create MySQL 8.0 instance
gcloud sql instances create revive-db \
    --database-version=MYSQL_8_0 \
    --tier=db-f1-micro \
    --region=us-central1 \
    --root-password=YOUR_ROOT_PASSWORD \
    --storage-type=SSD \
    --storage-size=10GB

# Create database
gcloud sql databases create revive_adserver \
    --instance=revive-db

# Create user
gcloud sql users create revive \
    --instance=revive-db \
    --password=YOUR_DB_PASSWORD
```

### Step 4: Store Secrets in Secret Manager

```bash
# Create secrets for database credentials
echo -n "revive_adserver" | gcloud secrets create revive-db-name --data-file=-
echo -n "revive" | gcloud secrets create revive-db-user --data-file=-
echo -n "YOUR_DB_PASSWORD" | gcloud secrets create revive-db-password --data-file=-
```

### Step 5: Create Service Account

```bash
# Create service account
gcloud iam service-accounts create revive-sa \
    --display-name="Revive Adserver Service Account"

# Grant Cloud SQL Client role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:revive-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"

# Grant Secret Manager access
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:revive-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

### Step 6: Deploy with Cloud Build

```bash
# Deploy using Cloud Build
gcloud builds submit --config cloudbuild.yaml \
    --substitutions=_REGION=us-central1,_SERVICE_NAME=revive-adserver
```

### Step 7: Update Cloud Run with Cloud SQL Connection

```bash
# Get the Cloud SQL connection name
gcloud sql instances describe revive-db --format='value(connectionName)'

# Update the service to connect to Cloud SQL
gcloud run services update revive-adserver \
    --region=us-central1 \
    --add-cloudsql-instances=YOUR_PROJECT_ID:us-central1:revive-db \
    --set-env-vars="DB_HOST=/cloudsql/YOUR_PROJECT_ID:us-central1:revive-db" \
    --set-env-vars="DB_NAME=revive_adserver" \
    --set-env-vars="DB_USER=revive" \
    --set-env-vars="DB_PASSWORD=YOUR_DB_PASSWORD"
```

### Step 8: Get Your Cloud Run URL

```bash
# Get the service URL
gcloud run services describe revive-adserver \
    --region=us-central1 \
    --format='value(status.url)'
```

Visit the URL to complete the Revive Adserver installation wizard.

---

## Custom Domain (Optional)

```bash
# Map your domain to Cloud Run
gcloud run domain-mappings create \
    --service=revive-adserver \
    --domain=ads.yourdomain.com \
    --region=us-central1
```

Follow the DNS instructions provided by GCP.

---

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PORT` | Application port (default: 8080) | No |
| `DB_HOST` | Database host or Cloud SQL socket | Yes |
| `DB_PORT` | Database port (default: 3306) | No |
| `DB_NAME` | Database name | Yes |
| `DB_USER` | Database username | Yes |
| `DB_PASSWORD` | Database password | Yes |

---

## Troubleshooting

### Container won't start

```bash
# View Cloud Run logs
gcloud run services logs read revive-adserver --region=us-central1 --limit=50
```

### Database connection issues

1. Verify Cloud SQL instance is running:
   ```bash
   gcloud sql instances describe revive-db
   ```

2. Check the connection name format:
   ```
   /cloudsql/PROJECT_ID:REGION:INSTANCE_NAME
   ```

3. Ensure service account has `cloudsql.client` role

### Permission denied errors

Ensure the `var/` directory has proper permissions:
```bash
# In your Dockerfile, this is already set
chmod -R 777 /var/www/html/var
```

### Build fails

```bash
# View build logs
gcloud builds list --limit=5
gcloud builds log BUILD_ID
```

---

## Cost Optimization

- Cloud Run: Pay only for requests (free tier: 2M requests/month)
- Cloud SQL: Use `db-f1-micro` for dev/small sites (~$10/month)
- Consider using Cloud SQL automatic storage increase OFF for cost control

---

## Security Recommendations

1. **Use Secret Manager** for all credentials
2. **Enable Cloud Armor** for DDoS protection
3. **Set up Cloud CDN** for static assets
4. **Enable VPC connector** for private Cloud SQL access
5. **Use managed SSL certificates** (automatic with Cloud Run)
