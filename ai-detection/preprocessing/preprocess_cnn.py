import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split
import torch
from torch.utils.data import DataLoader, TensorDataset
import os


class CNNPreprocessor:
    """Preprocessing pipeline for CNN model"""

    def __init__(self, data_path=None):
        """Initialize preprocessor

        Args:
            data_path: Path to training data CSV (optional, for fitting scalers)
        """
        self.scaler = StandardScaler()
        self.label_encoder = LabelEncoder()
        self.is_fitted = False

        # Expected classes from training
        self.expected_classes = ['ddos', 'normal', 'probe', 'tls']

        if data_path and os.path.exists(data_path):
            self.fit_from_data(data_path)

    def fit_from_data(self, data_path):
        """Fit scalers and encoders from training data

        Args:
            data_path: Path to CSV file with training data
        """
        try:
            # Load data (assuming same format as training)
            df = pd.read_csv(data_path)

            # Extract features and labels
            X = df.drop(columns=['label']).values
            y_str = df['label'].values

            # Fit scalers
            self.scaler.fit(X)
            self.label_encoder.fit(self.expected_classes)

            self.is_fitted = True
            print(f"Fitted preprocessor on {len(df)} samples")

        except Exception as e:
            print(f"Error fitting preprocessor: {e}")
            self.is_fitted = False

    def preprocess_for_training(self, data_path, batch_size=64, val_split=0.125, test_split=0.20):
        """Preprocess data for CNN training

        Args:
            data_path: Path to CSV data file
            batch_size: Batch size for DataLoader
            val_split: Validation split ratio
            test_split: Test split ratio

        Returns:
            dict: DataLoaders and preprocessing objects
        """
        # Load data
        df = pd.read_csv(data_path)

        # Extract features and labels
        X = df.drop(columns=['label']).values  # (N, 76)
        y_str = df['label'].values

        # Encode labels
        y = self.label_encoder.fit_transform(y_str)

        # Scale features
        X_scaled = self.scaler.fit_transform(X).astype(np.float32)

        # Train/val/test split (70/10/20)
        X_train_full, X_test, y_train_full, y_test = train_test_split(
            X_scaled, y, test_size=test_split, random_state=42, stratify=y
        )
        X_train, X_val, y_train, y_val = train_test_split(
            X_train_full, y_train_full, test_size=val_split, random_state=42, stratify=y_train_full
        )

        # Reshape to (N, C=1, L=76) for Conv1d
        def to_tensor3(x):
            return torch.tensor(x, dtype=torch.float32).unsqueeze(1)  # add channel dim

        X_train_t = to_tensor3(X_train)
        X_val_t = to_tensor3(X_val)
        X_test_t = to_tensor3(X_test)

        y_train_t = torch.tensor(y_train, dtype=torch.long)
        y_val_t = torch.tensor(y_val, dtype=torch.long)
        y_test_t = torch.tensor(y_test, dtype=torch.long)

        # Create DataLoaders
        train_loader = DataLoader(
            TensorDataset(X_train_t, y_train_t),
            batch_size=batch_size, shuffle=True
        )
        val_loader = DataLoader(
            TensorDataset(X_val_t, y_val_t),
            batch_size=batch_size, shuffle=False
        )
        test_loader = DataLoader(
            TensorDataset(X_test_t, y_test_t),
            batch_size=batch_size, shuffle=False
        )

        return {
            'train_loader': train_loader,
            'val_loader': val_loader,
            'test_loader': test_loader,
            'scaler': self.scaler,
            'label_encoder': self.label_encoder,
            'classes': self.label_encoder.classes_,
            'input_shape': (1, 76)  # (channels, length)
        }

    def preprocess_for_inference(self, data):
        """Preprocess data for CNN inference

        Args:
            data: Input data (numpy array, pandas DataFrame, or dict)

        Returns:
            torch.Tensor: Preprocessed tensor ready for CNN input (batch_size, 1, 76)
        """
        if not self.is_fitted:
            raise ValueError("Preprocessor must be fitted before inference preprocessing")

        # Handle different input formats
        if isinstance(data, dict):
            # Single sample as dict
            if 'features' in data:
                X = np.array(data['features']).reshape(1, -1)
            else:
                # Assume dict values are features
                X = np.array(list(data.values())).reshape(1, -1)
        elif isinstance(data, pd.Series):
            # Handle pandas Series (single row)
            X = data.values.reshape(1, -1)
        elif isinstance(data, pd.DataFrame):
            X = data.values
        elif isinstance(data, np.ndarray):
            if data.ndim == 1:
                X = data.reshape(1, -1)
            else:
                X = data
        else:
            raise ValueError(f"Unsupported data type: {type(data)}")

        # Validate feature count
        if X.shape[1] != 76:
            raise ValueError(f"Expected 76 features, got {X.shape[1]}")

        # Scale features
        X_scaled = self.scaler.transform(X).astype(np.float32)

        # Convert to tensor and reshape for CNN: (batch_size, 1, 76)
        X_tensor = torch.tensor(X_scaled, dtype=torch.float32).unsqueeze(1)

        return X_tensor

    def inverse_transform_labels(self, encoded_labels):
        """Convert encoded labels back to class names

        Args:
            encoded_labels: Encoded label indices

        Returns:
            list: Class names
        """
        return self.label_encoder.inverse_transform(encoded_labels)


def load_cnn_preprocessor(scaler_path=None, encoder_path=None):
    """Load a fitted CNN preprocessor

    Args:
        scaler_path: Path to saved scaler (optional)
        encoder_path: Path to saved label encoder (optional)

    Returns:
        CNNPreprocessor: Fitted preprocessor
    """
    preprocessor = CNNPreprocessor()

    # In a production setting, you would load fitted scalers here
    # For now, we assume preprocessing happens during inference

    return preprocessor


# Example usage
if __name__ == "__main__":
    # Example: preprocess data for training
    preprocessor = CNNPreprocessor()

    # This would be used if you have training data
    # training_data = preprocessor.preprocess_for_training("path/to/training/data.csv")

    # Example: preprocess for inference
    sample_data = np.random.randn(76)  # 76 features
    preprocessor.fit_from_data = lambda x: None  # Mock fitting
    preprocessor.is_fitted = True

    try:
        processed = preprocessor.preprocess_for_inference(sample_data)
        print(f"Processed shape: {processed.shape}")  # Should be (1, 1, 76)
    except Exception as e:
        print(f"Error: {e}")
