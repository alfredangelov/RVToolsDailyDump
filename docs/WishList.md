# RVTools Daily Dump Toolkit — Wishlist and Roadmap

Use this document to capture features, improvements, and decisions for the toolkit. Keep entries concise and actionable. Prefer small issues over large vague ones.

## 1) MVP scope

Goal:

- Reliable (dryRun capable, verbose output (when debugging enabled via config))
- Config-driven RVTools dumps (main configuration, seperate host list)
- Run daily, as a script unattended and email summary of the run
- Securely store credentials for all those servers (PowerShell SecretManagement with -Authentication None -Interaction None)
- A script that goes through the HostList configuration file and stores all credentials (via SecretManagement)
- Easy way to update a server credential if needed (or when the serviceAccount password has been rotated)
- Have easy onboarding / deployment, with scripts that validate all dependencies are installed and any required vaults (from config) are initialized and have secrets

Nice to have:

## RVTools Daily Dump - Feature Wishlist

This document tracks potential improvements and new features for the RVTools Daily Dump toolkit.

## High Priority

- **Configuration Validation**: Add parameter validation to catch common configuration errors early
- **Better Error Recovery**: Implement retry logic for transient network issues
- **Progress Indicators**: Add progress bars for long-running operations

## Medium Priority

- **Multiple Export Formats**: Support additional output formats beyond Excel
- **Custom Report Templates**: Allow customization of exported data structure
- **Scheduling Integration**: Built-in task scheduler integration

## Low Priority

- **Web Dashboard**: Simple web interface for viewing export status and results
- **Database Storage**: Option to store export data in SQL database
- **Advanced Filtering**: Export only specific VM/host data based on criteria

## Completed Features ✅

- ✅ **Secure Credential Management**: PowerShell SecretManagement integration (v1.1.0)
- ✅ **Email Integration**: Automated email reports with run summaries (v1.1.0)
- ✅ **Configuration Templates**: Template-based setup for easy deployment (v1.1.0)
- ✅ **Chunked Export Mode**: Handle large environments with memory-efficient exports (v1.3.0)
- ✅ **Microsoft Graph Email**: Modern OAuth2 email authentication (v1.4.0)
- ✅ **Complete Module Architecture**: Professional PowerShell module with advanced features (v2.0.1)
