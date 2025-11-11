This document details the methods for deploying, updating, and managing the DCS, with a strong focus on minimizing downtime, ensuring data integrity

The overall deployment process follows a standard CI/CD pipeline, adapted for on-premises delivery:

Code Commit/PR Merge: Developer commits code to main branch or merges a Pull Request.

CI/CD Trigger (GitHub Actions): Initiates the deploy.yml workflow.

Build & Test:
Linting, unit tests, integration tests.
Docker image build.
Vulnerability scanning (Trivy).
Push to Docker Registry (internal or external, depending on client setup).
Image is tagged with semver and SHA.

Staging Deployment:
Automatic deployment to the internal Staging environment (on a VM resembling client infra).

Smoke tests run against Staging.

Manual Approval (Production):

For production deployments, a manual approval step is required (via workflow_dispatch trigger).
Stakeholders (e.g., product owners, security team) review and approve the release.
Secure Transfer to On-Premises:
If air-gapped, the approved Docker images and deployment manifests are securely transferred to the client's internal registry or pre-loaded onto the VM.
For connected environments, direct pull from the SaaS-controlled registry is possible.

Production Deployment (On-Premises):

Triggered via SSH from GitHub Actions, executing the setup-environment.sh script on the target Host VM.
The script pulls the specified Docker image(s) and deploys using Docker Compose.

Health checks and post-deployment smoke tests are performed.

Validation & Monitoring: Continuous monitoring of the deployed service.

Impact: Zero downtime (as it's a new deployment).

Recovery: If initial deployment fails, the VM can be reprovisioned from scratch using Terraform.

--------------------------------------------------------------------------
Deployment Artifacts

docker-compose.yml: 
  Defines the multi-container application stack, including service definitions, environment variables, volumes, networks, and health checks. This is versioned in Git.

setup-environment.sh: 
  The main bash script executed on the on-premises Host VM. It handles pre-flight checks, environment configuration, pulling Docker images, and orchestrating docker compose commands. This is versioned in Git.


Database Initialization Scripts: 
  (db_init/init.sql) SQL scripts for initial database schema setup or migrations. (Note: Alembic is preferred for proper migrations in the long run). Versioned in Git.

Terraform Configuration Files: 
  (main.tf, variables.tf, data.tf) Used to provision and configure the underlying Host VM on vSphere/Hyper-V, ensuring infrastructure consistency.

------------------------------------------------------------------------------

Staging Environment Updates (Rolling Update)
Updates to the internal staging environment utilize a simple rolling update approach via docker compose up -d.

Process:
Build & Push: New Docker images are built and pushed to the registry by the CI/CD pipeline.
Trigger Deployment: GitHub Actions automatically connects to the Staging Host VM.
Execute Script: setup-environment.sh --deploy --environment staging is executed.
docker compose up -d: Docker Compose pulls the new images (if newer), stops old containers, and starts new ones. Containers are restarted one by one or in dependency order.
Health Check & Smoke Test: Services are validated as healthy before the deployment is considered complete.
Impact: Brief downtime per service during container replacement, typically seconds. Minimal risk in staging.
Recovery: If deployment fails, docker compose restart to retry, or docker compose up -d --force-recreate with the previous image tag.



Production Environment Updates (Blue/Green)
For production environments in client on-premises, a Blue/Green deployment strategy is implemented to achieve zero-downtime updates and provide an instant rollback mechanism. This requires two identical Host VMs for the DCS, designated as "Blue" and "Green," with a traffic management component (e.g., client's load balancer, DNS, or firewall VIP) directing traffic.

Prerequisites:

Two identical Host VMs configured for the DCS (e.g., dcs-prod-blue, dcs-prod-green).
A client-managed traffic routing mechanism (Load Balancer, DNS, firewall VIP) capable of switching traffic between the two VMs.
Separate IP addresses for Blue and Green environments, with a single CNAME/VIP pointing to the active one.

Process (Example: Deploying to Green):

Active (Blue) Environment: The currently running DCS instance (e.g., dcs-prod-blue) is serving all production traffic.
Provision/Update Inactive (Green) Environment:
GitHub Actions triggers the production deployment, targeting the inactive dcs-prod-green VM.
The setup-environment.sh --deploy --environment production --strategy green script is executed on dcs-prod-green.
This script pulls the new Docker images and deploys the entire DCS stack using Docker Compose on dcs-prod-green.
Database Migrations: Any necessary database schema migrations are run only on the Green environment's database. These must be backward-compatible with the Blue environment's application code.

Health Checks: Thorough health checks are performed on the newly deployed dcs-prod-green to ensure all services are healthy and functional.

Pre-Switch Validation: Extensive automated tests (smoke tests, sanity checks) are run against dcs-prod-green directly (e.g., via a separate internal testing IP or network path), before any production traffic is routed.

------------------------------------------------------------------------------

Rollback Strategy
Rollback mechanisms are an integral part of each deployment strategy.

Staging Rollback: If a rolling update fails in staging, the docker compose command can be executed with the previous successful image tag: docker compose -f /opt/data-collection-service/docker-compose.yml pull <previous_image_tag> docker compose -f /opt/data-collection-service/docker-compose.yml up -d --force-recreate
Production (Blue/Green) Rollback: This is the most robust rollback.

If issues are detected after the traffic switch to "Green," the traffic management system is immediately switched back to the old "Blue" environment. This is typically a very fast operation (seconds).
The "Blue" environment remains operational with the previous stable version.
Root cause analysis is performed on "Green" without impacting production users.

Emergency Rollback (VM Level): In catastrophic scenarios, the Host VM can be reverted to a previous snapshot (if available and recent) by client IT. This is a last resort due to potential data loss or inconsistency.

-----------------------------------------------------------------------------

Pre-Deployment & Post-Deployment Checks
To ensure successful deployments, a rigorous set of checks is performed at various stages.

Pre-Deployment Checks (setup-environment.sh responsibility):
Host Health: Verify VM CPU, Memory, Disk space, and network connectivity.

Docker Daemon: Ensure Docker daemon is running and healthy.
Dependencies: Confirm docker-compose, curl, jq (if used) are installed.
Network Reachability: Verify the Host VM can reach internal client data sources (DBs, APIs, file shares) and, if applicable, the Data Transfer Gateway.
Firewall Rules: Confirm necessary inbound/outbound firewall rules are in place on the Host VM and client network.
Secrets Availability: Ensure required environment variables or mounted Docker secrets are accessible.
Image Availability: Confirm the new Docker images are available in the target registry or pre-loaded.
Post-Deployment Checks (CI/CD & setup-environment.sh responsibility):
Docker Compose Status: docker compose ps shows all services running and healthy.

Service Health Endpoint: curl -f http://localhost:8000/health (from Nginx) returns 200 OK.
Application Logs: Review docker compose logs app for any critical errors or warnings during startup.

Connectivity:

Test connectivity to PostgreSQL from the app container.
Test connectivity to Redis from the app container.

Smoke Tests:

Trigger Sample Job: curl -X POST /api/v1/jobs/trigger with a simple, known-good configuration.
Check Job Status: curl /api/v1/jobs/status/{job_id} to confirm job is PENDING or RUNNING.
Check Job Result: curl /api/v1/jobs/result/{job_id} once the job is COMPLETED (requires a worker to process, possibly simulated for smoke tests).
External Integration (Data Transfer): For production, verify the Data Transfer Gateway logs show successful egress of data.

