#!/usr/bin/env python3
"""
AI Detection Model Performance Monitoring and Visualization
Monitors CPU and memory usage during model inference with time-series plots
"""

import time
import psutil
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from typing import Dict, List, Any, Optional
from contextlib import contextmanager
from predict import AIDetector
from handler import AIDetectionHandler
import gc

# Set plotting style
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

def format_size(size_mb):
    """Format size for display"""
    if size_mb < 1.0:
        return f"{size_mb*1024:.1f}KB"
    else:
        return f"{size_mb:.1f}MB"

class PerformanceMonitor:
    """Monitor CPU and memory usage during model inference"""

    def __init__(self):
        self.process = psutil.Process(os.getpid())
        self.baseline_cpu = None
        self.baseline_memory = None

    def get_system_stats(self) -> Dict[str, float]:
        """Get comprehensive CPU and memory usage metrics"""
        # System-wide CPU usage (affects entire host system)
        system_cpu_percent = psutil.cpu_percent(interval=None)

        # Process-specific CPU usage (affects only our AI process)
        process_cpu_percent = self.process.cpu_percent(interval=0.1)

        # Memory metrics
        memory_info = self.process.memory_info()
        memory_percent = self.process.memory_percent()

        # System information
        system_memory = psutil.virtual_memory()
        total_cpu_cores = psutil.cpu_count(logical=True)  # Logical cores (including hyper-threading)
        total_cpu_physical = psutil.cpu_count(logical=False)  # Physical cores

        return {
            'system_cpu_percent': min(system_cpu_percent, 100.0),  # System-wide CPU (0-100%)
            'process_cpu_percent': process_cpu_percent,  # Process CPU (can exceed 100%)
            'memory_rss': memory_info.rss / 1024 / 1024,  # MB (Resident Set Size)
            'memory_vms': memory_info.vms / 1024 / 1024,  # MB (Virtual Memory Size)
            'memory_percent': memory_percent,  # Process memory percentage
            'system_memory_total_gb': system_memory.total / (1024**3),  # Total system RAM in GB
            'system_memory_used_gb': system_memory.used / (1024**3),  # Used system RAM in GB
            'system_memory_percent': system_memory.percent,  # System memory usage %
            'cpu_cores_logical': total_cpu_cores,  # Total logical CPU cores
            'cpu_cores_physical': total_cpu_physical,  # Total physical CPU cores
            'timestamp': time.time()
        }

    def measure_baseline(self, duration: float = 2.0) -> Dict[str, float]:
        """Measure baseline system usage"""
        print("Measuring baseline system usage...")

        measurements = []
        start_time = time.time()

        # Take measurements over the duration
        while time.time() - start_time < duration:
            measurements.append(self.get_system_stats())
            time.sleep(0.2)  # 5 measurements per second

        # Calculate averages for both CPU metrics
        self.baseline_system_cpu = np.mean([m['system_cpu_percent'] for m in measurements])
        self.baseline_process_cpu = np.mean([m['process_cpu_percent'] for m in measurements])
        self.baseline_memory = np.mean([m['memory_rss'] for m in measurements])

        # Get system specs from first measurement (they don't change)
        system_specs = measurements[0] if measurements else {}

        print(".1f")
        print(".1f")
        print(f"System Specs: {system_specs.get('cpu_cores_physical', 'N/A')} physical cores, "
              f"{system_specs.get('cpu_cores_logical', 'N/A')} logical cores, "
              f"{system_specs.get('system_memory_total_gb', 'N/A'):.1f}GB RAM")

        return {
            'baseline_system_cpu': self.baseline_system_cpu,
            'baseline_process_cpu': self.baseline_process_cpu,
            'baseline_memory': self.baseline_memory,
            'system_specs': {
                'cpu_cores_physical': system_specs.get('cpu_cores_physical', 0),
                'cpu_cores_logical': system_specs.get('cpu_cores_logical', 0),
                'memory_total_gb': system_specs.get('system_memory_total_gb', 0)
            }
        }

    @contextmanager
    def monitor_inference(self, model_type: str, num_samples: int = 100):
        """Context manager to monitor model inference"""
        measurements = []
        start_time = time.time()

        # Single pre-measurement (faster than multiple)
        stats = self.get_system_stats()
        measurements.append({**stats, 'phase': 'pre', 'model': model_type})

        yield  # Execute the inference code

        # Single post-measurement
        stats = self.get_system_stats()
        measurements.append({**stats, 'phase': 'post', 'model': model_type})

        self.last_measurements = measurements

        # Calculate averages during inference for both CPU metrics
        inference_measurements = [m for m in measurements if m['phase'] in ['pre', 'post']]
        if inference_measurements:
            avg_system_cpu = np.mean([m['system_cpu_percent'] for m in inference_measurements])
            avg_process_cpu = np.mean([m['process_cpu_percent'] for m in inference_measurements])
            avg_memory = np.mean([m['memory_rss'] for m in inference_measurements])

            print(f"  {model_type.upper()}: System CPU {avg_system_cpu:.1f}%, Process CPU {avg_process_cpu:.1f}%, Memory {avg_memory:.1f}MB "
                  f"(Baseline: Sys CPU {self.baseline_system_cpu:.1f}%, Proc CPU {self.baseline_process_cpu:.1f}%, Memory {self.baseline_memory:.1f}MB)")

    def benchmark_model(self, model_type: str, num_iterations: int = 50, csv_file: str = './dos.csv') -> Dict[str, Any]:
        """Benchmark a specific model with performance monitoring using all packets from CSV"""
        print(f"\n🚀 Benchmarking {model_type.upper()} Model Performance")

        # Initialize detector
        detector = AIDetector()
        monitor = PerformanceMonitor()
        monitor.measure_baseline()

        # Load all data from CSV file
        print(f"📊 Loading data from {csv_file}...")
        try:
            df = pd.read_csv(csv_file)
            total_packets = len(df)
            print(f"✅ Loaded {total_packets} packets from CSV file")
        except FileNotFoundError:
            print(f"❌ CSV file '{csv_file}' not found. Using synthetic data.")
            # Fallback to synthetic data if CSV not found
            total_packets = 100
            df = pd.DataFrame(np.random.randn(total_packets, 76), columns=[f'feature_{i}' for i in range(76)])
            df['label'] = np.random.choice(['ddos', 'normal', 'probe', 'tls'], total_packets)

        all_measurements = []
        inference_times = []
        system_cpu_usage = []
        process_cpu_usage = []
        memory_usage = []
        packet_predictions = []

        # Process packets in batches to avoid memory issues
        batch_size = min(100, total_packets)  # Process in batches of 100 or total packets if fewer

        print(f"🔄 Processing {total_packets} packets in batches of {batch_size}...")

        for batch_start in range(0, min(num_iterations, total_packets), batch_size):
            batch_end = min(batch_start + batch_size, total_packets)
            batch_data = df.iloc[batch_start:batch_end]

            print(f"  Processing batch {batch_start//batch_size + 1}: packets {batch_start}-{batch_end-1}")

            # Convert batch to list of samples for processing
            for idx, (_, packet_data) in enumerate(batch_data.iterrows()):
                packet_idx = batch_start + idx

                # Monitor inference for this packet
                with monitor.monitor_inference(model_type, 1):
                    start_time = time.time()
                    try:
                        result = detector.predict_single(packet_data, model_type=model_type)
                        inference_time = time.time() - start_time
                        packet_predictions.append({
                            'packet_idx': packet_idx,
                            'prediction': result['prediction'],
                            'confidence': result['confidence']
                        })
                    except Exception as e:
                        print(f"    ⚠️ Error processing packet {packet_idx}: {e}")
                        inference_time = time.time() - start_time
                        packet_predictions.append({
                            'packet_idx': packet_idx,
                            'prediction': 'error',
                            'confidence': 0.0
                        })

                    inference_times.append(inference_time)

                    # Collect measurements
                    if hasattr(monitor, 'last_measurements'):
                        for measurement in monitor.last_measurements:
                            measurement_copy = measurement.copy()
                            measurement_copy['packet_idx'] = packet_idx
                            measurement_copy['iteration'] = packet_idx
                            measurement_copy['inference_time'] = inference_time
                            all_measurements.append(measurement_copy)

                            # Collect for averages
                            if measurement['phase'] in ['pre', 'post']:
                                system_cpu_usage.append(measurement['system_cpu_percent'])
                                process_cpu_usage.append(measurement['process_cpu_percent'])
                                memory_usage.append(measurement['memory_rss'])

            # Progress indicator
            progress = min(batch_end, num_iterations)
            print(f"  📈 Progress: {progress}/{min(num_iterations, total_packets)} packets processed ({progress/min(num_iterations, total_packets)*100:.1f}%)")

            # Limit to num_iterations if specified
            if progress >= num_iterations:
                break

        # Force garbage collection
        gc.collect()
        time.sleep(0.1)

        # Calculate prediction statistics
        predictions_df = pd.DataFrame(packet_predictions)
        prediction_counts = predictions_df['prediction'].value_counts() if not predictions_df.empty else {}

        # Calculate final statistics
        results = {
            'model': model_type,
            'measurements': all_measurements,
            'packet_predictions': packet_predictions,
            'statistics': {
                'total_packets_processed': len(packet_predictions),
                'avg_system_cpu_percent': np.mean(system_cpu_usage) if system_cpu_usage else 0,
                'avg_process_cpu_percent': np.mean(process_cpu_usage) if process_cpu_usage else 0,
                'avg_memory_mb': np.mean(memory_usage) if memory_usage else 0,
                'std_system_cpu_percent': np.std(system_cpu_usage) if system_cpu_usage else 0,
                'std_process_cpu_percent': np.std(process_cpu_usage) if process_cpu_usage else 0,
                'std_memory_mb': np.std(memory_usage) if memory_usage else 0,
                'max_system_cpu_percent': np.max(system_cpu_usage) if system_cpu_usage else 0,
                'max_process_cpu_percent': np.max(process_cpu_usage) if process_cpu_usage else 0,
                'max_memory_mb': np.max(memory_usage) if memory_usage else 0,
                'avg_inference_time': np.mean(inference_times),
                'std_inference_time': np.std(inference_times),
                'total_iterations': len(packet_predictions)
            },
            'prediction_summary': {
                'total_predictions': len(packet_predictions),
                'prediction_distribution': prediction_counts.to_dict() if not prediction_counts.empty else {},
                'avg_confidence': predictions_df['confidence'].mean() if not predictions_df.empty else 0,
                'confidence_std': predictions_df['confidence'].std() if not predictions_df.empty else 0,
                'error_rate': (predictions_df['prediction'] == 'error').sum() / len(predictions_df) * 100 if not predictions_df.empty else 0
            }
        }

        print(".3f"
              ".1f"
              ".3f")
        print(f"  📊 Packet Analysis: {len(packet_predictions)} predictions")
        if not prediction_counts.empty:
            print(f"     Prediction Distribution: {prediction_counts.to_dict()}")
            print(".3f"
                  ".1f")

        return results

