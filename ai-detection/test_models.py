#!/usr/bin/env python3
"""
Test script for AI Detection System
Tests loading and inference with trained models
"""

import sys
import os
import time
import numpy as np
from predict import AIDetector
from handler import AIDetectionHandler

def get_model_size_mb(model_path):
    """Get model file size in MB"""
    if os.path.exists(model_path):
        size_bytes = os.path.getsize(model_path)
        size_mb = size_bytes / (1024 * 1024)
        return size_mb
    return 0.0

def format_size(size_mb):
    """Format size for display"""
    if size_mb < 1.0:
        return f"{size_mb*1024:.1f}KB"
    else:
        return f"{size_mb:.1f}MB"


def test_model_loading():
    """Test loading of trained models"""
    print("Testing model loading...")

    try:
        detector = AIDetector()
        print(f"✓ Successfully loaded {len(detector.models)} models:")
        for model_name in detector.models.keys():
            print(f"  - {model_name}")
        return detector
    except Exception as e:
        print(f"✗ Failed to load models: {e}")
        return None


def test_single_prediction(detector):
    """Test single prediction"""
    print("\nTesting single predictions...")

    # Generate test data (76 features)
    test_data = np.random.randn(76).astype(np.float32)

    for model_type in ['cnn', 'mlp', 'rnn', 'lstm', 'gru', 'autoencoder']:
        if model_type in detector.models:
            try:
                result = detector.predict_single(test_data, model_type=model_type)
                print(f"✓ {model_type.upper()}: {result['prediction']} "
                      ".3f")
            except Exception as e:
                print(f"✗ {model_type.upper()} failed: {e}")
        else:
            print(f"- {model_type.upper()}: model not available")


def test_ensemble_prediction(detector):
    """Test ensemble prediction"""
    print("\nTesting ensemble prediction...")

    try:
        test_data = np.random.randn(76).astype(np.float32)
        result = detector.predict_ensemble(test_data)
        print(f"✓ Ensemble: {result['prediction']} "
              ".3f")
        print(f"  Individual predictions: {result['individual_predictions']}")
    except Exception as e:
        print(f"✗ Ensemble prediction failed: {e}")


def test_handler():
    """Test handler API"""
    print("\nTesting handler API...")

    try:
        handler = AIDetectionHandler()

        # Test data
        test_data = {"features": np.random.randn(76).tolist()}

        # Single model prediction
        result = handler.detect_intrusion(test_data, model_type="rnn")
        if result.get("status") == "success":
            print("✓ Handler single prediction successful")
            print(f"  Prediction: {result['prediction']}, Threat: {result['threat_level']}")
        else:
            print(f"✗ Handler single prediction failed: {result}")

        # Health check
        health = handler.health_check()
        if health.get("status") == "healthy":
            print("✓ Handler health check passed")
            print(f"  Models loaded: {health['models_loaded']}")
        else:
            print(f"✗ Handler health check failed: {health}")

    except Exception as e:
        print(f"✗ Handler test failed: {e}")


def test_preprocessors():
    """Test individual preprocessors"""
    print("\nTesting preprocessors...")

    # Test using AIDetector which properly initializes preprocessors
    try:
        detector = AIDetector()
        test_data = np.random.randn(76).astype(np.float32)

        # Test each preprocessor through the detector
        for model_type in ['rnn', 'lstm', 'gru']:  # Only test available models
            if model_type in detector.preprocessors:
                try:
                    processed = detector.preprocessors[model_type].preprocess_for_inference(test_data)
                    print(f"✓ {model_type.upper()} preprocessor: shape {processed.shape}")
                except Exception as e:
                    print(f"✗ {model_type.upper()} preprocessor failed: {e}")
            else:
                print(f"- {model_type.upper()}: preprocessor not available")

    except Exception as e:
        print(f"✗ Preprocessor test setup failed: {e}")


