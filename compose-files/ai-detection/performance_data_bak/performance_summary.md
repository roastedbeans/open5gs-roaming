# AI Detection Models Performance Summary

## Comprehensive Performance Metrics

| Model | Size | Peak Sys CPU (%) | Peak Proc CPU (%) | Avg Sys CPU (%) | Avg Proc CPU (%) | Peak Memory (MB) | Avg Memory (MB) | Packet Count | Preprocess (ms) | Predict (ms) | End-to-End (ms) | Throughput (samp/sec) |
|-------|------|------------------|-------------------|-----------------|-----------------|------------------|-----------------|--------------|-----------------|--------------|-----------------|---------------------|
| CNN | 304.9KB | 76.5 | 9.9 | 5.7 | 0.4 | 402.2 | 402.1 | 67 | 0.070 | 0.747 | 0.586 | 6493.1 |
| MLP | 82.7KB | 68.7 | 9.9 | 4.0 | 0.3 | 402.5 | 402.5 | 67 | 0.038 | 0.316 | 0.245 | 47999.4 |
| RNN | 198.8KB | 79.9 | 9.9 | 9.2 | 0.2 | 402.8 | 402.6 | 67 | 0.060 | 6.092 | 5.125 | 2282.6 |
| LSTM | 782.4KB | 62.2 | 10.0 | 7.1 | 0.5 | 402.9 | 402.8 | 67 | 0.060 | 3.520 | 3.582 | 1178.3 |
| GRU | 587.9KB | 24.4 | 9.9 | 7.1 | 0.4 | 403.0 | 403.0 | 67 | 0.079 | 6.975 | 9.461 | 1482.7 |
| AUTOENCODER | 155.3KB | 86.6 | 9.9 | 5.6 | 0.4 | 403.3 | 403.2 | 67 | 0.042 | 0.599 | 0.381 | 27807.2 |

## Detailed Statistics

### CNN Model

- **Model Size**: 304.9KB
- **Preprocessing Time**: 0.070ms ±0.042ms
- **Prediction Time**: 0.747ms ±0.937ms
- **End-to-End Time**: 0.586ms ±0.597ms
- **Throughput**: 6493.1 samples/sec
- **Batch Prediction Time**: 2.464ms ±1.809ms
- **Peak System CPU Usage**: 76.5%
- **Peak Process CPU Usage**: 9.9%
- **Average System CPU Usage**: 5.7%
- **Average Process CPU Usage**: 0.4%
- **Peak Memory Usage**: 402.2 MB
- **Average Memory Usage**: 402.1 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 65, 'tls': 2}
- **Average Confidence**: 1.000

### MLP Model

- **Model Size**: 82.7KB
- **Preprocessing Time**: 0.038ms ±0.007ms
- **Prediction Time**: 0.316ms ±0.450ms
- **End-to-End Time**: 0.245ms ±0.273ms
- **Throughput**: 47999.4 samples/sec
- **Batch Prediction Time**: 0.333ms ±0.098ms
- **Peak System CPU Usage**: 68.7%
- **Peak Process CPU Usage**: 9.9%
- **Average System CPU Usage**: 4.0%
- **Average Process CPU Usage**: 0.3%
- **Peak Memory Usage**: 402.5 MB
- **Average Memory Usage**: 402.5 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 64, 'probe': 2, 'ddos': 1}
- **Average Confidence**: 1.000

### RNN Model

- **Model Size**: 198.8KB
- **Preprocessing Time**: 0.060ms ±0.026ms
- **Prediction Time**: 6.092ms ±4.334ms
- **End-to-End Time**: 5.125ms ±1.611ms
- **Throughput**: 2282.6 samples/sec
- **Batch Prediction Time**: 7.009ms ±4.924ms
- **Peak System CPU Usage**: 79.9%
- **Peak Process CPU Usage**: 9.9%
- **Average System CPU Usage**: 9.2%
- **Average Process CPU Usage**: 0.2%
- **Peak Memory Usage**: 402.8 MB
- **Average Memory Usage**: 402.6 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 67}
- **Average Confidence**: 0.989

### LSTM Model

- **Model Size**: 782.4KB
- **Preprocessing Time**: 0.060ms ±0.023ms
- **Prediction Time**: 3.520ms ±1.247ms
- **End-to-End Time**: 3.582ms ±3.131ms
- **Throughput**: 1178.3 samples/sec
- **Batch Prediction Time**: 13.579ms ±4.287ms
- **Peak System CPU Usage**: 62.2%
- **Peak Process CPU Usage**: 10.0%
- **Average System CPU Usage**: 7.1%
- **Average Process CPU Usage**: 0.5%
- **Peak Memory Usage**: 402.9 MB
- **Average Memory Usage**: 402.8 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 66, 'tls': 1}
- **Average Confidence**: 0.912

### GRU Model

- **Model Size**: 587.9KB
- **Preprocessing Time**: 0.079ms ±0.043ms
- **Prediction Time**: 6.975ms ±3.271ms
- **End-to-End Time**: 9.461ms ±14.205ms
- **Throughput**: 1482.7 samples/sec
- **Batch Prediction Time**: 10.791ms ±4.663ms
- **Peak System CPU Usage**: 24.4%
- **Peak Process CPU Usage**: 9.9%
- **Average System CPU Usage**: 7.1%
- **Average Process CPU Usage**: 0.4%
- **Peak Memory Usage**: 403.0 MB
- **Average Memory Usage**: 403.0 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 67}
- **Average Confidence**: 0.995

### AUTOENCODER Model

- **Model Size**: 155.3KB
- **Preprocessing Time**: 0.042ms ±0.012ms
- **Prediction Time**: 0.599ms ±0.690ms
- **End-to-End Time**: 0.381ms ±0.353ms
- **Throughput**: 27807.2 samples/sec
- **Batch Prediction Time**: 0.575ms ±0.587ms
- **Peak System CPU Usage**: 86.6%
- **Peak Process CPU Usage**: 9.9%
- **Average System CPU Usage**: 5.6%
- **Average Process CPU Usage**: 0.4%
- **Peak Memory Usage**: 403.3 MB
- **Average Memory Usage**: 403.2 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 62, 'tls': 2, 'probe': 2, 'ddos': 1}
- **Average Confidence**: 1.000