def create_performance_plots(results_dict: Dict[str, Any], output_dir: str = "performance_data"):
    """Create comprehensive performance plots"""
    os.makedirs(output_dir, exist_ok=True)

    # Convert results to DataFrame for easier plotting
    all_data = []
    for model_results in results_dict.values():
        for measurement in model_results['measurements']:
            all_data.append({
                'timestamp': measurement['timestamp'],
                'model': measurement['model'],
                'system_cpu_percent': measurement['system_cpu_percent'],
                'process_cpu_percent': measurement['process_cpu_percent'],
                'memory_mb': measurement['memory_rss'],
                'system_memory_total_gb': measurement.get('system_memory_total_gb', 0),
                'system_memory_used_gb': measurement.get('system_memory_used_gb', 0),
                'cpu_cores_logical': measurement.get('cpu_cores_logical', 0),
                'cpu_cores_physical': measurement.get('cpu_cores_physical', 0),
                'phase': measurement['phase'],
                'iteration': measurement['iteration'],
                'inference_time': measurement.get('inference_time', 0)
            })

    df = pd.DataFrame(all_data)

    # Convert timestamps to relative time
    df['relative_time'] = df['timestamp'] - df['timestamp'].min()

    # Create individual model plots
    models = df['model'].unique()
    colors = sns.color_palette("husl", len(models))

    for i, model in enumerate(models):
        model_data = df[df['model'] == model].copy()

        # Individual model plot - 4 subplots: System CPU, Process CPU, Memory, Latency
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
        fig.suptitle(f'{model.upper()} Model Performance Monitoring', fontsize=16)

        # System CPU usage
        ax1.plot(model_data['relative_time'], model_data['system_cpu_percent'],
                color=colors[i], linewidth=2, alpha=0.7)
        ax1.fill_between(model_data['relative_time'], model_data['system_cpu_percent'],
                        alpha=0.3, color=colors[i])
        ax1.set_ylabel('System CPU (%)')
        ax1.set_title(f'{model.upper()} System CPU Usage')
        ax1.grid(True, alpha=0.3)

        # Process CPU usage
        ax2.plot(model_data['relative_time'], model_data['process_cpu_percent'],
                color=colors[i], linewidth=2, alpha=0.7)
        ax2.fill_between(model_data['relative_time'], model_data['process_cpu_percent'],
                        alpha=0.3, color=colors[i])
        ax2.set_ylabel('Process CPU (%)')
        ax2.set_title(f'{model.upper()} Process CPU Usage')
        ax2.grid(True, alpha=0.3)

        # Memory usage
        ax3.plot(model_data['relative_time'], model_data['memory_mb'],
                color=colors[i], linewidth=2, alpha=0.7)
        ax3.fill_between(model_data['relative_time'], model_data['memory_mb'],
                        alpha=0.3, color=colors[i])
        ax3.set_xlabel('Time (seconds)')
        ax3.set_ylabel('Memory (MB)')
        ax3.set_title(f'{model.upper()} Memory Usage')
        ax3.grid(True, alpha=0.3)

        # Latency (inference time)
        ax4.plot(model_data['relative_time'], model_data['inference_time'] * 1000,
                color=colors[i], linewidth=2, alpha=0.7, marker='o', markersize=3)
        ax4.fill_between(model_data['relative_time'], model_data['inference_time'] * 1000,
                        alpha=0.3, color=colors[i])
        ax4.set_xlabel('Time (seconds)')
        ax4.set_ylabel('Latency (ms)')
        ax4.set_title(f'{model.upper()} Inference Latency')
        ax4.grid(True, alpha=0.3)

        plt.tight_layout()
        plt.savefig(f'{output_dir}/{model}_performance.png', dpi=300, bbox_inches='tight')
        plt.close()

    # Combined plots - expanded to 3x2 grid to include both CPU metrics
    fig, ((ax1, ax2), (ax3, ax4), (ax5, ax6)) = plt.subplots(3, 2, figsize=(18, 15))
    fig.suptitle('AI Detection Models Performance Comparison', fontsize=16)

    # System CPU Usage - All models
    for i, model in enumerate(models):
        model_data = df[df['model'] == model]
        ax1.plot(model_data['relative_time'], model_data['system_cpu_percent'],
                color=colors[i], linewidth=2, label=model.upper(), alpha=0.7)

    ax1.set_ylabel('System CPU (%)')
    ax1.set_title('System CPU Usage Over Time')
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # Process CPU Usage - All models
    for i, model in enumerate(models):
        model_data = df[df['model'] == model]
        ax2.plot(model_data['relative_time'], model_data['process_cpu_percent'],
                color=colors[i], linewidth=2, label=model.upper(), alpha=0.7)

    ax2.set_ylabel('Process CPU (%)')
    ax2.set_title('Process CPU Usage Over Time')
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    # Memory Usage - All models
    for i, model in enumerate(models):
        model_data = df[df['model'] == model]
        ax3.plot(model_data['relative_time'], model_data['memory_mb'],
                color=colors[i], linewidth=2, label=model.upper(), alpha=0.7)

    ax3.set_ylabel('Memory (MB)')
    ax3.set_title('Memory Usage Over Time')
    ax3.legend()
    ax3.grid(True, alpha=0.3)

    # Latency - All models
    for i, model in enumerate(models):
        model_data = df[df['model'] == model]
        ax4.plot(model_data['relative_time'], model_data['inference_time'] * 1000,
                color=colors[i], linewidth=2, label=model.upper(), alpha=0.7, marker='o', markersize=2)

    ax4.set_ylabel('Latency (ms)')
    ax4.set_title('Inference Latency Over Time')
    ax4.legend()
    ax4.grid(True, alpha=0.3)

    # System CPU Box Plot
    sys_cpu_data = [df[df['model'] == model]['system_cpu_percent'].values for model in models]
    ax5.boxplot(sys_cpu_data, labels=[m.upper() for m in models])
    ax5.set_ylabel('System CPU (%)')
    ax5.set_title('System CPU Distribution')
    ax5.grid(True, alpha=0.3)

    # Process CPU Box Plot
    proc_cpu_data = [df[df['model'] == model]['process_cpu_percent'].values for model in models]
    ax6.boxplot(proc_cpu_data, labels=[m.upper() for m in models])
    ax6.set_ylabel('Process CPU (%)')
    ax6.set_title('Process CPU Distribution')
    ax6.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/combined_performance.png', dpi=300, bbox_inches='tight')
    plt.close()

    print(f"\n📊 Performance plots saved to '{output_dir}' directory")

