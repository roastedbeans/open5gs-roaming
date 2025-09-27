# AI Detection Service

Docker container for Open5GS AI-based Network Intrusion Detection System.

## Overview

This service provides real-time network intrusion detection using multiple deep learning models:
- **CNN (1D)**: Convolutional Neural Network for spatial feature extraction
- **MLP**: Multi-Layer Perceptron for general classification
- **RNN**: Recurrent Neural Network for sequential patterns
- **LSTM**: Long Short-Term Memory for long-range dependencies
- **GRU**: Gated Recurrent Unit for efficient sequential modeling
- **Autoencoder**: Unsupervised anomaly detection

## Features

- 🚀 **REST API**: FastAPI-based HTTP endpoints
- 🧠 **Multi-Model**: Ensemble predictions across all models
- ⚡ **High Performance**: Optimized for real-time inference
- 📊 **Performance Monitoring**: Built-in benchmarking tools
- 🔍 **Health Checks**: Automatic service monitoring
- 🐳 **Docker Ready**: Containerized deployment

## System Requirements

### Minimum Requirements (Development/Testing)
- **CPU**: 1 core (2.0 GHz or equivalent)
- **RAM**: 512 MB
- **Storage**: 500 MB (for models and logs)
- **Network**: Basic internet connection for package downloads

### Recommended Requirements (Production)
- **CPU**: 4 cores (3.0 GHz or equivalent)
- **RAM**: 1 GB
- **Storage**: 1 GB (for models, logs, and performance data)
- **Network**: Stable network connection

### Resource Usage by Model

Based on comprehensive performance analysis:

| Model | Peak CPU Cores | Peak Memory | Throughput | Use Case |
|-------|----------------|-------------|------------|----------|
| **MLP** | ~0.01 cores (0.1%) | 290 MB | 77K samp/sec | Ultra-efficient, low-resource |
| **Autoencoder** | ~0.01 cores (0.1%) | 235 MB | 70K samp/sec | Efficient, minimal resources |
| **RNN** | ~0.01 cores (0.1%) | 278 MB | 7K samp/sec | Balanced performance |
| **GRU** | ~0.01 cores (0.1%) | 219 MB | 4K samp/sec | Memory-efficient |
| **CNN** | ~3 cores (293%) | 311 MB | 1K samp/sec | High-performance, resource intensive |
| **LSTM** | ~3 cores (294%) | 270 MB | 2K samp/sec | Complex sequences, resource intensive |

### Docker Resource Configurations

Choose the appropriate Docker Compose file based on your deployment scenario:

#### **Development/Testing** (`docker-compose.minimal.yaml`)
```yaml
cpus: '1.0'      # 1 CPU core
memory: 512M     # 512MB RAM
```
**Use Case**: Local development, unit testing, CI/CD pipelines

#### **Standard Deployment** (Commented in `docker-compose.yaml`)
```yaml
cpus: '4.0'      # 4 CPU cores
memory: 1G       # 1GB RAM
```
**Use Case**: Production deployment with moderate traffic

#### **High-Throughput** (Commented in `docker-compose.yaml`)
```yaml
cpus: '6.0'      # 6 CPU cores
memory: 2G       # 2GB RAM
```
**Use Case**: High-traffic production, concurrent processing

#### **How to Switch Configurations**
To use a different configuration:
1. Open `docker-compose.yaml`
2. Comment out the current `deploy:` section
3. Uncomment the desired alternative configuration
4. Run `docker-compose down && docker-compose up -d`

**Note**: The separate `docker-compose.minimal.yaml` and `docker-compose.production.yaml` files have been removed and their configurations are now available as commented alternatives in the main `docker-compose.yaml` file.

## Publishing to Docker Hub

To publish your own version of this image:

```bash
# Tag the image with your repository name
docker tag open5gs-ai-detection:latest YOUR_USERNAME/open5gs-ai-detection:latest

# Login to Docker Hub
docker login

# Push the image
docker push YOUR_USERNAME/open5gs-ai-detection:latest
```

Then update the `image:` field in `docker-compose.yaml` to use your published image.

**Current published image**: `vinch05/open5gs-ai-detection:latest`

## Kubernetes Deployment

For production deployment in the Open5GS roaming environment:

