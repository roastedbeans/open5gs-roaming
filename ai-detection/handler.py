import json
import logging
from typing import Dict, List, Any, Union
import numpy as np
from predict import AIDetector


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class AIDetectionHandler:
    """Handler for AI-based intrusion detection in Open5GS roaming"""

    def __init__(self, model_dir: str = "models", device: str = "cpu"):
        """Initialize the AI detection handler

        Args:
            model_dir: Directory containing trained models
            device: Device to run models on ('cpu' or 'cuda')
        """
        try:
            self.detector = AIDetector(model_dir=model_dir, device=device)
            self.is_initialized = True
            logger.info("AI Detection Handler initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize AI Detection Handler: {e}")
            self.is_initialized = False

    def detect_intrusion(self, network_data: Dict[str, Any], model_type: str = "cnn") -> Dict[str, Any]:
        """Detect network intrusions from network traffic data

        Args:
            network_data: Dictionary containing network traffic features
            model_type: Type of model to use ('cnn', 'mlp', 'rnn', 'lstm', 'gru', 'autoencoder', 'ensemble')

        Returns:
            Dictionary containing detection results
        """
        if not self.is_initialized:
            return {
                "error": "AI Detection Handler not properly initialized",
                "status": "error"
            }

        try:
            # Validate input data
            if not isinstance(network_data, dict):
                return {
                    "error": "Input must be a dictionary of network features",
                    "status": "error"
                }

            # Extract features (assuming network_data contains the 77 features)
            # In practice, you might need to extract specific features from raw network data
            features = self._extract_features(network_data)

            if features is None:
                return {
                    "error": "Could not extract features from network data",
                    "status": "error"
                }

            # Make prediction
            if model_type == "ensemble":
                result = self.detector.predict_ensemble(features)
            else:
                result = self.detector.predict_single(features, model_type=model_type)

            # Add additional metadata
            result.update({
                "status": "success",
                "threat_level": self._calculate_threat_level(result),
                "recommendation": self._get_recommendation(result)
            })

            logger.info(f"Intrusion detection completed: {result['prediction']} "
                       ".2f")

            return result

        except Exception as e:
            logger.error(f"Error during intrusion detection: {e}")
            return {
                "error": str(e),
                "status": "error"
            }

    def batch_detect(self, network_data_list: List[Dict[str, Any]],
                    model_type: str = "cnn") -> List[Dict[str, Any]]:
        """Detect intrusions in batch of network data

        Args:
            network_data_list: List of network traffic feature dictionaries
            model_type: Type of model to use

        Returns:
            List of detection results
        """
        if not self.is_initialized:
            return [{"error": "AI Detection Handler not initialized", "status": "error"}]

        results = []
        for i, network_data in enumerate(network_data_list):
            try:
                result = self.detect_intrusion(network_data, model_type)
                result["sample_index"] = i
                results.append(result)
            except Exception as e:
                logger.error(f"Error processing sample {i}: {e}")
                results.append({
                    "error": str(e),
                    "status": "error",
                    "sample_index": i
                })

        return results

    def _extract_features(self, network_data: Dict[str, Any]) -> Union[np.ndarray, None]:
        """Extract features from network data

        This is a placeholder - in practice, you'd extract specific features
        from raw network traffic data (packets, flows, etc.)

        Args:
            network_data: Raw network data

        Returns:
            Numpy array of features or None if extraction fails
        """
        try:
            # Check if data already contains the expected features
            if "features" in network_data:
                features = network_data["features"]
                if isinstance(features, list):
                    features = np.array(features)
                elif isinstance(features, np.ndarray):
                    pass
                else:
                    raise ValueError("Features must be list or numpy array")

                if features.shape[-1] != 76:
                    raise ValueError(f"Expected 76 features, got {features.shape[-1]}")

                return features

            # Placeholder for feature extraction logic
            # In a real implementation, you would:
            # 1. Parse network packets/flows
            # 2. Extract relevant features (packet size, timing, protocols, etc.)
            # 3. Return as numpy array with 77 features

            # For now, return None to indicate feature extraction is needed
            logger.warning("Feature extraction not implemented - expecting 'features' key in input")
            return None

        except Exception as e:
            logger.error(f"Error extracting features: {e}")
            return None

    def _calculate_threat_level(self, result: Dict[str, Any]) -> str:
        """Calculate threat level based on prediction and confidence

        Args:
            result: Prediction result

        Returns:
            Threat level string
        """
        prediction = result.get("prediction", "normal")
        confidence = result.get("confidence", 0.0)

        if prediction == "normal":
            return "low"
        elif prediction in ["probe", "tls"]:
            if confidence > 0.8:
                return "medium"
            else:
                return "low"
        elif prediction == "ddos":
            if confidence > 0.9:
                return "high"
            elif confidence > 0.7:
                return "medium"
            else:
                return "low"
        else:
            return "unknown"

    def _get_recommendation(self, result: Dict[str, Any]) -> str:
        """Get recommendation based on detection result

        Args:
            result: Prediction result

        Returns:
            Recommendation string
        """
        prediction = result.get("prediction", "normal")
        threat_level = self._calculate_threat_level(result)

        if threat_level == "low":
            return "Continue monitoring"
        elif threat_level == "medium":
            if prediction == "ddos":
                return "Monitor traffic patterns and prepare mitigation"
            else:
                return "Log incident and continue monitoring"
        elif threat_level == "high":
            return "Immediate action required - block suspicious traffic"
        else:
            return "Unable to determine recommendation"

    def get_model_info(self) -> Dict[str, Any]:
        """Get information about available models

        Returns:
            Dictionary with model information
        """
        if not self.is_initialized:
            return {"error": "Handler not initialized"}

        return {
            "available_models": list(self.detector.models.keys()),
            "device": str(self.detector.device),
            "model_directory": self.detector.model_dir,
            "classes": self.detector.label_encoder.classes_.tolist()
        }

    def health_check(self) -> Dict[str, Any]:
        """Perform health check of the AI detection system

        Returns:
            Health status dictionary
        """
        if not self.is_initialized:
            return {
                "status": "unhealthy",
                "message": "AI Detection Handler not initialized"
            }

        try:
            # Test with dummy data using first available model
            dummy_data = np.random.randn(76)
            available_models = list(self.detector.models.keys())
            if available_models:
                result = self.detector.predict_single(dummy_data, model_type=available_models[0])
            else:
                return {
                    "status": "unhealthy",
                    "message": "No models available for testing"
                }

            return {
                "status": "healthy",
                "message": "AI Detection system is operational",
                "models_loaded": len(self.detector.models),
                "test_prediction": result["prediction"]
            }
        except Exception as e:
            return {
                "status": "unhealthy",
                "message": f"Health check failed: {str(e)}"
            }


# Global handler instance
_handler = None


def get_handler() -> AIDetectionHandler:
    """Get or create the global AI detection handler instance"""
    global _handler
    if _handler is None:
        _handler = AIDetectionHandler()
    return _handler


def detect_intrusion_api(network_data: Dict[str, Any], model_type: str = "cnn") -> Dict[str, Any]:
    """API function for intrusion detection

    Args:
        network_data: Network traffic data
        model_type: Model to use for detection

    Returns:
        Detection results
    """
    handler = get_handler()
    return handler.detect_intrusion(network_data, model_type)


def health_check_api() -> Dict[str, Any]:
    """API function for health check"""
    handler = get_handler()
    return handler.health_check()


# Example usage and testing
if __name__ == "__main__":
    # Initialize handler
    handler = AIDetectionHandler()

    # Health check
    health = handler.health_check()
    print("Health check:", json.dumps(health, indent=2))

    if health["status"] == "healthy":
        # Test with dummy data
        dummy_network_data = {
            "features": np.random.randn(77).tolist()
        }

        result = handler.detect_intrusion(dummy_network_data, model_type="cnn")
        print("Detection result:", json.dumps(result, indent=2))
