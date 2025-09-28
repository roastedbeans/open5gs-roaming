#!/usr/bin/env python3
"""
CPU Performance Monitor - Following article's approach
Measures CPU utilization during inference like GPU utilization
"""

import time
import psutil
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from typing import Dict, List, Any
from predict import AIDetector
import gc
import platform

# Set plotting style
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

class CPUMonitor:
    """Monitor CPU usage following article's GPU monitoring approach"""

    def __init__(self):
        self.process = psutil.Process(os.getpid())
        # Initialize CPU tracking (first call returns 0)
        self.process.cpu_percent()
        time.sleep(0.1)

    def _reset_monitor(self):
        """Reset CPU monitor state to ensure clean measurements"""
        # Reinitialize CPU tracking
        self.process.cpu_percent()
        # Allow time for CPU measurement to stabilize
        time.sleep(0.5)
        # Take a few initial measurements to stabilize
        for _ in range(3):
            self.process.cpu_percent(interval=0.1)

    def measure_with_warmup(self, detector, model_type: str, data_batch,
                           warmup_iterations: int = 50) -> Dict[str, Any]:
        """
        Measure CPU following article approach:
        1. Extensive warm-up (50+ iterations)
        2. Measure CPU during actual work
        3. Report averages (mean values)
        """
        
        # WARM-UP PHASE (article recommends 50-200)
        print(f"  🔄 Warm-up: {warmup_iterations} iterations...")
        for i in range(min(warmup_iterations, len(data_batch))):
            detector.predict_single(data_batch.iloc[i], model_type=model_type)
        
        # Force cleanup after warmup
        gc.collect()
        time.sleep(0.2)
        
        # MEASUREMENT PHASE
        cpu_samples = []
        memory_samples = []
        end_to_end_latencies = []
        preprocess_latencies = []
        predict_latencies = []
        measurements = []

        print(f"  📊 Measuring {len(data_batch)} inferences...")

        for idx, (_, packet) in enumerate(data_batch.iterrows()):
            # Get CPU before inference
            cpu_before = self.process.cpu_percent(interval=None)

            # Start end-to-end timing
            start_time = time.perf_counter()

            # Preprocessing phase timing
            preprocess_start = time.perf_counter()
            X_tensor = detector.preprocess_data(packet, model_type)
            preprocess_end = time.perf_counter()

            # Prediction phase timing
            predict_start = time.perf_counter()
            detector.predict_single(packet, model_type=model_type)
            predict_end = time.perf_counter()

            # End end-to-end timing
            end_time = time.perf_counter()

            # Get CPU after inference
            cpu_after = self.process.cpu_percent(interval=None)

            # Get memory usage (like GPU memory in article)
            mem_info = self.process.memory_info()
            memory_mb = mem_info.uss / 1024 / 1024 if hasattr(mem_info, 'uss') else mem_info.rss / 1024 / 1024

            # Calculate metrics
            end_to_end_latency_ms = (end_time - start_time) * 1000
            preprocess_latency_ms = (preprocess_end - preprocess_start) * 1000
            predict_latency_ms = (predict_end - predict_start) * 1000
            cpu_percent = max(cpu_before, cpu_after)  # Take max of before/after

            cpu_samples.append(cpu_percent)
            memory_samples.append(memory_mb)
            end_to_end_latencies.append(end_to_end_latency_ms)
            preprocess_latencies.append(preprocess_latency_ms)
            predict_latencies.append(predict_latency_ms)

            # Store for output compatibility
            measurements.append({
                'timestamp': time.time(),
                'model': model_type,
                'cpu_percent': cpu_percent,
                'memory_mb': memory_mb,
                'end_to_end_latency_ms': end_to_end_latency_ms,
                'preprocess_latency_ms': preprocess_latency_ms,
                'predict_latency_ms': predict_latency_ms,
                'iteration': idx
            })

            # Progress
            if (idx + 1) % 100 == 0:
                print(f"    Progress: {idx + 1}/{len(data_batch)}")
        
        # CALCULATE STATISTICS (following article's approach)
        cpu_array = np.array(cpu_samples)
        memory_array = np.array(memory_samples)
        end_to_end_array = np.array(end_to_end_latencies)
        preprocess_array = np.array(preprocess_latencies)
        predict_array = np.array(predict_latencies)

        # Remove outliers (>3 std from median) for CPU and memory
        cpu_median = np.median(cpu_array)
        cpu_std = np.std(cpu_array)
        cpu_mask = np.abs(cpu_array - cpu_median) <= 3 * cpu_std
        clean_cpu = cpu_array[cpu_mask]

        memory_median = np.median(memory_array)
        memory_std = np.std(memory_array)
        memory_mask = np.abs(memory_array - memory_median) <= 3 * memory_std
        clean_memory = memory_array[memory_mask]

        # Remove outliers for all latency types
        e2e_median = np.median(end_to_end_array)
        e2e_std = np.std(end_to_end_array)
        e2e_mask = np.abs(end_to_end_array - e2e_median) <= 3 * e2e_std
        clean_end_to_end = end_to_end_array[e2e_mask]

        preprocess_median = np.median(preprocess_array)
        preprocess_std = np.std(preprocess_array)
        preprocess_mask = np.abs(preprocess_array - preprocess_median) <= 3 * preprocess_std
        clean_preprocess = preprocess_array[preprocess_mask]

        predict_median = np.median(predict_array)
        predict_std = np.std(predict_array)
        predict_mask = np.abs(predict_array - predict_median) <= 3 * predict_std
        clean_predict = predict_array[predict_mask]

        # Calculate throughput (samples per second) based on end-to-end latency
        avg_latency_sec = np.mean(clean_end_to_end) / 1000
        throughput = 1.0 / avg_latency_sec if avg_latency_sec > 0 else 0
        
        return {
            'model': model_type,
            'measurements': measurements,
            'cpu_mean': np.mean(clean_cpu),
            'cpu_median': np.median(clean_cpu),
            'memory_mean_mb': np.mean(clean_memory),
            'memory_median_mb': np.median(clean_memory),
            'end_to_end_latency_mean_ms': np.mean(clean_end_to_end),
            'end_to_end_latency_median_ms': np.median(clean_end_to_end),
            'preprocess_latency_mean_ms': np.mean(clean_preprocess),
            'preprocess_latency_median_ms': np.median(clean_preprocess),
            'predict_latency_mean_ms': np.mean(clean_predict),
            'predict_latency_median_ms': np.median(clean_predict),
            'throughput_samples_per_sec': throughput,
            'num_samples': len(clean_cpu)
        }

