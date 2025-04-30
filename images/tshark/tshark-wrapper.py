#!/usr/bin/env python3

import yaml
import sys
import os
import subprocess
import logging
import time
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('tshark-wrapper')

def setup_log_file(log_config):
    """Setup file logging based on config"""
    if not log_config:
        return
    
    log_file = log_config.get('file', '/var/log/tshark.log')
    log_level = log_config.get('level', 'info').upper()
    
    # Create file handler
    file_handler = logging.FileHandler(log_file)
    file_handler.setLevel(getattr(logging, log_level, logging.INFO))
    file_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
    
    # Add handler to logger
    logger.addHandler(file_handler)
    
    logger.info(f"Logging to {log_file} with level {log_level}")

def build_tshark_command(config):
    """Build tshark command from YAML config"""
    cmd = ['tshark']
    
    # Capture interface
    if 'capture' in config and 'interface' in config['capture']:
        cmd.extend(['-i', config['capture']['interface']])
    
    # Output file
    if 'capture' in config and 'output' in config['capture']:
        cmd.extend(['-w', config['capture']['output']])
    
    # File rotation settings
    if 'capture' in config and 'rotate' in config['capture'] and config['capture']['rotate']:
        # If rotation is enabled, use ring buffer
        if 'max_files' in config['capture']:
            cmd.extend(['-b', f'files:{config["capture"]["max_files"]}'])
        if 'rotate_interval' in config['capture']:
            cmd.extend(['-b', f'duration:{config["capture"]["rotate_interval"]}'])
        if 'max_size' in config['capture']:
            # Convert MB to KB for tshark
            filesize_kb = int(config['capture']['max_size']) * 1024
            cmd.extend(['-b', f'filesize:{filesize_kb}'])
    
    # Capture filters - combined with 'or'
    if 'filters' in config and config['filters']:
        capture_filter = ' or '.join([f'({f})' for f in config['filters']])
        cmd.extend(['-f', f'"{capture_filter}"'])
    
    # Display filters
    if 'display_filters' in config and config['display_filters']:
        display_filter = ' or '.join([f'({f})' for f in config['display_filters']])
        cmd.extend(['-Y', f'"{display_filter}"'])
    
    # Performance settings
    if 'performance' in config:
        perf = config['performance']
        if 'buffer_size' in perf:
            # Convert MB to KB
            buffer_size_kb = int(perf['buffer_size']) * 1024
            cmd.extend(['-B', str(buffer_size_kb)])
        
        if 'max_packets' in perf:
            cmd.extend(['-c', str(perf['max_packets'])])
        
        if 'promiscuous_mode' in perf:
            if perf['promiscuous_mode']:
                cmd.append('-p')
    
    return cmd

def main():
    if len(sys.argv) < 2:
        logger.error("Config file path required as argument")
        sys.exit(1)
    
    config_file = sys.argv[1]
    
    try:
        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)
    except Exception as e:
        logger.error(f"Failed to load config file: {e}")
        sys.exit(1)
    
    # Setup logging based on config
    if 'logging' in config:
        setup_log_file(config['logging'])
    
    # Build and execute tshark command
    cmd = build_tshark_command(config)
    
    logger.info(f"Starting tshark with command: {' '.join(cmd)}")
    
    try:
        # Execute tshark
        process = subprocess.Popen(cmd)
        
        # Wait for process to complete
        process.wait()
        
        # Log exit status
        exit_code = process.returncode
        if exit_code == 0:
            logger.info("tshark completed successfully")
        else:
            logger.error(f"tshark exited with code {exit_code}")
    
    except Exception as e:
        logger.error(f"Failed to execute tshark: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()