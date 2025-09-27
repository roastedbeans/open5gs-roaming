#!/usr/bin/env python3
"""
AI Detection API Server using FastAPI
Provides REST endpoints for intrusion detection
"""

import json
import logging
from typing import Dict, List, Any, Optional
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

from handler import AIDetectionHandler
from predict import AIDetector

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="AI Intrusion Detection System",
    description="Open5GS AI-based Network Intrusion Detection Service",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global handler instance
handler = None

# Pydantic models for request/response
class DetectionRequest(BaseModel):
    features: List[float] = Field(..., description="Network traffic features (76 values)")
    model_type: Optional[str] = Field("ensemble", description="Model type: cnn, mlp, rnn, lstm, gru, autoencoder, ensemble")

class BatchDetectionRequest(BaseModel):
    data: List[Dict[str, Any]] = Field(..., description="List of network traffic data with features")
    model_type: Optional[str] = Field("ensemble", description="Model type for all requests")

class HealthResponse(BaseModel):
    status: str
    message: str
    models_loaded: Optional[int] = None
    test_prediction: Optional[str] = None

class DetectionResponse(BaseModel):
    status: str
    prediction: str
    confidence: float
    probabilities: Dict[str, float]
    model_used: str
    threat_level: str
    recommendation: str

class BatchDetectionResponse(BaseModel):
    status: str
    results: List[Dict[str, Any]]

def initialize_handler():
    """Initialize the AI detection handler"""
    global handler
    if handler is None:
        try:
            handler = AIDetectionHandler()
            logger.info("AI Detection Handler initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize handler: {e}")
            raise

@app.on_event("startup")
async def startup_event():
    """Initialize handler on startup"""
    initialize_handler()

@app.get("/", tags=["General"])
async def root():
    """Root endpoint"""
    return {
        "message": "AI Intrusion Detection System API",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """Health check endpoint"""
    if handler is None:
        raise HTTPException(status_code=503, detail="Handler not initialized")

    try:
        health = handler.health_check()
        return HealthResponse(**health)
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=500, detail=f"Health check failed: {str(e)}")

@app.post("/detect", response_model=DetectionResponse, tags=["Detection"])
async def detect_intrusion(request: DetectionRequest):
    """Single intrusion detection endpoint"""
    if handler is None:
        raise HTTPException(status_code=503, detail="Handler not initialized")

    try:
        # Prepare data
        data = {"features": request.features}

        # Validate feature count
        if len(request.features) != 76:
            raise HTTPException(
                status_code=400,
                detail=f"Expected 76 features, got {len(request.features)}"
            )

        # Make prediction
        result = handler.detect_intrusion(data, model_type=request.model_type)

        if result.get("status") == "error":
            raise HTTPException(status_code=500, detail=result.get("error", "Detection failed"))

        return DetectionResponse(**result)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Detection failed: {e}")
        raise HTTPException(status_code=500, detail=f"Detection failed: {str(e)}")

@app.post("/detect/batch", response_model=BatchDetectionResponse, tags=["Detection"])
async def detect_intrusion_batch(request: BatchDetectionRequest):
    """Batch intrusion detection endpoint"""
    if handler is None:
        raise HTTPException(status_code=503, detail="Handler not initialized")

    try:
        # Validate all requests have correct feature count
        for i, data in enumerate(request.data):
            if "features" in data and len(data["features"]) != 76:
                raise HTTPException(
                    status_code=400,
                    detail=f"Request {i}: Expected 76 features, got {len(data['features'])}"
                )

        # Make batch predictions
        results = handler.batch_detect(request.data, model_type=request.model_type)

        return BatchDetectionResponse(status="success", results=results)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Batch detection failed: {e}")
        raise HTTPException(status_code=500, detail=f"Batch detection failed: {str(e)}")

@app.get("/models", tags=["Models"])
async def get_model_info():
    """Get information about available models"""
    if handler is None:
        raise HTTPException(status_code=503, detail="Handler not initialized")

    try:
        return handler.get_model_info()
    except Exception as e:
        logger.error(f"Failed to get model info: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get model info: {str(e)}")

@app.post("/benchmark", tags=["Benchmarking"])
async def run_benchmark(
    background_tasks: BackgroundTasks,
    num_iterations: int = 50,
    batch_size: int = 16
):
    """Run performance benchmarking (runs in background)"""
    from test_models import benchmark_models

    try:
        # Run benchmark in background
        results = benchmark_models(num_iterations=num_iterations, batch_size=batch_size)

        if results:
            return {
                "status": "success",
                "message": f"Benchmarking completed with {len(results)} models",
                "results": results
            }
        else:
            raise HTTPException(status_code=500, detail="Benchmarking failed")

    except Exception as e:
        logger.error(f"Benchmarking failed: {e}")
        raise HTTPException(status_code=500, detail=f"Benchmarking failed: {str(e)}")

if __name__ == "__main__":
    # Run the API server
    uvicorn.run(
        "api_server:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )
