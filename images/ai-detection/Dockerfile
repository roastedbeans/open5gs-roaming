# syntax=docker/dockerfile:1

# Use Python 3.11 slim image as base
FROM python:3.11-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV DEBIAN_FRONTEND=noninteractive

# Optimize Python for containers
ENV PYTHONHASHSEED=random
ENV PYTHONPATH=/app

# Limit CPU threads for better container performance (can be overridden)
ENV OMP_NUM_THREADS=1
ENV MKL_NUM_THREADS=1
ENV NUMEXPR_NUM_THREADS=1

# Set working directory
WORKDIR /app

# Install system dependencies for PyTorch and other libraries
RUN apt-get update && apt-get install -y \
    build-essential \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libgthread-2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY ai-detection/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy AI detection code and models
COPY ai-detection/ .

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash app

# Set proper permissions
RUN chmod +x api_server.py test_models.py performance.py entrypoint.sh && \
    chown -R app:app /app
USER app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "from handler import AIDetectionHandler; h = AIDetectionHandler(); print('healthy' if h.health_check().get('status') == 'healthy' else 'unhealthy')"

# Expose port for API server
EXPOSE 8000

# Default command - run API server
CMD ["python", "api_server.py"]

# Alternative commands (uncomment to use):
# CMD ["python", "test_models.py"]  # Run tests