def _force_memory_cleanup():
    """Force aggressive memory cleanup and reset to prevent carry-over between models"""
    import gc

    # Clear PyTorch cache safely
    try:
        import torch
        # Clear CUDA cache if available
        if hasattr(torch, 'cuda') and torch.cuda.is_available():
            torch.cuda.empty_cache()
            try:
                torch.cuda.synchronize()
            except:
                pass

        # Clear CPU cache if available
        try:
            if hasattr(torch, 'cpu'):
                torch.cpu.empty_cache()
        except:
            pass
    except ImportError:
        pass  # PyTorch not available
    except Exception:
        pass  # Any other PyTorch error

    # Force garbage collection multiple times with different generations
    for generation in range(3):
        gc.collect(generation)

    # Try to release memory back to OS (platform dependent)
    try:
        import ctypes
        if hasattr(ctypes, 'CDLL'):
            try:
                # Try to call malloc_trim on Linux to release memory to OS
                libc = ctypes.CDLL('libc.so.6')
                libc.malloc_trim(0)
            except:
                pass
    except:
        pass

    # Allow time for system to stabilize after cleanup
    time.sleep(0.5)

def _reset_process_state():
    """Reset process state to ensure clean measurements"""
    try:
        import resource
        # Reset resource usage counters if possible
        resource.setrlimit(resource.RLIMIT_AS, (-1, -1))  # Reset address space limit
    except:
        pass

