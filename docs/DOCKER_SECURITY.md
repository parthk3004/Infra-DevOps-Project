This document outlines the security measures and best practices implemented for the Dockerized Data Collection Service

Guiding Principles

Least Privilege: Grant only the minimum necessary permissions for containers, users, and processes.
Defense in Depth: Implement multiple layers of security controls, so if one fails, others can still protect the system.
Minimize Attack Surface: Reduce the number of components, open ports, and unnecessary features.
Automation: Automate security checks and deployments to ensure consistency and prevent manual errors.
Visibility: Implement robust logging and monitoring to detect and respond to security incidents.
Immutability: Treat containers as immutable, ensuring that once built, they are not modified at runtime.

Minimal Base Images - ( we are using python slim and also multi stage to reduce image size at run time)
Practice: Utilize minimal base images such as Alpine Linux or slim variants (e.g., python:3.11-slim-buster, nginx:alpine, postgres:alpine, redis:alpine).

Benefit: Reduces the image size, decreases the number of installed packages, and significantly lowers the potential attack surface by removing unnecessary binaries and libraries that could harbor vulnerabilities.


Practice: 
All application containers (FastAPI app, Nginx, PostgreSQL, Redis) run with a dedicated non-root user (e.g., appuser, nginx, postgres, redis) and group within the container.
Pin all dependencies to specific versions in requirements.txt (Python) or equivalent for other services.
Integrate automated vulnerability scanning tools (e.g., Trivy, Snyk) into the CI/CD pipeline.
Scan both OS packages and application language dependencies (e.g., Python packages).
Regularly update dependencies to patch known vulnerabilities.
Utilize Docker Content Trust (Notary) or an equivalent solution to sign Docker images and verify their authenticity before pulling and running them.
Implement multi-stage builds in Dockerfiles.
Never embed sensitive information (credentials, API keys, private keys, certificates) directly into Docker images.
Securing containers at runtime is crucial to prevent escape attempts and unauthorized access.
Define CPU and memory limits for each container in docker-compose.yml (deploy.resources.limits).
Utilize Docker Secrets for sensitive information (database credentials, API keys for client sources, etc.).
Secrets are injected as files into the container's filesystem, accessible only by the intended process, rather than as environment variables (which can be leaked via /proc/).
Configure all containers to output structured logs (JSON) to stdout/stderr.
Utilize Docker's json-file logging driver.
Deploy the Host VM using a hardened Linux OS image (e.g., Ubuntu Server, RHEL). This includes:
Minimal installation (remove unnecessary packages).
    Regular patching and updates.
    Disabling unused services.
    Implementing a strong host firewall (e.g., ufw, firewalld).
    Enabling SELinux/AppArmor
Configure host-level firewalls
Configure auditd on the Host OS to log critical system calls and file access events.
Ensure journald (or rsyslog) collects Docker daemon logs and other system logs.
Forward host logs to the central monitoring solution.

-------------------------------------------------------------------------

Deployment & Update Security
Secure deployment practices are essential to maintain the integrity of the system throughout its lifecycle.

Secure CI/CD Pipeline
Practice:
Implement strong access controls for the CI/CD platform (GitHub Actions).
Use temporary, role-based credentials for accessing registries and deploying to VMs.
Scan code for security vulnerabilities (SAST) and secrets (secret scanning).
Enforce image signing and verification in the pipeline.

Benefit: Prevents unauthorized changes or malicious injection into the deployment process

--------------------------------------------------------------------------

Regular Audits & Reviews
Practice:
Conduct regular security audits of Dockerfiles, docker-compose.yml configurations, and the Host VM setup.
Perform penetration testing and vulnerability assessments (external and internal) on the deployed system.
Review access logs and security alerts regularly.

Benefit: Continuously identifies and addresses emerging threats and ensures ongoing compliance with security policies.