def create_performance_table(results_dict: Dict[str, Any], output_dir: str = "performance_data"):
    """Create a comprehensive performance summary table (both markdown and image)"""
    print("\n📋 Generating Performance Summary Table...")

    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    # Create markdown table
    output_file = os.path.join(output_dir, "performance_summary.md")
    with open(output_file, 'w') as f:
        f.write("# AI Detection Models Performance Summary\n\n")
        f.write("## Comprehensive Performance Metrics\n\n")

        # Add system information header
        f.write("## System Configuration\n\n")

        # Get system specs from any model's results
        system_info = ""
        specs_found = False
        for stats in results_dict.values():
            if 'system_specs' in stats:
                specs = stats['system_specs']
                system_info = f"- **CPU Cores**: {specs.get('cpu_cores_physical', 'N/A')} physical, {specs.get('cpu_cores_logical', 'N/A')} logical\n"
                system_info += f"- **RAM**: {specs.get('memory_total_gb', 'N/A'):.1f} GB total\n"
                specs_found = True
                break

        if not specs_found:
            # Fallback: get system info directly
            import psutil
            cpu_physical = psutil.cpu_count(logical=False)
            cpu_logical = psutil.cpu_count(logical=True)
            memory = psutil.virtual_memory()
            memory_total_gb = memory.total / (1024**3)
            system_info = f"- **CPU Cores**: {cpu_physical} physical, {cpu_logical} logical\n"
            system_info += f"- **RAM**: {memory_total_gb:.1f} GB total\n"

        f.write(system_info + "\n")

        f.write("## Performance Metrics\n\n")

        # Main performance table with comprehensive metrics
        f.write("| Model | Size | Peak Sys CPU (%) | Peak Proc CPU (%) | Avg Sys CPU (%) | Avg Proc CPU (%) | Peak Memory (MB) | Avg Memory (MB) | Packet Count | Preprocess (ms) | Predict (ms) | End-to-End (ms) | Throughput (samp/sec) |\n")
        f.write("|-------|------|------------------|-------------------|-----------------|-----------------|------------------|-----------------|--------------|-----------------|--------------|-----------------|---------------------|\n")

        for model_name, stats in results_dict.items():
            model_display = model_name.upper()

            # Extract metrics from combined results
            size = format_size(stats['model_size_mb']) if 'model_size_mb' in stats else "N/A"
            peak_system_cpu = f"{stats['peak_system_cpu_percent']:.1f}" if 'peak_system_cpu_percent' in stats else "N/A"
            peak_process_cpu = f"{stats['peak_process_cpu_percent']:.1f}" if 'peak_process_cpu_percent' in stats else "N/A"
            avg_system_cpu = f"{stats['avg_system_cpu_percent']:.1f}" if 'avg_system_cpu_percent' in stats else "N/A"
            avg_process_cpu = f"{stats['avg_process_cpu_percent']:.1f}" if 'avg_process_cpu_percent' in stats else "N/A"
            peak_memory = f"{stats['peak_memory_mb']:.1f}" if 'peak_memory_mb' in stats else "N/A"
            avg_memory = f"{stats['avg_memory_mb']:.1f}" if 'avg_memory_mb' in stats else "N/A"
            packet_count = stats['packet_count'] if 'packet_count' in stats else "N/A"

            # Extract prediction metrics
            prediction_summary = stats.get('prediction_summary', {})
            total_predictions = prediction_summary.get('total_predictions', 0)
            avg_confidence = f"{prediction_summary.get('avg_confidence', 0):.3f}" if prediction_summary.get('avg_confidence', 0) > 0 else "N/A"
            preprocess = f"{stats['preprocessing']['mean'] * 1000:.3f}" if 'preprocessing' in stats else "N/A"
            predict = f"{stats['prediction']['mean'] * 1000:.3f}" if 'prediction' in stats else "N/A"
            end_to_end = f"{stats['end_to_end']['mean'] * 1000:.3f}" if 'end_to_end' in stats else "N/A"
            throughput = f"{stats['batch_prediction']['throughput']:.1f}" if 'batch_prediction' in stats else "N/A"

            f.write(f"| {model_display} | {size} | {peak_system_cpu} | {peak_process_cpu} | {avg_system_cpu} | {avg_process_cpu} | {peak_memory} | {avg_memory} | {packet_count} | {preprocess} | {predict} | {end_to_end} | {throughput} |\n")

        f.write("\n")
        f.write("## Detailed Statistics\n\n")

        for model_name, stats in results_dict.items():
            model_display = model_name.upper()
            f.write(f"### {model_display} Model\n\n")

            # Model size
            if 'model_size_mb' in stats:
                f.write(f"- **Model Size**: {format_size(stats['model_size_mb'])}\n")

            # Timing metrics
            if 'preprocessing' in stats:
                f.write(f"- **Preprocessing Time**: {stats['preprocessing']['mean']*1000:.3f}ms ±{stats['preprocessing']['std']*1000:.3f}ms\n")
            if 'prediction' in stats:
                f.write(f"- **Prediction Time**: {stats['prediction']['mean']*1000:.3f}ms ±{stats['prediction']['std']*1000:.3f}ms\n")
            if 'end_to_end' in stats:
                f.write(f"- **End-to-End Time**: {stats['end_to_end']['mean']*1000:.3f}ms ±{stats['end_to_end']['std']*1000:.3f}ms\n")
            if 'batch_prediction' in stats:
                f.write(f"- **Throughput**: {stats['batch_prediction']['throughput']:.1f} samples/sec\n")
                f.write(f"- **Batch Prediction Time**: {stats['batch_prediction']['mean']*1000:.3f}ms ±{stats['batch_prediction']['std']*1000:.3f}ms\n")

            # Resource metrics
            if 'peak_system_cpu_percent' in stats:
                f.write(f"- **Peak System CPU Usage**: {stats['peak_system_cpu_percent']:.1f}%\n")
            if 'peak_process_cpu_percent' in stats:
                f.write(f"- **Peak Process CPU Usage**: {stats['peak_process_cpu_percent']:.1f}%\n")
            if 'avg_system_cpu_percent' in stats:
                f.write(f"- **Average System CPU Usage**: {stats['avg_system_cpu_percent']:.1f}%\n")
            if 'avg_process_cpu_percent' in stats:
                f.write(f"- **Average Process CPU Usage**: {stats['avg_process_cpu_percent']:.1f}%\n")
            if 'peak_memory_mb' in stats:
                f.write(f"- **Peak Memory Usage**: {stats['peak_memory_mb']:.1f} MB\n")
            if 'avg_memory_mb' in stats:
                f.write(f"- **Average Memory Usage**: {stats['avg_memory_mb']:.1f} MB\n")
            if 'packet_count' in stats:
                f.write(f"- **Packets Processed**: {stats['packet_count']}\n")

            # Prediction Analysis
            if 'prediction_summary' in stats:
                pred_summary = stats['prediction_summary']
                f.write(f"- **Total Predictions**: {pred_summary.get('total_predictions', 0)}\n")
                if pred_summary.get('prediction_distribution'):
                    f.write(f"- **Prediction Distribution**: {pred_summary['prediction_distribution']}\n")
                if pred_summary.get('avg_confidence', 0) > 0:
                    f.write(f"- **Average Confidence**: {pred_summary['avg_confidence']:.3f}\n")
                if pred_summary.get('error_rate', 0) > 0:
                    f.write(f"- **Error Rate**: {pred_summary['error_rate']:.2f}%\n")

            # Legacy stats (if present)
            if 'std_cpu_percent' in stats and 'std_cpu_percent' in stats:
                f.write(f"- **CPU Usage Std**: {stats['std_cpu_percent']:.1f}%\n")
            if 'std_memory_mb' in stats:
                f.write(f"- **Memory Usage Std**: {stats['std_memory_mb']:.1f} MB\n")
            if 'avg_inference_time' in stats and 'preprocessing' not in stats:  # Only show if not already shown above
                f.write(f"- **Average Latency**: {stats['avg_inference_time']*1000:.3f} ms\n")
            if 'total_iterations' in stats and 'packet_count' not in stats:
                f.write(f"- **Total Iterations**: {stats['total_iterations']}\n")

            f.write("\n")

    # Create table image
    create_performance_table_image(results_dict, output_dir)

    print(f"✅ Performance summary table saved to '{output_file}'")
    print(f"✅ Performance table image saved to '{output_dir}/performance_table.png'")