def benchmark_all_models(num_packets: int = 500) -> Dict[str, Any]:
    """Benchmark all models using article's approach with complete memory isolation"""

    print("🚀 CPU Performance Monitoring (Article Approach)")
    print("=" * 60)

    # Initial system cleanup before starting any benchmarks
    print("🧹 Initial system cleanup...")
    _force_memory_cleanup()
    _reset_process_state()

    # System info
    print(f"System: {psutil.cpu_count()} CPU cores, "
          f"{psutil.virtual_memory().total / (1024**3):.1f}GB RAM\n")

    # Load data
    try:
        df = pd.read_csv('./dos.csv').head(num_packets)
        print(f"✅ Loaded {len(df)} packets for benchmarking\n")
    except Exception as e:
        print(f"❌ Error loading data: {e}")
        return {}

    results = {}
    models = ['cnn', 'mlp', 'rnn', 'lstm', 'gru', 'autoencoder']

    for model_type in models:
        print(f"\n{'='*40}")
        print(f"Benchmarking {model_type.upper()}")
        print(f"{'='*40}")

        try:
            # Aggressive memory cleanup and reset before starting new model
            print("  🧹 Performing memory cleanup and reset...")
            _force_memory_cleanup()

            # Create fresh monitor instance for each model to avoid carry-over effects
            monitor = CPUMonitor()

            # Add stabilization period between models
            print("  ⏳ Stabilizing system...")
            time.sleep(1.5)

            # Create fresh detector instance (this will load the model into memory)
            detector = AIDetector()

            # Reset CPU monitor state after model loading
            monitor._reset_monitor()

            # Additional stabilization after model loading
            time.sleep(0.5)

            # Measure with warm-up
            result = monitor.measure_with_warmup(
                detector,
                model_type,
                df,
                warmup_iterations=50  # Article recommends 50-200
            )

            # Print results (averages only)
            print(f"\n📊 {model_type.upper()} Results:")
            print(f"  CPU Utilization: {result['cpu_mean']:.1f}%")
            print(f"  Memory Usage: {result['memory_mean_mb']:.1f}MB")
            print(f"  End-to-End Latency: {result['end_to_end_latency_mean_ms']:.2f}ms")
            print(f"  Preprocessing Latency: {result['preprocess_latency_mean_ms']:.2f}ms")
            print(f"  Prediction Latency: {result['predict_latency_mean_ms']:.2f}ms")
            print(f"  Throughput: {result['throughput_samples_per_sec']:.1f} samples/sec")

            results[model_type] = result

            # Aggressive cleanup after each model to ensure clean state for next model
            print("  🧽 Final cleanup for next model...")
            _force_memory_cleanup()

            # Delete objects explicitly
            del detector
            del monitor

            # Additional cleanup and stabilization
            gc.collect()
            gc.collect()  # Double collect
            gc.collect()  # Triple collect for thorough cleanup

            # Longer stabilization between models to ensure complete reset
            time.sleep(5.0)

        except Exception as e:
            print(f"  ❌ Error: {e}")
            # Still try to cleanup even on error
            try:
                del detector, monitor
                _force_memory_cleanup()
            except:
                pass

    return results

