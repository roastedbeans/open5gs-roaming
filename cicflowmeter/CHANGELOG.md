# Changelog

## [0.4.1] - 2025-09-27
### Added
- **AI Model Selection**: Added `--model` parameter to choose specific AI models (cnn, mlp, rnn, lstm, gru, autoencoder, ensemble)
- **Real-time Detection**: Enhanced `--url` mode for streaming flows to AI detection API
- **Attack Logging**: Comprehensive logging with `cicflowmeter_attacks.log` and `cicflowmeter_detections.log`
- **Feature Optimization**: Reduced to 76 features compatible with AI models (removed IP addresses, ports, timestamps, protocol)
- **API Integration**: Direct HTTP streaming with JSON payload formatting

### Changed
- Python 3.10+ compatibility: Replaced `match/case` with `if/elif/else` for broader Python support
- Enhanced error handling and logging for production use
- Updated repository references for Open5GS roaming integration

## [0.4.0] - 2025-06-08
### Changed
- Major refactor: Now uses a custom FlowSession and the prn callback of AsyncSniffer for all flow processing, instead of relying on Scapy's DefaultSession/session system.
- All flow logic, feature extraction, and output are now fully managed by the project code, not by Scapy internals.
- The process method always returns None, preventing unwanted packet printing by Scapy.
- Logging is robust: only shows debug output if -v is set.
- All flows are always flushed at the end, even for small pcaps.

### Notes
- This project is a CICFlowMeter-like tool (see https://www.unb.ca/cic/research/applications.html#CICFlowMeter), not Cisco NetFlow. It extracts custom flow features as in the original Java CICFlowMeter.
- The refactor does not change the set of features/fields extracted, only how packets are routed to your logic.