def create_performance_table_image(results_dict: Dict[str, Any], output_dir: str = "performance_data"):
    """Create a visual table image of the performance summary"""
    print("\n🖼️ Generating Performance Table Image...")

    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    # Prepare data for the table
    models = []
    data_rows = []

    for model_name, stats in results_dict.items():
        model_display = model_name.upper()

        # Extract metrics from combined results
        size = format_size(stats['model_size_mb']) if 'model_size_mb' in stats else "N/A"
        peak_system_cpu = f"{stats['peak_system_cpu_percent']:.1f}" if 'peak_system_cpu_percent' in stats else "N/A"
        peak_process_cpu = f"{stats['peak_process_cpu_percent']:.1f}" if 'peak_process_cpu_percent' in stats else "N/A"
        avg_system_cpu = f"{stats['avg_system_cpu_percent']:.1f}" if 'avg_system_cpu_percent' in stats else "N/A"
        avg_process_cpu = f"{stats['avg_process_cpu_percent']:.1f}" if 'avg_process_cpu_percent' in stats else "N/A"
        peak_memory = f"{stats['peak_memory_mb']:.1f}" if 'peak_memory_mb' in stats else "N/A"
        avg_memory = f"{stats['avg_memory_mb']:.1f}" if 'avg_memory_mb' in stats else "N/A"
        packet_count = stats['packet_count'] if 'packet_count' in stats else "N/A"
        preprocess = f"{stats['preprocessing']['mean'] * 1000:.3f}" if 'preprocessing' in stats else "N/A"
        predict = f"{stats['prediction']['mean'] * 1000:.3f}" if 'prediction' in stats else "N/A"
        end_to_end = f"{stats['end_to_end']['mean'] * 1000:.3f}" if 'end_to_end' in stats else "N/A"
        throughput = f"{stats['batch_prediction']['throughput']:.1f}" if 'batch_prediction' in stats else "N/A"

        models.append(model_display)
        data_rows.append([size, peak_system_cpu, peak_process_cpu, avg_system_cpu, avg_process_cpu, peak_memory, avg_memory, packet_count,
                         preprocess, predict, end_to_end, throughput])

    # Column headers
    columns = ['Size', 'Peak Sys CPU (%)', 'Peak Proc CPU (%)', 'Avg Sys CPU (%)', 'Avg Proc CPU (%)',
               'Peak Memory (MB)', 'Avg Memory (MB)', 'Packet Count', 'Preprocess (ms)', 'Predict (ms)',
               'End-to-End (ms)', 'Throughput\n(samp/sec)']

    # Create figure and axis
    fig, ax = plt.subplots(figsize=(20, 8))
    ax.axis('tight')
    ax.axis('off')

    # Create table
    table = ax.table(cellText=data_rows,
                    rowLabels=models,
                    colLabels=columns,
                    cellLoc='center',
                    loc='center',
                    colWidths=[0.06, 0.07, 0.07, 0.07, 0.07, 0.08, 0.08, 0.06, 0.07, 0.06, 0.07, 0.1])

    # Style the table
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1.2, 2)

    # Style header row
    for i, cell in enumerate(table.get_celld().values()):
        if cell.get_text().get_text() in columns:
            cell.set_fontsize(11)
            cell.set_text_props(weight='bold')
            cell.set_facecolor('#e6f3ff')  # Light blue header

    # Style row labels (model names) - they are in the (-1, i+1) position
    for i, model in enumerate(models):
        try:
            cell = table.get_celld()[(-1, i)]  # Row labels are at (-1, column_index)
            cell.set_fontsize(11)
            cell.set_text_props(weight='bold')
            cell.set_facecolor('#f0f0f0')  # Light gray for model names
        except KeyError:
            # If styling fails, continue - table will still work
            pass

    # Add title with system information
    # Get system specs from data
    system_info = "System: "
    if data_rows and len(data_rows) > 0:
        # Try to get system specs from the first measurement
        for model_results in results_dict.values():
            if 'measurements' in model_results and model_results['measurements']:
                first_measurement = model_results['measurements'][0]
                cpu_physical = first_measurement.get('cpu_cores_physical', 'N/A')
                cpu_logical = first_measurement.get('cpu_cores_logical', 'N/A')
                mem_total = first_measurement.get('system_memory_total_gb', 'N/A')
                system_info += f"{cpu_physical} cores, {mem_total:.1f}GB RAM"
                break

    plt.title('AI Detection Models Performance Summary\nComprehensive Performance Metrics',
              fontsize=16, fontweight='bold', pad=20)

    # Add subtitle with timestamp and system info
    from datetime import datetime
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    plt.suptitle(f'{system_info} | Generated on {timestamp}', fontsize=10, y=0.95, style='italic')

    # Adjust layout and save
    plt.tight_layout()
    output_file = os.path.join(output_dir, "performance_table.png")
    plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()

    print(f"✅ Performance table image saved to '{output_file}'")

