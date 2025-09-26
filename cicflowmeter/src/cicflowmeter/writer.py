import csv
import json
import logging
from typing import Protocol
from datetime import datetime

import requests


class OutputWriter(Protocol):
    def write(self, data: dict) -> None:
        raise NotImplementedError


class CSVWriter(OutputWriter):
    def __init__(self, output_file) -> None:
        self.file = open(output_file, "w")
        self.line = 0
        self.writer = csv.writer(self.file)

    def write(self, data: dict) -> None:
        if self.line == 0:
            self.writer.writerow(data.keys())

        self.writer.writerow(data.values())
        self.file.flush()
        self.line += 1

    def __del__(self):
        self.file.close()


class HttpWriter(OutputWriter):
    def __init__(self, output_url, model_type="ensemble") -> None:
        self.url = output_url
        self.model_type = model_type
        self.session = requests.Session()
        self.logger = logging.getLogger(__name__)

        # Setup logging to file and console
        self._setup_logging()

    def _setup_logging(self):
        """Setup logging for attack detection results"""
        self.logger.setLevel(logging.INFO)

        # Create formatters
        formatter = logging.Formatter(
            '%(asctime)s - %(levelname)s - %(message)s'
        )

        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_handler.setFormatter(formatter)
        self.logger.addHandler(console_handler)

        # File handler for attack logs
        file_handler = logging.FileHandler('cicflowmeter_attacks.log')
        file_handler.setLevel(logging.WARNING)  # Only log warnings and above (attacks)
        file_handler.setFormatter(logging.Formatter(
            '%(asctime)s - ATTACK DETECTED - %(message)s'
        ))
        self.logger.addHandler(file_handler)

        # File handler for all detections
        all_handler = logging.FileHandler('cicflowmeter_detections.log')
        all_handler.setLevel(logging.INFO)
        all_handler.setFormatter(logging.Formatter(
            '%(asctime)s - %(message)s'
        ))
        self.logger.addHandler(all_handler)

    def _determine_attack(self, prediction: str, confidence: float) -> tuple[bool, str]:
        """Determine if the prediction indicates an attack"""
        attack_types = {
            'ddos': 'DDoS Attack',
            'probe': 'Network Probe/Scan',
            'tls': 'TLS Attack'
        }

        is_attack = prediction in attack_types
        attack_type = attack_types.get(prediction, 'Unknown')

        # Consider high-confidence normal traffic as safe
        if prediction == 'normal' and confidence > 0.8:
            return False, 'Normal Traffic'

        # Any non-normal prediction is considered suspicious
        if prediction != 'normal':
            return True, f'{attack_type} (confidence: {confidence:.3f})'

        # Low confidence normal traffic might be suspicious
        if prediction == 'normal' and confidence < 0.6:
            return True, f'Suspicious Normal Traffic (low confidence: {confidence:.3f})'

        return False, f'Normal Traffic (confidence: {confidence:.3f})'

    def _log_flow_details(self, flow_data: dict, api_response: dict):
        """Log detailed flow information for attacks"""
        prediction = api_response.get('prediction', 'unknown')
        confidence = api_response.get('confidence', 0.0)
        threat_level = api_response.get('threat_level', 'unknown')

        # Extract key flow features for logging
        flow_info = {
            'duration': flow_data.get('flow_duration', 0),
            'bytes_per_sec': flow_data.get('flow_byts_s', 0),
            'packets_per_sec': flow_data.get('flow_pkts_s', 0),
            'fwd_packets': flow_data.get('tot_fwd_pkts', 0),
            'bwd_packets': flow_data.get('tot_bwd_pkts', 0),
        }

        return f"Flow: {flow_info} | Prediction: {prediction} | Confidence: {confidence:.3f} | Threat: {threat_level}"

    def write(self, data):
        try:
            # Convert flow data to the format expected by AI API
            # API expects: {"features": [list of 76 float values], "model_type": "..."}
            # Convert all values to float to ensure JSON serializability
            features_list = [float(value) for value in data.values()]

            api_payload = {"features": features_list, "model_type": self.model_type}

            # Send flow data to AI detection API
            resp = self.session.post(self.url, json=api_payload, timeout=10)
            resp.raise_for_status()  # raise if not 2xx

            # Parse API response
            api_response = resp.json()

            # Extract prediction details
            prediction = api_response.get('prediction', 'unknown')
            confidence = api_response.get('confidence', 0.0)
            threat_level = api_response.get('threat_level', 'unknown')
            recommendation = api_response.get('recommendation', '')

            # Determine if this is an attack
            is_attack, attack_description = self._determine_attack(prediction, confidence)

            # Prepare log message
            flow_summary = self._log_flow_details(data, api_response)

            if is_attack:
                # Log as attack/warning
                self.logger.warning(f"🚨 ATTACK DETECTED: {attack_description} | {flow_summary}")
                print(f"\033[91m🚨 ATTACK DETECTED: {attack_description}\033[0m")
            else:
                # Log as normal/info
                self.logger.info(f"✅ Normal traffic detected | {flow_summary}")
                if threat_level in ['medium', 'high'] or confidence < 0.7:
                    print(f"\033[93m⚠️  Suspicious traffic: {threat_level} threat | {prediction} ({confidence:.3f})\033[0m")
                else:
                    print(f"\033[92m✅ Normal traffic: {prediction} ({confidence:.3f})\033[0m")

        except requests.exceptions.RequestException as e:
            self.logger.error(f"HTTP request failed: {e}")
            print(f"\033[91m❌ API request failed: {e}\033[0m")
        except json.JSONDecodeError as e:
            self.logger.error(f"Failed to parse API response: {e}")
            print(f"\033[91m❌ Invalid API response: {e}\033[0m")
        except Exception as e:
            self.logger.exception(f"HTTPWriter error: {e}")
            print(f"\033[91m❌ Unexpected error: {e}\033[0m")

    def __del__(self):
        self.session.close()


def output_writer_factory(output_mode, output, model_type="ensemble") -> OutputWriter:
    if output_mode == "url":
        return HttpWriter(output, model_type=model_type)
    elif output_mode == "csv":
        return CSVWriter(output)
    else:
        raise RuntimeError("no output_mode provided")
   
