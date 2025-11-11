import os
import logging
import request # to handle request
import uuid
from typing import Dict, Any, Optional
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, status, Request
from pydantic import BaseModel, Field
from sqlalchemy import create_engine, Column, String, DateTime, Text, JSON
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.exc import SQLAlchemyError
import json # For structured logging

# --- Configuration ---
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@db:5432/datacollection")

# --- Logging Setup ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("data_collection_service")
class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "timestamp": datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat(),
            "level": record.levelname,
            "name": record.name,
            "message": record.getMessage(),
            "file": f"{record.filename}:{record.lineno}",
            "func": record.funcName,
            "extra": record.__dict__.get('extra', {})
        }
        if hasattr(record, 'request_id'):
            log_record['request_id'] = record.request_id
        if record.exc_info:
            log_record['exc_info'] = self.formatException(record.exc_info)
        return json.dumps(log_record)

# Logger formatter handling
handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logger.handlers = [] # Clear existing handlers
logger.addHandler(handler)
logger.propagate = False

# --- Database Setup ---
Base = declarative_base()
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


# Database Models ( how data will look like)
class Job(Base):
    __tablename__ = "jobs"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    source_type = Column(String, nullable=False)
    status = Column(String, default="PENDING") # PENDING, RUNNING, COMPLETED, FAILED
    config = Column(JSON, nullable=False)
    result = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    error_message = Column(Text, nullable=True)

class SourceConfig(BaseModel):
    url: Optional[str] = None
    query: Optional[str] = None
    path: Optional[str] = None
    credentials_secret_name: Optional[str] = Field(
        None, description="Name of the secret containing credentials for the source."
    )
    db_connection_string_secret: Optional[str]
    api_key_secret: Optional[str]

class TriggerJobRequest(BaseModel):
    source_type: str = Field(..., description="Type of data source: api, database, file")
    config: SourceConfig = Field(..., description="Configuration details for the data source")

class JobStatusResponse(BaseModel):
    job_id: str
    status: str
    source_type: str
    created_at: datetime
    updated_at: datetime
    error_message: Optional[str] = None

class JobResultResponse(BaseModel):
    job_id: str
    status: str
    result: Optional[Dict[str, Any]] = None
    error_message: Optional[str] = None

# --- FastAPI Application ---
app = FastAPI(
    title="Data Collection Service API",
    description="API for triggering and managing data collection jobs from various client sources.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)


# Middleware for Request ID and Logging
@app.middleware("http")
async def add_request_id_middleware(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    extra_log_data = {'request_id': request_id}
    logger.info(f"Incoming request: {request.method} {request.url}", extra=extra_log_data)

    response = await call_next(request)

    response.headers["X-Request-ID"] = request_id
    logger.info(f"Outgoing response: {response.status_code}", extra=extra_log_data)
    return response

# --- Endpoints ---

@app.get("/health", summary="Health Check")
async def health_check():
    """
    Checks the health of the application.
    Returns 200 OK if the application is running.
    """
    try:
        # Check database connectivity
        db = SessionLocal()
        db.execute("SELECT 1")
        db.close()
        # Add Redis connectivity check here if Redis is critical for basic health
        return {"status": "ok", "database": "connected"}
    except SQLAlchemyError as e:
        logger.error(f"Database health check failed: {e}", exc_info=True, extra={'request_id': getattr(app.state, 'request_id', 'N/A')})
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Database connection failed: {e}"
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}", exc_info=True, extra={'request_id': getattr(app.state, 'request_id', 'N/A')})
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error during health check: {e}"
        )


@app.post("/api/v1/jobs/trigger", response_model=JobStatusResponse, status_code=status.HTTP_202_ACCEPTED)
async def trigger_data_collection_job(request_data: TriggerJobRequest):
    """
    Triggers a new data collection job based on the provided source configuration.
    """
    db = SessionLocal()
    request_id = getattr(app.state, 'request_id', 'N/A')
    try:

        new_job = Job(
            source_type=request_data.source_type,
            config=request_data.config.model_dump_json(exclude_none=True), # Store config as JSON
            status="PENDING" # Job is initially pending, will be picked up by a worker
        )
        db.add(new_job)
        db.commit()
        db.refresh(new_job)

        logger.info(f"Job {new_job.id} triggered for source type '{new_job.source_type}'.", extra={'job_id': new_job.id, 'request_id': request_id})

        return JobStatusResponse(
            job_id=new_job.id,
            status=new_job.status,
            source_type=new_job.source_type,
            created_at=new_job.created_at,
            updated_at=new_job.updated_at
        )
    except SQLAlchemyError as e:
        db.rollback()
        logger.error(f"Database error during job trigger: {e}", exc_info=True, extra={'request_id': request_id})
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create job due to database error: {e}"
        )
    except Exception as e:
        db.rollback() # Ensure rollback on any other error too
        logger.error(f"Unexpected error during job trigger: {e}", exc_info=True, extra={'request_id': request_id})
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}"
        )
    finally:
        db.close()


