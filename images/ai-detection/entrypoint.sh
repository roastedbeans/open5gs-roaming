#!/bin/bash

set -e

# Default values
COMMAND="server"
HOST="0.0.0.0"
PORT="8000"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--command)
            COMMAND="$2"
            shift 2
            ;;
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        --test)
            COMMAND="test"
            shift
            ;;
        --benchmark)
            COMMAND="benchmark"
            shift
            ;;
        --monitor)
            COMMAND="monitor"
            shift
            ;;
        --help)
            echo "AI Detection Service"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --command COMMAND    Command to run (server, test, benchmark, monitor) [default: server]"
            echo "  -h, --host HOST         Host to bind to [default: 0.0.0.0]"
            echo "  -p, --port PORT         Port to bind to [default: 8000]"
            echo "      --test              Run test suite"
            echo "      --benchmark         Run performance benchmarks"
            echo "      --monitor           Run performance monitoring with graphs"
            echo "      --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set environment variables for the API server
export AI_DETECTION_HOST="$HOST"
export AI_DETECTION_PORT="$PORT"

# Execute the requested command
case $COMMAND in
    server)
        echo "Starting AI Detection API Server on $HOST:$PORT"
        exec python api_server.py
        ;;
    test)
        echo "Running AI Detection Test Suite"
        exec python test_models.py
        ;;
    benchmark)
        echo "Running AI Detection Performance Benchmarks"
        exec python test_models.py --benchmark
        ;;
    monitor)
        echo "Running AI Detection Performance Monitoring with Graphs"
        exec python monitor_performance.py
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Available commands: server, test, benchmark, monitor"
        exit 1
        ;;
esac
