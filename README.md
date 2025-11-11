# Infra-DevOps-Project
This project is for self learning and evaluation where it will help to create a infrastructure and manage it with the tools such as github repository. we will have various sub repository which will contain the infrastructure as a Code, configiration file and various infra services file.

 **The GitHub Repository Structure:**
   ```
   ├── .github/
   │   └── workflows/
   │       └── deploy.yml
   ├── app/
   │   ├── main.py
   │   └── requirements.txt
   ├── scripts/
   │   └── setup-environment.sh
   ├── docs/
   │   ├── ARCHITECTURE.md
   │   ├── DOCKER_SECURITY.md
   │   ├── DEPLOYMENT_STRATEGY.md
   │   └── TROUBLESHOOTING.md
   ├── Dockerfile
   |── requirement.txt
   ├── docker-compose.yml
   └── README.md
   ```

Docker File -
Multi-stage Build: We use 2 stage first is to build with base image of python 3.11 and integrate it with dependencies into a virtual environment (.venv). This stage is optimized for caching known as Builder stage. Second is Final stage use to copies the built virtual environment and the application code reducing the size of image and implementing all the required libraries only where build tools and dev dependencies are excluded.

Note - OCI (Open Container Initiative) compliant labels are added for better metadata and discoverability.