def create_cpu_plots(results: Dict[str, Any], output_dir: str = "performance_data"):
    """Create separate CPU and memory utilization plots with averages"""
    os.makedirs(output_dir, exist_ok=True)

    models = list(results.keys())
    colors = sns.color_palette("husl", len(models))

    # 1. CPU utilization plot
    fig, ax = plt.subplots(figsize=(10, 6))
    cpu_values = [results[m]['cpu_mean'] for m in models]

    bars = ax.bar(models, cpu_values, color=colors, alpha=0.8)
    ax.set_xlabel('Model', fontsize=12)
    ax.set_ylabel('CPU Utilization (%)', fontsize=12)
    ax.set_title('Average CPU Utilization by Model', fontsize=14, fontweight='bold')
    ax.set_xticks(range(len(models)))
    ax.set_xticklabels([m.upper() for m in models])
    ax.grid(True, alpha=0.3, axis='y')

    # Add value labels on bars
    max_value = max(cpu_values)
    min_value = min(cpu_values)
    y_range = max_value - min_value
    offset = y_range * 0.03  # 3% of the y-axis range as offset
    for bar, value in zip(bars, cpu_values):
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height + offset,
                f'{value:.1f}', ha='center', va='bottom', fontsize=10)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/cpu_utilization.png', dpi=150, bbox_inches='tight')
    plt.close()

    # 2. Memory usage plot
    fig, ax = plt.subplots(figsize=(10, 6))
    memory_values = [results[m]['memory_mean_mb'] for m in models]

    bars = ax.bar(models, memory_values, color=colors, alpha=0.8)
    ax.set_xlabel('Model', fontsize=12)
    ax.set_ylabel('Memory Usage (MB)', fontsize=12)
    ax.set_title('Average Memory Usage by Model', fontsize=14, fontweight='bold')
    ax.set_xticks(range(len(models)))
    ax.set_xticklabels([m.upper() for m in models])
    ax.grid(True, alpha=0.3, axis='y')

    # Set y-axis to start from a value just below minimum to show differences
    min_memory = min(memory_values)
    max_memory = max(memory_values)
    y_margin = (max_memory - min_memory) * 0.1  # 10% margin
    ax.set_ylim(bottom=max(0, min_memory - y_margin), top=max_memory + y_margin)

    # Add value labels on bars
    max_value = max(memory_values)
    min_value = min(memory_values)
    y_range = max_value - min_value
    offset = y_range * 0.03  # 3% of the y-axis range as offset
    for bar, value in zip(bars, memory_values):
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height + offset,
                f'{value:.1f}', ha='center', va='bottom', fontsize=10)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/memory_usage.png', dpi=150, bbox_inches='tight')
    plt.close()

    # 3. Throughput plot
    fig, ax = plt.subplots(figsize=(10, 6))
    throughput_values = [results[m]['throughput_samples_per_sec'] for m in models]

    bars = ax.bar(models, throughput_values, color=colors, alpha=0.8)
    ax.set_xlabel('Model', fontsize=12)
    ax.set_ylabel('Throughput (samples/sec)', fontsize=12)
    ax.set_title('Average Throughput by Model', fontsize=14, fontweight='bold')
    ax.set_xticks(range(len(models)))
    ax.set_xticklabels([m.upper() for m in models])
    ax.grid(True, alpha=0.3, axis='y')

    # Add value labels on bars
    max_value = max(throughput_values)
    min_value = min(throughput_values)
    y_range = max_value - min_value
    offset = y_range * 0.03  # 3% of the y-axis range as offset
    for bar, value in zip(bars, throughput_values):
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height + offset,
                f'{value:.0f}', ha='center', va='bottom', fontsize=10)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/throughput.png', dpi=150, bbox_inches='tight')
    plt.close()

    # 4. Latency breakdown plot (end-to-end, preprocessing, prediction)
    fig, ax = plt.subplots(figsize=(12, 8))

    x = np.arange(len(models))
    width = 0.25

    e2e_values = [results[m]['end_to_end_latency_mean_ms'] for m in models]
    preprocess_values = [results[m]['preprocess_latency_mean_ms'] for m in models]
    predict_values = [results[m]['predict_latency_mean_ms'] for m in models]

    bars1 = ax.bar(x - width, e2e_values, width, label='End-to-End', alpha=0.8, color='skyblue')
    bars2 = ax.bar(x, preprocess_values, width, label='Preprocessing', alpha=0.8, color='lightcoral')
    bars3 = ax.bar(x + width, predict_values, width, label='Prediction', alpha=0.8, color='lightgreen')

    ax.set_xlabel('Model', fontsize=12)
    ax.set_ylabel('Latency (ms)', fontsize=12)
    ax.set_title('Latency Breakdown by Model', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([m.upper() for m in models])
    ax.legend()
    ax.grid(True, alpha=0.3, axis='y')

    # Add value labels on bars
    for bars, values in [(bars1, e2e_values), (bars2, preprocess_values), (bars3, predict_values)]:
        for bar, value in zip(bars, values):
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height + 0,
                    f'{value:.1f}', ha='center', va='bottom', fontsize=8)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/latency_breakdown.png', dpi=150, bbox_inches='tight')
    plt.close()

    # Create summary table
    create_summary_table(results, output_dir)

    print(f"\n✅ Individual plots saved to {output_dir}/")

