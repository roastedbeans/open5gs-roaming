import os
import numpy as np
import pandas as pd
import torch
from model import create_model, CLASS_NAMES
from preprocessing.preprocess_cnn import CNNPreprocessor
from preprocessing.preprocess_mlp import MLPPreprocessor
from preprocessing.preprocess_rnn import RNNPreprocessor
from preprocessing.preprocess_lstm import LSTMPreprocessor
from preprocessing.preprocess_gru import GRUPreprocessor
from preprocessing.preprocess_autoencoder import AutoencoderPreprocessor


class AIDetector:
    """AI-based Intrusion Detection System"""

    def __init__(self, model_dir="models", device="cpu"):
        self.device = torch.device(device)
        self.model_dir = model_dir
        self.models = {}
        self.preprocessors = {}
        self.available_models = ['cnn', 'mlp', 'rnn', 'lstm', 'gru', 'autoencoder']

        # Initialize preprocessors for each model type
        self._init_preprocessors()

        # Load all available models
        self._load_models()

    def _init_preprocessors(self):
        """Initialize preprocessors for each model type"""
        # Fit preprocessors on dummy data for inference compatibility
        # In production, you would load pre-fitted scalers
        dummy_data = np.random.randn(100, 76)  # 100 samples, 76 features
        dummy_labels = np.random.choice(['ddos', 'normal', 'probe', 'tls'], 100)

        self.preprocessors = {}
        preprocessor_classes = {
            'cnn': CNNPreprocessor,
            'mlp': MLPPreprocessor,
            'rnn': RNNPreprocessor,
            'lstm': LSTMPreprocessor,
            'gru': GRUPreprocessor,
            'autoencoder': AutoencoderPreprocessor
        }

        for name, preprocessor_class in preprocessor_classes.items():
            try:
                # Create and fit preprocessor
                preprocessor = preprocessor_class()
                preprocessor.scaler.fit(dummy_data)
                preprocessor.label_encoder.fit(['ddos', 'normal', 'probe', 'tls'])
                preprocessor.is_fitted = True
                self.preprocessors[name] = preprocessor
                print(f"Fitted {name} preprocessor")
            except Exception as e:
                print(f"Warning: Could not fit {name} preprocessor: {e}")
                # Create unfitted preprocessor as fallback
                preprocessor = preprocessor_class()
                self.preprocessors[name] = preprocessor

    def _load_models(self):
        """Load all trained models"""
        for model_type in self.available_models:
            # Handle special case filenames
            if model_type == 'autoencoder':
                model_filename = 'best_supae.pth'
            elif model_type == 'cnn':
                model_filename = 'best_cnn1d.pth'
            else:
                model_filename = f"best_{model_type}.pth"

            model_path = os.path.join(self.model_dir, model_filename)
            if os.path.exists(model_path):
                try:
                    model = create_model(model_type, num_classes=len(CLASS_NAMES))
                    model.load_state_dict(torch.load(model_path, map_location=self.device, weights_only=True))
                    model.to(self.device)
                    model.eval()
                    self.models[model_type] = model
                    print(f"Loaded {model_type} model from {model_path}")
                except Exception as e:
                    print(f"Error loading {model_type} model: {e}")
            else:
                print(f"Model file not found: {model_path}")

        if not self.models:
            raise ValueError("No models could be loaded")

    def preprocess_data(self, data, model_type='cnn'):
        """Preprocess input data for prediction using model-specific preprocessor

        Args:
            data: Can be dict, pandas DataFrame, or numpy array
            model_type: Type of model ('cnn', 'mlp', 'rnn', 'lstm', 'gru', 'autoencoder')

        Returns:
            torch.Tensor: Preprocessed data ready for model input
        """
        if model_type not in self.preprocessors:
            raise ValueError(f"No preprocessor available for model type: {model_type}")

        preprocessor = self.preprocessors[model_type]
        X_tensor = preprocessor.preprocess_for_inference(data)

        return X_tensor

    def predict_single(self, data, model_type='cnn'):
        """Make prediction on single sample

        Args:
            data: Input features (dict, DataFrame, or numpy array)
            model_type: Type of model to use ('cnn', 'mlp', 'rnn', 'lstm', 'gru')

        Returns:
            dict: Prediction results
        """
        if model_type not in self.models:
            raise ValueError(f"Model {model_type} not available. Available: {list(self.models.keys())}")

        # Preprocess data
        X_tensor = self.preprocess_data(data, model_type)

        # Handle different model input requirements
        if model_type == 'cnn':
            # CNN preprocessor already returns (batch_size, channels, length)
            # No additional processing needed
            pass
        elif model_type in ['rnn', 'lstm', 'gru']:
            # RNN variants expect (batch_size, seq_len, input_size)
            # Preprocessors already output (batch, 76, 1) so no change needed
            pass

        model = self.models[model_type]

        with torch.no_grad():
            output = model(X_tensor.to(self.device))
            # Handle autoencoder which returns (logits, x_hat, z)
            if model_type == 'autoencoder':
                logits, _, _ = output
            else:
                logits = output
            probabilities = torch.softmax(logits, dim=1)
            predicted_class_idx = torch.argmax(probabilities, dim=1).item()
            confidence = probabilities[0][predicted_class_idx].item()

        predicted_class = CLASS_NAMES[predicted_class_idx]

        return {
            'prediction': predicted_class,
            'confidence': confidence,
            'probabilities': {
                class_name: prob.item()
                for class_name, prob in zip(CLASS_NAMES, probabilities[0])
            },
            'model_used': model_type
        }

    def predict_batch(self, data, model_type='cnn'):
        """Make predictions on batch of samples

        Args:
            data: Batch of input features
            model_type: Type of model to use

        Returns:
            list: List of prediction results
        """
        if model_type not in self.models:
            raise ValueError(f"Model {model_type} not available")

        # Preprocess data
        X_tensor = self.preprocess_data(data, model_type)

        # Handle different model input requirements
        if model_type == 'cnn':
            # CNN preprocessor already returns (batch_size, channels, length)
            # No additional processing needed
            pass
        elif model_type in ['rnn', 'lstm', 'gru']:
            # RNN variants expect (batch_size, seq_len, input_size)
            # Preprocessors already output (batch, 76, 1) so no change needed
            pass

        model = self.models[model_type]

        with torch.no_grad():
            output = model(X_tensor.to(self.device))
            # Handle autoencoder which returns (logits, x_hat, z)
            if model_type == 'autoencoder':
                logits, _, _ = output
            else:
                logits = output
            probabilities = torch.softmax(logits, dim=1)
            predicted_class_indices = torch.argmax(probabilities, dim=1)
            confidences = torch.max(probabilities, dim=1)[0]

        results = []
        for i in range(len(predicted_class_indices)):
            predicted_class = CLASS_NAMES[predicted_class_indices[i].item()]
            confidence = confidences[i].item()

            results.append({
                'prediction': predicted_class,
                'confidence': confidence,
                'probabilities': {
                    class_name: probabilities[i][j].item()
                    for j, class_name in enumerate(CLASS_NAMES)
                },
                'model_used': model_type
            })

        return results

    def predict_ensemble(self, data):
        """Make ensemble prediction using all available models

        Args:
            data: Input features

        Returns:
            dict: Ensemble prediction results
        """
        if not self.models:
            raise ValueError("No models available for ensemble prediction")

        all_probabilities = []

        for model_type, model in self.models.items():
            X_tensor = self.preprocess_data(data, model_type)

            # Handle different model input requirements
            if model_type == 'cnn':
                # CNN preprocessor already returns (batch_size, channels, length)
                # No additional processing needed
                pass
            elif model_type in ['rnn', 'lstm', 'gru']:
                # RNN variants expect (batch_size, seq_len, input_size)
                # Preprocessors already output (batch, 76, 1) so no change needed
                pass

            with torch.no_grad():
                output = model(X_tensor.to(self.device))
                # Handle autoencoder which returns (logits, x_hat, z)
                if model_type == 'autoencoder':
                    logits, _, _ = output
                else:
                    logits = output
                probabilities = torch.softmax(logits, dim=1)
                all_probabilities.append(probabilities.cpu().numpy()[0])

        # Average probabilities across all models
        avg_probabilities = np.mean(all_probabilities, axis=0)
        predicted_class_idx = np.argmax(avg_probabilities)
        confidence = avg_probabilities[predicted_class_idx]

        predicted_class = CLASS_NAMES[predicted_class_idx]

        return {
            'prediction': predicted_class,
            'confidence': confidence,
            'probabilities': {
                class_name: float(prob)
                for class_name, prob in zip(CLASS_NAMES, avg_probabilities)
            },
            'model_used': 'ensemble',
            'individual_predictions': {
                model_type: CLASS_NAMES[np.argmax(probs)]
                for model_type, probs in zip(self.models.keys(), all_probabilities)
            }
        }


