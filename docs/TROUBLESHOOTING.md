This document provides guidance for troubleshooting common issues encountered with the Data Collection Service (DCS) deployed on client on-premises infrastructure. It covers how to verify components, understand failure modes, and outlines a day-to-day playbook for operational support.

Initial Troubleshooting Steps (When an issue is detected):
Identify the Symptom: What is the user experiencing? (e.g., "Jobs aren't running," "I can't access the API," "No new data is showing up in the cloud").

Review Recent Changes:
Was there a recent deployment? If so, consider a rollback if the issue is critical.
Were any configuration changes applied?
Were there any changes on the client's side (e.g., firewall, network, data source credentials)?

Bottom-Up (Infrastructure first):
Is the Host VM healthy (resources, network)?
Is Docker daemon running?
Are all Docker Compose containers running and healthy? (docker compose ps)

Top-Down (User perspective):
Can you reach Nginx? (curl http://localhost/health)
Can Nginx reach the App? (Check Nginx logs for 502/503)
Can the App reach DB/Redis? (Check App logs for connection errors)
Can the App reach client data sources? (Check App logs for source-specific errors)
Is the Data Transfer Gateway working?


Examine Logs:

Start with the service logs most likely to be affected based on the symptom.
    docker compose logs -f <service_name> for real-time logs.

Search for ERROR, CRITICAL, WARNING keywords.
Look for correlation IDs (request_id, job_id) to trace requests or jobs.

check :
  docker logs <container_name> and docker inspect <container_name>

Test connectivity from the Host VM to client data sources (ping, telnet <host> <port>, curl).
Test connectivity between containers: docker exec -it <app_container_name> ping db (requires iputils-ping or similar in app container).


Steps to Start Troubleshooting:

Access: Attempt SSH to the VM. If unsuccessful, use the virtualization console (VMware vCenter, Hyper-V Manager).
Resource Usage:
top or htop: Check CPU and Memory usage. Identify any runaway processes.
df -h: Check disk space, especially / and /var/lib/docker.
free -h: Check free RAM.

Verify the Docker daemon is running.

sudo systemctl status docker
sudo journalctl -xe | grep docker    # Check Docker daemon logs for errors.
If Docker is down, try sudo systemctl start docker.
docker logs dcs_nginx

Network:
ping <client_data_source_ip>
ping <gateway_ip>
ncat ip
nc -v ip : port 
sudo ufw status

FastAPI Application (DCS App)
-----------------------------

Understanding Failure Modes:

Application Code Errors: Uncaught exceptions, logic bugs leading to 500 errors.
Dependency Issues: Cannot connect to PostgreSQL or Redis.
External Source Connectivity: Fails to connect to client databases, APIs, or file shares.
Resource Limits: Application process killed by OS/Docker due to exceeding configured CPU/Memory.


Steps -
docker compose ps app
docker compose ps db
docker compose logs -f app  # check error it is python db or connection error.
docker compose logs -f db

curl -f http://localhost:8000/health



------------------------------------------------------------------------------------------------

Validate and check the logs properly to identify the issue in order following top-down or bottom -up approach.


