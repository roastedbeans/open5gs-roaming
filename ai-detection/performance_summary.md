# AI Detection Models Performance Summary

## Comprehensive Performance Metrics

| Model | Size | Peak CPU (%) | Avg CPU (%) | Peak Memory (MB) | Avg Memory (MB) | Packet Count | Preprocess (ms) | Predict (ms) | End-to-End (ms) | Throughput (samp/sec) |
|-------|------|--------------|-------------|------------------|-----------------|--------------|-----------------|--------------|-----------------|---------------------|
| CNN | 304.9KB | 21.5 | 3.0 | 347.2 | 347.2 | 10 | 0.211 | 0.942 | 0.219 | 1595.8 |
| MLP | 82.7KB | 11.4 | 1.9 | 347.2 | 347.1 | 10 | 0.029 | 0.061 | 0.062 | 89345.1 |
| RNN | 198.8KB | 28.7 | 2.9 | 292.9 | 291.4 | 10 | 0.040 | 0.762 | 0.597 | 7367.2 |
| LSTM | 782.4KB | 40.0 | 4.5 | 300.9 | 300.9 | 10 | 0.043 | 1.595 | 1.515 | 2726.6 |
| GRU | 587.9KB | 42.9 | 4.5 | 301.0 | 301.0 | 10 | 0.037 | 1.459 | 1.385 | 3866.7 |
| AUTOENCODER | 155.3KB | 14.0 | 2.4 | 301.0 | 301.0 | 10 | 0.029 | 0.080 | 0.078 | 79880.1 |

## Detailed Statistics

### CNN Model

- **Model Size**: 304.9KB
- **Preprocessing Time**: 0.211ms ±0.793ms
- **Prediction Time**: 0.942ms ±3.602ms
- **End-to-End Time**: 0.219ms ±0.060ms
- **Throughput**: 1595.8 samples/sec
- **Batch Prediction Time**: 10.027ms ±0.608ms
- **Peak CPU Usage**: 21.5%
- **Average CPU Usage**: 3.0%
- **Peak Memory Usage**: 347.2 MB
- **Average Memory Usage**: 347.2 MB
- **Packet Count**: 10

### MLP Model

- **Model Size**: 82.7KB
- **Preprocessing Time**: 0.029ms ±0.005ms
- **Prediction Time**: 0.061ms ±0.005ms
- **End-to-End Time**: 0.062ms ±0.002ms
- **Throughput**: 89345.1 samples/sec
- **Batch Prediction Time**: 0.179ms ±0.007ms
- **Peak CPU Usage**: 11.4%
- **Average CPU Usage**: 1.9%
- **Peak Memory Usage**: 347.2 MB
- **Average Memory Usage**: 347.1 MB
- **Packet Count**: 10

### RNN Model

- **Model Size**: 198.8KB
- **Preprocessing Time**: 0.040ms ±0.021ms
- **Prediction Time**: 0.762ms ±0.780ms
- **End-to-End Time**: 0.597ms ±0.007ms
- **Throughput**: 7367.2 samples/sec
- **Batch Prediction Time**: 2.172ms ±0.333ms
- **Peak CPU Usage**: 28.7%
- **Average CPU Usage**: 2.9%
- **Peak Memory Usage**: 292.9 MB
- **Average Memory Usage**: 291.4 MB
- **Packet Count**: 10

### LSTM Model

- **Model Size**: 782.4KB
- **Preprocessing Time**: 0.043ms ±0.036ms
- **Prediction Time**: 1.595ms ±0.391ms
- **End-to-End Time**: 1.515ms ±0.013ms
- **Throughput**: 2726.6 samples/sec
- **Batch Prediction Time**: 5.868ms ±0.071ms
- **Peak CPU Usage**: 40.0%
- **Average CPU Usage**: 4.5%
- **Peak Memory Usage**: 300.9 MB
- **Average Memory Usage**: 300.9 MB
- **Packet Count**: 10

### GRU Model

- **Model Size**: 587.9KB
- **Preprocessing Time**: 0.037ms ±0.010ms
- **Prediction Time**: 1.459ms ±0.348ms
- **End-to-End Time**: 1.385ms ±0.022ms
- **Throughput**: 3866.7 samples/sec
- **Batch Prediction Time**: 4.138ms ±0.074ms
- **Peak CPU Usage**: 42.9%
- **Average CPU Usage**: 4.5%
- **Peak Memory Usage**: 301.0 MB
- **Average Memory Usage**: 301.0 MB
- **Packet Count**: 10

### AUTOENCODER Model

- **Model Size**: 155.3KB
- **Preprocessing Time**: 0.029ms ±0.003ms
- **Prediction Time**: 0.080ms ±0.007ms
- **End-to-End Time**: 0.078ms ±0.004ms
- **Throughput**: 79880.1 samples/sec
- **Batch Prediction Time**: 0.200ms ±0.007ms
- **Peak CPU Usage**: 14.0%
- **Average CPU Usage**: 2.4%
- **Peak Memory Usage**: 301.0 MB
- **Average Memory Usage**: 301.0 MB
- **Packet Count**: 10

