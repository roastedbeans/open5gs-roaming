# AI Detection Models Performance Summary

## Comprehensive Performance Metrics

## System Configuration

- **CPU Cores**: 8 physical, 8 logical
- **RAM**: 7.7 GB total

## Performance Metrics

| Model | Size | Peak Sys CPU (%) | Peak Proc CPU (%) | Avg Sys CPU (%) | Avg Proc CPU (%) | Peak Memory (MB) | Avg Memory (MB) | Packet Count | Preprocess (ms) | Predict (ms) | End-to-End (ms) | Throughput (samp/sec) |
|-------|------|------------------|-------------------|-----------------|-----------------|------------------|-----------------|--------------|-----------------|--------------|-----------------|---------------------|
| CNN | 304.9KB | 14.3 | 9.9 | 2.0 | 0.4 | 404.5 | 397.3 | 67 | 0.082 | 0.481 | 0.298 | 4230.2 |
| MLP | 82.7KB | 3.5 | 9.9 | 0.5 | 0.3 | 397.3 | 397.3 | 67 | 0.039 | 0.172 | 0.185 | 54691.7 |
| RNN | 198.8KB | 14.1 | 9.6 | 2.3 | 0.1 | 397.4 | 397.4 | 67 | 0.052 | 3.257 | 3.194 | 3093.4 |
| LSTM | 782.4KB | 10.1 | 9.8 | 1.4 | 0.4 | 397.8 | 397.6 | 67 | 0.063 | 6.680 | 6.876 | 473.6 |
| GRU | 587.9KB | 14.6 | 9.7 | 2.5 | 0.1 | 397.9 | 397.8 | 67 | 0.057 | 5.701 | 5.644 | 1543.8 |
| AUTOENCODER | 155.3KB | 3.5 | 9.8 | 0.6 | 0.1 | 398.0 | 398.0 | 67 | 0.037 | 0.223 | 0.219 | 47166.8 |

## Detailed Statistics

### CNN Model

- **Model Size**: 304.9KB
- **Preprocessing Time**: 0.082ms ±0.141ms
- **Prediction Time**: 0.481ms ±0.899ms
- **End-to-End Time**: 0.298ms ±0.061ms
- **Throughput**: 4230.2 samples/sec
- **Batch Prediction Time**: 3.782ms ±5.195ms
- **Peak System CPU Usage**: 14.3%
- **Peak Process CPU Usage**: 9.9%
- **Average System CPU Usage**: 2.0%
- **Average Process CPU Usage**: 0.4%
- **Peak Memory Usage**: 404.5 MB
- **Average Memory Usage**: 397.3 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 65, 'tls': 2}
- **Average Confidence**: 1.000

### MLP Model

- **Model Size**: 82.7KB
- **Preprocessing Time**: 0.039ms ±0.014ms
- **Prediction Time**: 0.172ms ±0.088ms
- **End-to-End Time**: 0.185ms ±0.102ms
- **Throughput**: 54691.7 samples/sec
- **Batch Prediction Time**: 0.293ms ±0.048ms
- **Peak System CPU Usage**: 3.5%
- **Peak Process CPU Usage**: 9.9%
- **Average System CPU Usage**: 0.5%
- **Average Process CPU Usage**: 0.3%
- **Peak Memory Usage**: 397.3 MB
- **Average Memory Usage**: 397.3 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 64, 'probe': 2, 'ddos': 1}
- **Average Confidence**: 1.000

### RNN Model

- **Model Size**: 198.8KB
- **Preprocessing Time**: 0.052ms ±0.023ms
- **Prediction Time**: 3.257ms ±0.237ms
- **End-to-End Time**: 3.194ms ±0.071ms
- **Throughput**: 3093.4 samples/sec
- **Batch Prediction Time**: 5.172ms ±0.240ms
- **Peak System CPU Usage**: 14.1%
- **Peak Process CPU Usage**: 9.6%
- **Average System CPU Usage**: 2.3%
- **Average Process CPU Usage**: 0.1%
- **Peak Memory Usage**: 397.4 MB
- **Average Memory Usage**: 397.4 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 67}
- **Average Confidence**: 0.989

### LSTM Model

- **Model Size**: 782.4KB
- **Preprocessing Time**: 0.063ms ±0.035ms
- **Prediction Time**: 6.680ms ±0.300ms
- **End-to-End Time**: 6.876ms ±0.907ms
- **Throughput**: 473.6 samples/sec
- **Batch Prediction Time**: 33.783ms ±0.931ms
- **Peak System CPU Usage**: 10.1%
- **Peak Process CPU Usage**: 9.8%
- **Average System CPU Usage**: 1.4%
- **Average Process CPU Usage**: 0.4%
- **Peak Memory Usage**: 397.8 MB
- **Average Memory Usage**: 397.6 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 66, 'tls': 1}
- **Average Confidence**: 0.812

### GRU Model

- **Model Size**: 587.9KB
- **Preprocessing Time**: 0.057ms ±0.033ms
- **Prediction Time**: 5.701ms ±0.348ms
- **End-to-End Time**: 5.644ms ±0.108ms
- **Throughput**: 1543.8 samples/sec
- **Batch Prediction Time**: 10.364ms ±0.917ms
- **Peak System CPU Usage**: 14.6%
- **Peak Process CPU Usage**: 9.7%
- **Average System CPU Usage**: 2.5%
- **Average Process CPU Usage**: 0.1%
- **Peak Memory Usage**: 397.9 MB
- **Average Memory Usage**: 397.8 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 67}
- **Average Confidence**: 0.992

### AUTOENCODER Model

- **Model Size**: 155.3KB
- **Preprocessing Time**: 0.037ms ±0.010ms
- **Prediction Time**: 0.223ms ±0.101ms
- **End-to-End Time**: 0.219ms ±0.051ms
- **Throughput**: 47166.8 samples/sec
- **Batch Prediction Time**: 0.339ms ±0.030ms
- **Peak System CPU Usage**: 3.5%
- **Peak Process CPU Usage**: 9.8%
- **Average System CPU Usage**: 0.6%
- **Average Process CPU Usage**: 0.1%
- **Peak Memory Usage**: 398.0 MB
- **Average Memory Usage**: 398.0 MB
- **Packets Processed**: 67
- **Total Predictions**: 67
- **Prediction Distribution**: {'normal': 63, 'tls': 2, 'ddos': 1, 'probe': 1}
- **Average Confidence**: 1.000