def create_summary_table(results: Dict[str, Any], output_dir: str):
    """Create summary table with averages"""

    # Prepare data
    data = []
    for model, stats in results.items():
        data.append([
            model.upper(),
            f"{stats['cpu_mean']:.1f}%",
            f"{stats['memory_mean_mb']:.1f}MB",
            f"{stats['end_to_end_latency_mean_ms']:.2f}ms",
            f"{stats['preprocess_latency_mean_ms']:.2f}ms",
            f"{stats['predict_latency_mean_ms']:.2f}ms",
            f"{stats['throughput_samples_per_sec']:.0f}"
        ])

    # Create table plot
    fig, ax = plt.subplots(figsize=(16, 6))
    ax.axis('tight')
    ax.axis('off')

    columns = ['Model', 'CPU Average', 'Memory Average', 'End-to-End Latency', 'Preprocessing Latency', 'Prediction Latency', 'Throughput']
    
    table = ax.table(cellText=data,
                    colLabels=columns,
                    cellLoc='center',
                    loc='center')
    
    table.auto_set_font_size(False)
    table.set_fontsize(11)
    table.scale(1.1, 2)

    # Style header
    for i in range(len(columns)):
        table[(0, i)].set_facecolor('#e6f3ff')
        table[(0, i)].set_text_props(weight='bold')

    plt.title('Performance Summary Table (Averages)',
              fontsize=14, fontweight='bold', pad=20)
    
    plt.savefig(f'{output_dir}/performance_table.png', dpi=150, bbox_inches='tight')
    plt.close()

