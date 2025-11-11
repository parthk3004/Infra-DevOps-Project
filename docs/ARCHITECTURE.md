The Architecture of this project is 2 - D architecture where we are crerating a docker image and launching it in VM containing python 3.11 base image and a function to fetch the request and store it in postgress SQL.

It will have a put/get/post/push request we validate it and store iyt in the db. Our architecture is using loggers to handle the logging and the stage of application, which help in troubleshooting the overall issue aries in the environment.

This document outlines the architectural design of the Data Collection Service (DCS), a new microservice component within the SaaS compliance automation platform. It details the high-level, low-level, and deployment architectures, focusing on its specific requirement for on-premises deployment within client environments


Goals:
Secure Data Collection: Reliably and securely collect data from diverse client on-premises sources (databases, APIs, file systems).
On-Premises Deployment: Designed for deployment on client-managed virtualization infrastructure (VMware, Hyper-V)
Scalability (Local): Able to handle varying data volumes and job frequencies within the client environment.
Security & Compliance: High emphasis on data protection, access control, auditing, and vulnerability management.

HLD -
![unnamed](https://github.com/user-attachments/assets/83016ab7-8a6d-471a-9cb4-8491d100ca81)


The DCS is deployed on a dedicated Virtual Machine (VM) provisioned on the client's existing virtualization platform (e.g., VMware vSphere, Microsoft Hyper-V).

Host VM: A Linux-based VM (e.g., Ubuntu, RHEL) running Docker Engine and Docker Compose. This VM acts as the host for all DCS containers.
Resource Allocation: VM resources (CPU, RAM, Storage) are allocated based on expected data volume and processing requirements, with the ability to scale vertically as needed.
Base Image: VMs are provisioned from a hardened, pre-approved client image, potentially pre-installed with Docker.
Orchestration: Docker Compose manages the lifecycle (start, stop, restart, health checks) of the multi-container DCS application stack.


Component                             Technology
Containerization	                    Docker
Container Orchestration	              Docker Compose
Application Framework	                FastAPI (Python)
Reverse Proxy                    	    Nginx
Database	                            PostgreSQL
ORM	                                  SQLAlchemy
Logging	                              Structured JSON Logs (Python logging + custom formatter)
CI/CD	                                GitHub Actions
Configuration Management      	      Bash Script (setup-environment.sh)
Infrastructure Provisioning     	    Terraform (for vSphere/Hyper-V)
Vulnerability Scanning	              Trivy


Maintenance:

Scheduled patching for Host OS and Docker.
Database maintenance (vacuuming, indexing).
Application updates via CI/CD pipeline.

Logging: 
Centralized JSON logging, critical for remote diagnosis. Log retention policies are defined.

Backup & Restore: 
PostgreSQL data volumes (dcs_pgdata) are backed up regularly (e.g., VM snapshots, logical backups).

Rollback Strategy: 
Defined procedures for reverting to a previous stable deployment version (e.g., via Blue/Green traffic switch, or redeploying a previous Docker image tag).


Troubleshooting: 
Comprehensive TROUBLESHOOTING.md (separate document) provides detailed runbooks and diagnostic steps.