def main():
    """Main performance monitoring workflow"""
    print("🚀 AI Detection Model Performance Monitoring")
    print("=" * 50)

    # Display system information
    import psutil
    cpu_physical = psutil.cpu_count(logical=False)
    cpu_logical = psutil.cpu_count(logical=True)
    memory = psutil.virtual_memory()
    memory_total_gb = memory.total / (1024**3)

    print("🖥️  System Configuration:")
    print(f"- CPUs: {cpu_physical} physical cores, {cpu_logical} logical cores")
    print(f"- RAM: {memory_total_gb:.1f} GB total")
    print("=" * 50)

    # Import benchmark function
    from test_models import benchmark_models

    # Run comprehensive benchmarks (includes latency, throughput, timing, etc.)
    print("Running comprehensive performance benchmarks...")
    benchmark_results = benchmark_models(num_iterations=25, batch_size=16)

    # Also run resource monitoring for CPU/Memory metrics
    models_to_test = ['cnn', 'mlp', 'rnn', 'lstm', 'gru', 'autoencoder']
    monitor = PerformanceMonitor()
    resource_results = {}

    # Determine how many packets to process
    try:
        sample_df = pd.read_csv('./dos.csv')
        total_available_packets = len(sample_df)
        # Process all packets, but limit to reasonable number for performance monitoring
        packets_to_process = min(total_available_packets, 500)  # Process up to 500 packets for comprehensive monitoring
        print(f"\n🔍 Found {total_available_packets} packets in CSV. Processing {packets_to_process} for comprehensive monitoring...")
    except:
        packets_to_process = 100  # Fallback if CSV not available

    print(f"\n🚀 Running comprehensive resource monitoring on {packets_to_process} packets...")
    for model in models_to_test:
        try:
            print(f"\n🎯 Monitoring {model.upper()} with {packets_to_process} packets...")
            resource_results[model] = monitor.benchmark_model(model, num_iterations=packets_to_process, csv_file='./dos.csv')
        except Exception as e:
            print(f"❌ Failed to monitor {model}: {e}")
            continue

    # Merge results - use benchmark results as base, add resource metrics where available
    combined_results = {}
    for model in models_to_test:
        if model in benchmark_results:
            combined_results[model] = benchmark_results[model].copy()
            # Add resource metrics if available
            if model in resource_results:
                resource_stats = resource_results[model]['statistics']
                prediction_summary = resource_results[model]['prediction_summary']

                combined_results[model]['peak_system_cpu_percent'] = resource_stats['max_system_cpu_percent']
                combined_results[model]['peak_process_cpu_percent'] = resource_stats['max_process_cpu_percent']
                combined_results[model]['avg_system_cpu_percent'] = resource_stats['avg_system_cpu_percent']
                combined_results[model]['avg_process_cpu_percent'] = resource_stats['avg_process_cpu_percent']
                combined_results[model]['peak_memory_mb'] = resource_stats['max_memory_mb']
                combined_results[model]['avg_memory_mb'] = resource_stats['avg_memory_mb']
                combined_results[model]['packet_count'] = resource_stats['total_packets_processed']

                # Add prediction analysis
                combined_results[model]['prediction_summary'] = prediction_summary

                # Add system specs (they should be the same for all models)
                if 'system_specs' in resource_results[model]:
                    combined_results[model]['system_specs'] = resource_results[model]['system_specs']

    # Create visualizations using resource results (for time-series plots)
    if resource_results:
        create_performance_plots(resource_results, output_dir="performance_data")

    # Create comprehensive table using combined results
    if combined_results:
        create_performance_table(combined_results, output_dir="performance_data")

        print("\n" + "=" * 50)
        print("✅ Performance monitoring completed!")
        print("📊 Check 'performance_data/' for graphs and comprehensive performance table")
    else:
        print("❌ No results to visualize")

if __name__ == "__main__":
    main()
