# Stage 1: Builder - Install dependencies use base image as per requirement

FROM python:3.11 AS builder
# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV PIP_NO_CACHE_DIR 1

WORKDIR /app

# Copy only the requirements file first
COPY requirements.txt .

# Install dependencies into a dedicated directory
RUN pip install --no-cache-dir --target /install -r requirements.txt

# ---
# Stage 2: Final - Build the production image
# Use 'slim-buster' image for the smallest footprint
FROM python:3.11-slim-buster AS final

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Create a non-root user and group
ARG UID=10001
RUN addgroup --gid $UID parthgroup && \
    adduser --uid $UID --ingroup parthgroup --shell /sbin/nologin --disabled-password --gecos "" appuser && \
    mkdir /app && chown appuser:parthgroup /app
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Copy the installed dependencies from the 'builder' stage
COPY --from=builder /install /usr/local/lib/python3.11/site-packages/

# Copy the application code
COPY app/ ./app/

# Expose the port the application listens on
EXPOSE 8000

# Set appropriate labels for versioning and metadata
LABEL org.opencontainers.image.title="Data Collection Service" \
      org.opencontainers.image.description="FastAPI application for compliance data collection" \
      org.opencontainers.image.version="1.0.1" \
      org.opencontainers.image.authors="Parth" \
      org.opencontainers.image.url="https://github.com/parthk3004/Infra-DevOps-Project/tree/main/app/data-collection-service" \
      org.opencontainers.image.source="https://github.com/parthk3004/Infra-DevOps-Project/tree/main/app/data-collection-service" \
      org.opencontainers.image.licenses="Proprietary"

# Run as myUser
USER appuser

# Healthcheck definition/ EntryPoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Command to run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
