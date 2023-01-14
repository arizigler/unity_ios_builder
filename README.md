# Overview

This script is used to build & install a Unity app on iOS from the command line.
The Xcode project will be created under Builds/iOS.

## Usage
./build_unity_app.sh [-i] -d dev_team_id project_path

## Options

- `-i`: (optional) install the app to the device after building.
- `-d dev_team_id` : (required) the Development Team ID to be used for signing the app.
- `project_path` : (required) the path to the Unity project.

## Examples

./build_unity_app.sh -i -d N28K52843 /path/to/UnityProject

This command will build the Unity app located at `/path/to/UnityProject` for iOS, set the provisioning style to Automatic, set the Development Team ID to N28K52843 and install the app to the device after building.

## Requirements
- Unity 2021.3.15f1 or higher.
- A valid Development Team ID.

## Note
- The script will not proceed if the Development Team ID is not provided
- The script will not proceed if the Unity executable is not found on the system
- The script will not proceed if the Unity project path is not found on the system

## Troubleshooting
- If you encounter any issues with the script, check the Unity console logs and error messages for more information.
- If the issue persists, check the Unity documentation or forums for any known issues or solutions related to the script.