```bash
# Deploy to VPLMN namespace
./scripts/kubectl-deploy-ai-detection.sh

# Check deployment status
microk8s kubectl get pods -n vplmn -l app=ai-detection

# View logs
microk8s kubectl logs -n vplmn -l app=ai-detection

# Access the service
# Internal: http://ai-detection.vplmn:8000
# External (NodePort): http://<node-ip>:32000
```

The Kubernetes manifests are located in `k8s-roaming/vplmn/ai-detection/`.

## Quick Start

### Using Docker Compose

```bash
# Navigate to the compose directory
cd compose-files/ai-detection

# Start the service (using minimal config by default)
docker-compose up -d

# To use different resource configurations, edit docker-compose.yaml
# and uncomment the desired configuration section

# Check logs
docker-compose logs -f ai-detection

# Stop the service
docker-compose down
```

### Using Published Docker Image (Recommended)

```bash
# Pull and run the published image from Docker Hub
docker run -d \
  --name open5gs-ai-detection \
  -p 8000:8000 \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/performance_data:/app/performance_data \
  vinch05/open5gs-ai-detection:latest
```

### Using Docker Directly (Build Locally)

```bash
# Build the image locally
docker build -t open5gs-ai-detection -f images/ai-detection/Dockerfile ../../

# Run the container
docker run -d \
  --name ai-detection \
  -p 8000:8000 \
  open5gs-ai-detection
```

## API Endpoints

### Health Check
```bash
curl http://localhost:8000/health
```

### Single Detection
```bash
curl -X POST http://localhost:8000/detect \
  -H "Content-Type: application/json" \
  -d '{
    "features": [0.1, 0.2, ..., 76_values],
    "model_type": "ensemble"
  }'
```

### Batch Detection
```bash
curl -X POST http://localhost:8000/detect/batch \
  -H "Content-Type: application/json" \
  -d '{
    "data": [
      {"features": [0.1, 0.2, ..., 76_values]},
      {"features": [0.3, 0.4, ..., 76_values]}
    ],
    "model_type": "ensemble"
  }'
```

### Model Information
```bash
curl http://localhost:8000/models
```

## Configuration

### Environment Variables

- `PYTHONPATH`: Python path (default: `/app`)
- `AI_DETECTION_HOST`: Server host (default: `0.0.0.0`)
- `AI_DETECTION_PORT`: Server port (default: `8000`)

### Command Line Options

```bash
# Run API server (default)
docker-compose exec ai-detection ./entrypoint.sh --command server

# Run test suite
docker-compose exec ai-detection ./entrypoint.sh --test

# Run performance benchmarks
docker-compose exec ai-detection ./entrypoint.sh --benchmark
```

## Performance Benchmarks

The service includes built-in performance benchmarking:

```bash
# Run comprehensive benchmarks
docker-compose exec ai-detection ./entrypoint.sh --benchmark

# Or run directly
docker-compose exec ai-detection python test_models.py --benchmark
```

### Sample Performance Results

```
📊 Benchmarking CNN Model
--------------------------------------------------
  Model Size:       304.9KB
  Preprocessing:  0.10ms ±0.03ms
  Prediction:     0.21ms ±0.06ms
  End-to-End:     0.17ms ±0.03ms
  Batch (size 16): 13.14ms ±0.65ms
  Throughput:     1217.3 samples/sec

🏆 Best Performing Models:
  Fastest Preprocessing: AUTOENCODER
  Fastest Prediction: MLP
  Fastest End-to-End: MLP
  Highest Throughput: MLP
  Smallest Model: MLP (82.7KB)
```

## Model Architecture

### Input Format
All models expect **76 network traffic features** as input:
- Packet statistics, timing information, protocol features
- Standardized using scikit-learn StandardScaler
- Real-time preprocessing for inference

### Available Models

| Model | Architecture | Use Case | Size |
|-------|-------------|----------|------|
| **MLP** | 3 Dense layers (128→64→32→4) | General classification | 83KB |
| **CNN** | Conv1d blocks + Global Avg Pool | Spatial patterns | 305KB |
| **RNN** | Vanilla RNN (2 layers, 128 hidden) | Sequential patterns | 199KB |
| **LSTM** | LSTM (2 layers, 128 hidden) | Long dependencies | 782KB |
| **GRU** | GRU (2 layers, 128 hidden) | Efficient sequences | 588KB |
| **Autoencoder** | Encoder+Classifier+Decoder | Anomaly detection | 155KB |

## Integration with Open5GS

### Network Configuration