def main():
    """Example usage"""
    detector = AIDetector()

    # Load data from CSV file
    print("Loading data from dos.csv...")
    df = pd.read_csv('./dos.csv')

    # Use the first row for single prediction
    sample_data = df.iloc[0]  # First row as dict-like
    print(f"Using first row with {len(sample_data)} features")

    # Single prediction
    print("\n" + "="*50)
    print("SINGLE PREDICTION TEST")
    print("="*50)
    result = detector.predict_single(sample_data, model_type='cnn')
    print("CNN Model Result:", result)

    # Ensemble prediction
    print("\n" + "="*50)
    print("ENSEMBLE PREDICTION TEST")
    print("="*50)
    ensemble_result = detector.predict_ensemble(sample_data)
    print("Ensemble Result:", ensemble_result)

    # Test with multiple rows for batch prediction
    print("\n" + "="*50)
    print("BATCH PREDICTION TEST")
    print("="*50)
    batch_data = df.head(20)  # First 3 rows
    print(f"Testing batch prediction with {len(batch_data)} samples")
    batch_result = detector.predict_batch(batch_data, model_type='mlp')
    print("Batch results:")
    for i, result in enumerate(batch_result):
        print(f"  Sample {i+1}: {result['prediction']} ({result['confidence']:.3f})")


if __name__ == "__main__":
    main()