def create_summary_text_file(results: Dict[str, Any], df: pd.DataFrame, output_dir: str = "performance_data"):
    """Create a comprehensive text summary file"""

    os.makedirs(output_dir, exist_ok=True)
    summary_file = os.path.join(output_dir, "performance_summary.txt")

    with open(summary_file, 'w') as f:
        # Header
        f.write("=" * 80 + "\n")
        f.write("AI DETECTION SYSTEM PERFORMANCE SUMMARY\n")
        f.write("=" * 80 + "\n")
        f.write(f"Generated on: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")

        # System Information
        f.write("SYSTEM INFORMATION\n")
        f.write("-" * 30 + "\n")

        # Basic system info
        f.write(f"Platform: {platform.system()} {platform.release()}\n")
        f.write(f"Architecture: {platform.machine()}\n")
        f.write(f"Python Version: {platform.python_version()}\n")

        # CPU Information
        cpu_count = psutil.cpu_count()
        cpu_count_logical = psutil.cpu_count(logical=True)
        f.write(f"CPU Cores: {cpu_count} physical, {cpu_count_logical} logical\n")

        # Memory Information
        mem = psutil.virtual_memory()
        total_mem_gb = mem.total / (1024**3)
        available_mem_gb = mem.available / (1024**3)
        f.write(f"Total Memory: {total_mem_gb:.1f} GB\n")
        f.write(f"Available Memory: {available_mem_gb:.1f} GB\n")

        # Docker Information (if running in container)
        f.write("\nDOCKER INFORMATION\n")
        f.write("-" * 20 + "\n")

        try:
            # Check if running in Docker
            with open('/proc/1/cgroup', 'r') as cgroup_file:
                cgroup_content = cgroup_file.read()
                if 'docker' in cgroup_content.lower() or 'containerd' in cgroup_content.lower():
                    f.write("Running in Docker: Yes\n")

                    # Try to get container resource limits
                    try:
                        # Check CPU limits
                        with open('/sys/fs/cgroup/cpu/cpu.shares', 'r') as cpu_shares:
                            shares = int(cpu_shares.read().strip())
                            if shares > 0:
                                f.write(f"CPU Shares: {shares}\n")

                        # Check memory limits
                        with open('/sys/fs/cgroup/memory/memory.limit_in_bytes', 'r') as mem_limit:
                            limit_bytes = int(mem_limit.read().strip())
                            if limit_bytes < 2**60:  # Not unlimited
                                limit_gb = limit_bytes / (1024**3)
                                f.write(f"Memory Limit: {limit_gb:.1f} GB\n")
                    except:
                        f.write("Container resource limits: Unable to determine\n")
                else:
                    f.write("Running in Docker: No\n")
        except:
            f.write("Docker detection: Unable to determine\n")

        # Dataset Information
        f.write("\nDATASET INFORMATION\n")
        f.write("-" * 20 + "\n")
        f.write(f"CSV File: dos.csv\n")
        f.write(f"Total Packets: {len(df)}\n")
        f.write(f"Features per packet: {len(df.columns)}\n")
        f.write(f"Packet types: {', '.join(df.columns[:5])}... (showing first 5)\n")

        # Performance Results
        f.write("\nPERFORMANCE RESULTS\n")
        f.write("-" * 20 + "\n")

        # Summary table in text format
        f.write("\nPERFORMANCE SUMMARY TABLE\n")
        f.write("-" * 100 + "\n")

        # Header
        header = f"{'Model':<10} {'CPU (%)':<8} {'Memory (MB)':<12} {'End-to-End (ms)':<15} {'Preprocess (ms)':<15} {'Predict (ms)':<12} {'Throughput':<10}"
        f.write(header + "\n")
        f.write("-" * 100 + "\n")

        # Data rows
        for model_name, stats in results.items():
            row = f"{model_name.upper():<10} "
            row += f"{stats['cpu_mean']:<8.1f} "
            row += f"{stats['memory_mean_mb']:<12.1f} "
            row += f"{stats['end_to_end_latency_mean_ms']:<15.2f} "
            row += f"{stats['preprocess_latency_mean_ms']:<15.2f} "
            row += f"{stats['predict_latency_mean_ms']:<12.2f} "
            row += f"{stats['throughput_samples_per_sec']:<10.0f}"
            f.write(row + "\n")

        f.write("-" * 100 + "\n")

        # Detailed breakdown for each model
        f.write("\nDETAILED RESULTS PER MODEL\n")
        f.write("-" * 30 + "\n")

        for model_name, stats in results.items():
            f.write(f"\n{model_name.upper()} Model:\n")
            f.write("-" * (len(model_name) + 7) + "\n")
            f.write(f"  CPU Utilization:     {stats['cpu_mean']:.1f}%\n")
            f.write(f"  Memory Usage:        {stats['memory_mean_mb']:.1f} MB\n")
            f.write(f"  End-to-End Latency:  {stats['end_to_end_latency_mean_ms']:.2f} ms\n")
            f.write(f"  Preprocessing Time:  {stats['preprocess_latency_mean_ms']:.2f} ms\n")
            f.write(f"  Prediction Time:     {stats['predict_latency_mean_ms']:.2f} ms\n")
            f.write(f"  Throughput:          {stats['throughput_samples_per_sec']:.0f} samples/sec\n")
            f.write(f"  Samples Processed:   {stats['num_samples']}\n")

        # Footer
        f.write("\n" + "=" * 80 + "\n")
        f.write("END OF PERFORMANCE SUMMARY\n")
        f.write("=" * 80 + "\n")

    print(f"\n✅ Summary text file saved to {summary_file}")
    return summary_file

def main():
    """Main function"""
    import argparse
    parser = argparse.ArgumentParser(description='AI Detection System Performance Benchmark')
    parser.add_argument('--limit', type=int, default=500,
                       help='Maximum number of packets to use for benchmarking (default: 500)')
    args = parser.parse_args()
    
    # Load data
    try:
        df = pd.read_csv('./dos.csv').head(args.limit)
        print(f"✅ Loaded {len(df)} packets for benchmarking\n")
    except Exception as e:
        print(f"❌ Error loading data: {e}")
        return

    # Run benchmarks
    results = benchmark_all_models(args.limit)

    # Create plots and summary
    if results:
        create_cpu_plots(results)
        create_summary_text_file(results, df)
        print("\n✅ Benchmarking completed!")

if __name__ == "__main__":
    main()