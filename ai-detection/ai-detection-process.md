# Kubernetes (Visited PLMN)

## SEPP Data Capture
- **n32c / n32f** interfaces
- **CICFlowMeter (Sidecar/Daemon)**
  - Generates **Feature Vector** (82 → 76 features)
  - **Data Cleansing**: Remove infinite/negative values
  - **Normalization**: Z-score via StandardScaler
- **Output**: Structured dataset (76 features)
- Sends to API (`<url>/predict`)

➡️ **AI-based Detection System**

## Model Inference
- **Model Loading**: Single pre-trained deep learning model
- **Input**: Structured dataset (76 features)
- **Forward Pass**: Neural network processing
- **Output**: Class probabilities

## Threat Classification
- ✅ **Normal Roaming Operation**
- ❌ **DoS Attack**
- ❌ **TLS Exploitation**
- ❌ **Probing Activity**

## Real-Time Response
- **Immediate Detection**: Real-time results
- **Reporting**: Detailed threat reports
- **Scaling**: Kubernetes HPA for dynamic scaling
