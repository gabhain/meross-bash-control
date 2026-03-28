# Meross Bash Control Scripts

A collection of Bash scripts to easily toggle and query the status of Meross Smart Lamps from the command line. Due to the Meross protocol requiring complex cryptographically signed hashes (`md5` timestamps with device keys), providing simple direct `curl` commands is difficult. 

This repository provides a reliable cloud-assisted wrapper script to tackle this.

## Cloud-assisted Auto Wrapper

This is the most reliable approach. It uses your Meross Cloud account to securely find your devices, retrieve their hidden internal cryptographic keys, and send commands using the official `meross-iot` Python library (running quietly in the background via a virtual environment).

### Setup

1. Open `meross_cloud_wrapper.sh` and fill in your actual Meross App Email and Password at the very top of the script.
2. Make sure the script is executable:
   ```bash
   chmod +x meross_cloud_wrapper.sh
   ```

### Usage
Run the script using the exact name of your lamp as it appears in the Meross App.

```bash
./meross_cloud_wrapper.sh "Bedroom Lamp" on
./meross_cloud_wrapper.sh "Bedroom Lamp" off
./meross_cloud_wrapper.sh "Bedroom Lamp" status
```
*Note: The script will automatically download and cache `meross-iot` in a hidden `.meross_venv` folder on its very first run.*