def benchmark_models(num_iterations=100, batch_size=32):
    """Benchmark model performance including preprocessing and prediction latency"""
    print(f"\n🚀 Benchmarking Model Performance ({num_iterations} iterations, batch_size={batch_size})")
    print("=" * 80)

    try:
        detector = AIDetector()
        available_models = list(detector.models.keys())

        # Generate test data
        single_test_data = np.random.randn(76).astype(np.float32)
        batch_test_data = np.random.randn(batch_size, 76).astype(np.float32)

        results = {}

        # Get model sizes first
        model_sizes = {}
        for model_type in available_models:
            if model_type == 'autoencoder':
                model_filename = 'best_supae.pth'
            elif model_type == 'cnn':
                model_filename = 'best_cnn1d.pth'
            else:
                model_filename = f"best_{model_type}.pth"

            model_path = os.path.join(detector.model_dir, model_filename)
            model_sizes[model_type] = get_model_size_mb(model_path)

        for model_type in available_models:
            print(f"\n📊 Benchmarking {model_type.upper()} Model")
            print("-" * 50)

            # Initialize timing arrays
            preprocessing_times = []
            prediction_times = []
            end_to_end_times = []
            batch_prediction_times = []

            for i in range(num_iterations):
                # Single prediction timing
                start_time = time.time()
                X_tensor = detector.preprocess_data(single_test_data, model_type)
                preprocessing_times.append(time.time() - start_time)

                start_time = time.time()
                result = detector.predict_single(single_test_data, model_type)
                prediction_times.append(time.time() - start_time)

                # End-to-end timing (preprocessing + prediction)
                start_time = time.time()
                result = detector.predict_single(single_test_data, model_type)
                end_to_end_times.append(time.time() - start_time)

                # Batch prediction timing
                start_time = time.time()
                batch_result = detector.predict_batch(batch_test_data, model_type)
                batch_prediction_times.append(time.time() - start_time)

            # Calculate statistics
            stats = {
                'model_size_mb': model_sizes[model_type],
                'preprocessing': {
                    'mean': np.mean(preprocessing_times),
                    'std': np.std(preprocessing_times),
                    'min': np.min(preprocessing_times),
                    'max': np.max(preprocessing_times),
                    'total': np.sum(preprocessing_times)
                },
                'prediction': {
                    'mean': np.mean(prediction_times),
                    'std': np.std(prediction_times),
                    'min': np.min(prediction_times),
                    'max': np.max(prediction_times),
                    'total': np.sum(prediction_times)
                },
                'end_to_end': {
                    'mean': np.mean(end_to_end_times),
                    'std': np.std(end_to_end_times),
                    'min': np.min(end_to_end_times),
                    'max': np.max(end_to_end_times),
                    'total': np.sum(end_to_end_times)
                },
                'batch_prediction': {
                    'mean': np.mean(batch_prediction_times),
                    'std': np.std(batch_prediction_times),
                    'min': np.min(batch_prediction_times),
                    'max': np.max(batch_prediction_times),
                    'total': np.sum(batch_prediction_times),
                    'throughput': batch_size / np.mean(batch_prediction_times)  # samples/sec
                }
            }

            results[model_type] = stats

            # Print results for this model
            print(f"  Model Size:      {format_size(stats['model_size_mb']):>8}")
            print(f"  Preprocessing:  {stats['preprocessing']['mean']*1000:.2f}ms ±{stats['preprocessing']['std']*1000:.2f}ms")
            print(f"  Prediction:     {stats['prediction']['mean']*1000:.2f}ms ±{stats['prediction']['std']*1000:.2f}ms")
            print(f"  End-to-End:     {stats['end_to_end']['mean']*1000:.2f}ms ±{stats['end_to_end']['std']*1000:.2f}ms")
            print(f"  Batch (size {batch_size}): {stats['batch_prediction']['mean']*1000:.2f}ms ±{stats['batch_prediction']['std']*1000:.2f}ms")
            print(f"  Throughput:     {stats['batch_prediction']['throughput']:.1f} samples/sec")

        # Print summary comparison
        print(f"\n📈 Performance Summary ({num_iterations} iterations)")
        print("=" * 90)
        print(f"{'Model':<12} {'Size':<8} {'Preprocess':<10} {'Predict':<10} {'End-to-End':<12} {'Throughput':<12}")
        print("-" * 90)

        for model_type in available_models:
            stats = results[model_type]
            size_str = format_size(stats['model_size_mb'])
            print(f"{model_type.upper():<12} {size_str:<8} {stats['preprocessing']['mean']*1000:>8.2f}ms {stats['prediction']['mean']*1000:>8.2f}ms {stats['end_to_end']['mean']*1000:>10.2f}ms {stats['batch_prediction']['throughput']:>10.1f} samp/sec")

        # Find best performing models
        best_preprocessing = min(results.keys(), key=lambda x: results[x]['preprocessing']['mean'])
        best_prediction = min(results.keys(), key=lambda x: results[x]['prediction']['mean'])
        best_end_to_end = min(results.keys(), key=lambda x: results[x]['end_to_end']['mean'])
        best_throughput = max(results.keys(), key=lambda x: results[x]['batch_prediction']['throughput'])
        smallest_model = min(results.keys(), key=lambda x: results[x]['model_size_mb'])

        print(f"\n🏆 Best Performing Models:")
        print(f"  Fastest Preprocessing: {best_preprocessing.upper()}")
        print(f"  Fastest Prediction: {best_prediction.upper()}")
        print(f"  Fastest End-to-End: {best_end_to_end.upper()}")
        print(f"  Highest Throughput: {best_throughput.upper()}")
        print(f"  Smallest Model: {smallest_model.upper()} ({format_size(results[smallest_model]['model_size_mb'])})")

        return results

    except Exception as e:
        print(f"✗ Benchmarking failed: {e}")
        import traceback
        traceback.print_exc()
        return None


def main():
    """Run all tests"""
    print("🧪 AI Detection System Test Suite")
    print("=" * 40)

    # Test model loading
    detector = test_model_loading()
    if detector is None:
        print("\n❌ Cannot continue without loaded models")
        sys.exit(1)

    # Test predictions
    test_single_prediction(detector)
    test_ensemble_prediction(detector)

    # Test handler
    test_handler()

    # Test preprocessors
    test_preprocessors()

    # Performance benchmarking
    benchmark_models(num_iterations=50, batch_size=16)  # Reduced for faster testing

    print("\n" + "=" * 40)
    print("✅ Test suite completed!")


def run_performance_benchmark(num_iterations=100, batch_size=32, models_to_test=None):
    """
    Standalone function to run comprehensive performance benchmarking

    Args:
        num_iterations: Number of iterations for statistical significance
        batch_size: Batch size for batch prediction testing
        models_to_test: List of specific models to test, None for all available

    Returns:
        Dictionary with performance results for each model
    """
    print(f"\n🚀 Running Comprehensive Performance Benchmark")
    print(f"   Iterations: {num_iterations}, Batch Size: {batch_size}")

    results = benchmark_models(num_iterations=num_iterations, batch_size=batch_size)

    if results:
        print("\n✅ Benchmarking completed successfully!")
        print(f"📊 Results saved for {len(results)} models")

    return results


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--benchmark":
        # Run only benchmarks
        print("🧪 AI Detection Benchmark Suite")
        print("=" * 40)
        run_performance_benchmark(num_iterations=50, batch_size=16)
    else:
        # Run full test suite
        main()