The service is designed to integrate with Open5GS network functions:

- **AMF**: Access and Mobility Management
- **SMF**: Session Management
- **UPF**: User Plane Function

### Data Flow

```
Network Traffic → Feature Extraction → AI Detection → Alert/Action
```

### API Integration Example

```python
import requests

# Single detection
response = requests.post('http://ai-detection:8000/detect', json={
    'features': network_features,
    'model_type': 'ensemble'
})

result = response.json()
if result['threat_level'] == 'high':
    # Trigger mitigation actions
    trigger_network_mitigation(result)
```

## Monitoring

### Health Checks

The container includes built-in health monitoring:

```bash
# Check container health
docker ps | grep ai-detection

# View health logs
docker-compose logs ai-detection | grep health
```

### Performance Monitoring

```bash
# Run performance benchmarks
docker-compose exec ai-detection ./entrypoint.sh --benchmark

# Monitor resource usage
docker stats open5gs-ai-detection
```

## Troubleshooting

### Common Issues

1. **Model Loading Errors**
   ```bash
   # Check if models are present
   docker-compose exec ai-detection ls -la models/
   ```

2. **Memory Issues**
   ```bash
   # Increase container memory limit
   docker-compose.yml:
   services:
     ai-detection:
       deploy:
         resources:
           limits:
             memory: 2G
   ```

3. **Port Conflicts**
   ```bash
   # Check if port 8000 is available
   netstat -tlnp | grep 8000
   ```

4. **Performance Issues**
   ```bash
   # Run benchmarks to diagnose
   docker-compose exec ai-detection ./entrypoint.sh --benchmark
   ```

### Logs

```bash
# View application logs
docker-compose logs -f ai-detection

# View specific time range
docker-compose logs --since "1h" ai-detection
```

## Development

### Building Custom Images

```bash
# Build with custom tag
docker build -t my-ai-detection -f images/ai-detection/Dockerfile .

# Build with different Python version
docker build --build-arg PYTHON_VERSION=3.10 -t ai-detection-py310 .
```

### Testing Locally

```bash
# Run tests before building
cd ai-detection
python test_models.py

# Run performance benchmarks
python test_models.py --benchmark

# Run performance monitoring with graphs
python monitor_performance.py
```

## Performance Monitoring

The service includes comprehensive performance monitoring that tracks CPU and memory usage during model inference.

### Generated Outputs

After running performance monitoring, you'll find:

1. **Individual Model Graphs** (`performance_data/`):
   - `{model}_performance.png` - CPU and memory usage over time for each model

2. **Combined Analysis** (`performance_data/`):
   - `combined_performance.png` - All models comparison with box plots

3. **Summary Table** (`performance_data/performance_summary.md`):
   - Markdown table with average CPU and memory usage per model

4. **Performance Table Image** (`performance_data/performance_table.png`):
   - A visual representation of the summary table.

### Usage Examples

```bash
# Run performance monitoring (generates graphs and table)
docker-compose exec ai-detection ./entrypoint.sh --monitor

# Or run directly
docker-compose exec ai-detection python monitor_performance.py
```

### Sample Performance Output

```
📈 Performance Summary (25 iterations)
==========================================================================================
Model        Size     Preprocess Predict    End-to-End   Throughput
--------------------------------------------------------------------------------
CNN          304.9KB      0.10ms     0.21ms       0.17ms     1217.3 samp/sec
MLP          82.7KB       0.04ms     0.08ms       0.08ms    88787.1 samp/sec
RNN          198.8KB      0.04ms     0.58ms       0.59ms     7107.9 samp/sec
LSTM         782.4KB      0.06ms     1.52ms       1.51ms     2599.1 samp/sec
GRU          587.9KB      0.05ms     1.42ms       1.41ms     3541.6 samp/sec
AUTOENCODER  155.3KB      0.03ms     0.09ms       0.10ms    76066.4 samp/sec

🏆 Best Performing Models:
  Fastest Preprocessing: AUTOENCODER
  Fastest Prediction: MLP
  Fastest End-to-End: MLP
  Highest Throughput: MLP
  Smallest Model: MLP (82.7KB)
```

## Security Considerations

- Container runs as non-root user
- Minimal base image (python:3.11-slim)
- No sensitive data in container
- Network isolation via Docker networks
- Health checks for automatic recovery

## License

This component is part of the Open5GS project.