@app.get("/api/v1/jobs/status/{job_id}", response_model=JobStatusResponse)
async def get_job_status(job_id: str):
    """
    Retrieves the current status of a data collection job.
    """
    db = SessionLocal()
    request_id = getattr(app.state, 'request_id', 'N/A')
    try:
        job = db.query(Job).filter(Job.id == job_id).first()
        if not job:
            logger.warning(f"Job {job_id} not found.", extra={'job_id': job_id, 'request_id': request_id})
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")

        logger.info(f"Retrieved status for job {job_id}: {job.status}", extra={'job_id': job.id, 'request_id': request_id})
        return JobStatusResponse(
            job_id=job.id,
            status=job.status,
            source_type=job.source_type,
            created_at=job.created_at,
            updated_at=job.updated_at,
            error_message=job.error_message
        )
    except SQLAlchemyError as e:
        logger.error(f"Database error retrieving job status for {job_id}: {e}", exc_info=True, extra={'job_id': job_id, 'request_id': request_id})
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve job status due to database error: {e}"
        )
    finally:
        db.close()

@app.get("/api/v1/jobs/result/{job_id}", response_model=JobResultResponse)
async def get_job_result(job_id: str):
    """
    Retrieves the result of a completed data collection job.
    """
    db = SessionLocal()
    request_id = getattr(app.state, 'request_id', 'N/A')
    try:
        job = db.query(Job).filter(Job.id == job_id).first()
        if not job:
            logger.warning(f"Job {job_id} not found.", extra={'job_id': job_id, 'request_id': request_id})
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")

        if job.status != "COMPLETED":
            logger.info(f"Job {job_id} not yet completed (status: {job.status}).", extra={'job_id': job.id, 'request_id': request_id})
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Job {job_id} is not yet completed. Current status: {job.status}"
            )

        logger.info(f"Retrieved result for job {job_id}.", extra={'job_id': job.id, 'request_id': request_id})
        return JobResultResponse(
            job_id=job.id,
            status=job.status,
            result=job.result, # Result is a JSON field in DB
            error_message=job.error_message
        )
    except SQLAlchemyError as e:
        logger.error(f"Database error retrieving job result for {job_id}: {e}", exc_info=True, extra={'job_id': job_id, 'request_id': request_id})
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve job result due to database error: {e}"
        )
    finally:
        db.close()


async def _process_data_collection_job(job_id: str):
    db = SessionLocal()
    try:
        job = db.query(Job).filter(Job.id == job_id).first()
        if not job:
            logger.error(f"Worker: Job {job_id} not found for processing.", extra={'job_id': job_id})
            return

        job.status = "RUNNING"
        job.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(job)
        logger.info(f"Worker: Started processing job {job_id} for source '{job.source_type}'.", extra={'job_id': job_id})

        collected_data = {} #data collection based on source_type and config
        error_message = None

        if job.source_type == "api":
            try:
                response = requests.get(job.config.get("url"), timeout=30)
                response.raise_for_status()
                collected_data = response.json()
            except requests.exceptions.RequestException as e:
                error_message = f"API collection failed: {e}"
                logger.error(f"Worker: API collection failed for job {job_id}: {e}", exc_info=True, extra={'job_id': job_id})
            except Exception as e:
                error_message = f"API collection encountered unexpected error: {e}"
                logger.error(f"Worker: Unexpected API collection error for job {job_id}: {e}", exc_info=True, extra={'job_id': job_id})
        elif job.source_type == "database":
            collected_data = {"records_count": 100, "sample_data": [{"id": 1, "value": "test"}]}
            logger.info(f"Worker: Simulated database collection for job {job_id}.", extra={'job_id': job_id})
        elif job.source_type == "file":
            # Example: Read from a file path
            # This would require accessing a mounted volume or network share
            collected_data = {"file_name": job.config.get("path"), "lines_read": 50}
            logger.info(f"Worker: Simulated file collection for job {job_id}.", extra={'job_id': job_id})
        else:
            error_message = f"Unsupported source type: {job.source_type}"
            logger.error(f"Worker: Unsupported source type '{job.source_type}' for job {job_id}.", extra={'job_id': job_id})

        if error_message:
            job.status = "FAILED"
            job.error_message = error_message
        else:
            job.status = "COMPLETED"
            job.result = collected_data

        job.updated_at = datetime.now(timezone.utc)
        db.commit()
        logger.info(f"Worker: Job {job_id} finished with status '{job.status}'.", extra={'job_id': job_id})

    except SQLAlchemyError as e:
        db.rollback()
        job.status = "FAILED"
        job.error_message = f"Worker: Database error during job processing: {e}"
        db.commit()
        logger.error(f"Worker: Database error processing job {job_id}: {e}", exc_info=True, extra={'job_id': job_id})
    except Exception as e:
        db.rollback()
        job.status = "FAILED"
        job.error_message = f"Worker: An unexpected error occurred during job processing: {e}"
        db.commit()
        logger.error(f"Worker: Unexpected error processing job {job_id}: {e}", exc_info=True, extra={'job_id': job_id})
    finally:
        db.close()


