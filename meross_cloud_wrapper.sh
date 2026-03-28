#!/bin/bash

# Meross Cloud & Local Automated Control Wrapper
# Usage: ./meross_cloud_wrapper.sh <lamp_name> <on|off|status> OR ./meross_cloud_wrapper.sh list

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# ---------------------------------------------------------
# Set your Meross account credentials here:
export MEROSS_EMAIL="[EMAIL_ADDRESS]"
export MEROSS_PASSWORD="[PASSWORD]"
# ---------------------------------------------------------

if [ "$1" == "list" ]; then
    LAMP_NAME="all"
    ACTION="list"
else
    LAMP_NAME=$1
    ACTION=$2

    if [ -z "$LAMP_NAME" ] || [ -z "$ACTION" ]; then
        echo "Usage: $0 <lamp_name> <on|off|status> OR $0 list"
        exit 1
    fi

    if [[ "$ACTION" != "on" && "$ACTION" != "off" && "$ACTION" != "status" ]]; then
        echo "Action must be 'on', 'off', 'status', or run '$0 list'."
        exit 1
    fi
fi


# We use a virtual environment so we don't pollute the global python space.
VENV_DIR="$SCRIPT_DIR/.meross_venv"

if [ ! -d "$VENV_DIR" ]; then
    echo "Setting up Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    echo "Installing meross-iot library..."
    source "$VENV_DIR/bin/activate"
    pip install -q meross-iot
    deactivate
fi

source "$VENV_DIR/bin/activate"

# We pass the instruction directly to python. This handles the complex encryption, keys, and Cloud/Local routing automatically.
cat << 'EOF' > "$SCRIPT_DIR/toggle_lamp.py"
import asyncio
import os
import sys
from meross_iot.http_api import MerossHttpClient
from meross_iot.manager import MerossManager

EMAIL = os.environ.get('MEROSS_EMAIL')
PASSWORD = os.environ.get('MEROSS_PASSWORD')
LAMP_NAME = sys.argv[1]
ACTION = sys.argv[2]

async def main():
    if not EMAIL or not PASSWORD:
        print("Error: Meross Email and Password environment variables not set.")
        sys.exit(1)

    # 1. Setup the HTTP client
    http_api_client = await MerossHttpClient.async_from_user_password(email=EMAIL, password=PASSWORD)

    # 2. Setup and start the device manager
    manager = MerossManager(http_client=http_api_client)
    await manager.async_init()

    # 3. Discover devices
    # print("Discovering devices...")
    await manager.async_device_discovery()

    # 4. Handle "list" action or find the specific device by name
    if ACTION == "list":
        devices = manager.find_devices()
        print("\nDiscovered Devices on your Meross account:")
        if not devices:
            print("  No devices found.")
        for d in devices:
            kind = "Lamp/Switch" if d.supports_toggle() or d.supports_toggle_x() or d.supports_light_control() else "Other Device"
            print(f"  - {d.name} ({kind})")
        print("")
    else:
        devices = manager.find_devices(device_name=LAMP_NAME)

        if not devices:
            print(f"Error: Lamp '{LAMP_NAME}' not found. Please ensure the exact name matches your Meross app.")
        else:
            dev = devices[0]
            # Check if the device is a togglable lamp
            if dev.supports_light_control() or dev.supports_toggle() or dev.supports_toggle_x():
                if ACTION == "status":
                    print(f"Querying status for '{dev.name}'...")
                    await dev.async_update()
                    is_on = dev.is_on()
                    print(f"Status: {'ON' if is_on else 'OFF'}")
                else:
                    print(f"Turning {ACTION} '{dev.name}'...")
                    if ACTION == "on":
                        await dev.async_turn_on(channel=0)
                    elif ACTION == "off":
                        await dev.async_turn_off(channel=0)
                    print("Done.")
            else:
                print(f"Error: The device '{LAMP_NAME}' does not support toggling.")

    # 5. Cleanup
    manager.close()
    await http_api_client.async_logout()

if __name__ == '__main__':
    if os.name == 'nt':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(main())
EOF

# Execute the python toggle script
python "$SCRIPT_DIR/toggle_lamp.py" "$LAMP_NAME" "$ACTION"

deactivate
