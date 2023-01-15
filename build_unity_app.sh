#!/bin/bash

if [[ $# -eq 0 || "$1" == "--help" ]]; then
    echo "Usage: ./build_unity_app.sh project_path"
    exit 1
fi

install_to_device=false
dev_team=""
while getopts "i:d:" opt; do
  case $opt in
    i)
      install_to_device=true
      ;;
    d)
      dev_team=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [ -z "$dev_team" ]; then
  echo "-devteam option is required"
  exit 1
else
  echo "dev_team variable is set to $dev_team"
fi

project_path=$(realpath "$1")

echo "Generating Unity project at path $project_path"

# Check if the Editor folder exists, and create it if it doesn't
if [ ! -d "$project_path/Assets/Editor" ]; then
  mkdir "$project_path/Assets/Editor"
  shall_delete=1
fi

if [ ! -d "$project_path/Builds/iOS" ]; then
  build_options="None"
else
  build_options="AcceptExternalModificationsToPlayer"
fi

# Create the cs file with the build script
build_file="using UnityEngine;
using UnityEditor;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

public static class AutoBuilder {
    static string[] GetScenePaths()
    {
        string[] scenes = new string[EditorBuildSettings.scenes.Length];

        for(int i = 0; i < scenes.Length; i++)
        {
            scenes[i] = EditorBuildSettings.scenes[i].path;
        }

        return scenes;
    }
    [MenuItem(\"Custom/build\")]
    static void PerformiOSBuild ()
    {
        EditorSceneManager.OpenScene(EditorBuildSettings.scenes[0].path);
        EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.iOS, BuildTarget.iOS);
        BuildPipeline.BuildPlayer(GetScenePaths(), \"Builds/iOS\",BuildTarget.iOS,BuildOptions.$build_options);
    }
}"

target_build_file="$project_path/Assets/Editor/BuildScript.cs"
if [ ! -f "$target_build_file" ] || ! echo "$build_file" | shasum -a 256 | grep $(shasum -a 256 "$target_build_file" | cut -f 1 -d " "); then
  echo "Updating build file at $target_build_file"
  echo "$build_file" > "$target_build_file"
fi

# Set the path to the Unity executable
UNITY_EXECUTABLE="/Applications/Unity/Hub/Editor/2021.3.15f1/Unity.app/Contents/MacOS/Unity"

# Set the path to the Unity project
UNITY_PROJECT_PATH=$project_path

# Set the build target
BUILD_TARGET="iOS"

if command -v $UNITY_EXECUTABLE &>/dev/null; then
    # Build the project
    "$UNITY_EXECUTABLE" \
      -batchmode \
      -quit \
      -nographics \
      -projectPath "$UNITY_PROJECT_PATH" \
      -buildTarget "$BUILD_TARGET" \
      -executeMethod AutoBuilder.PerformiOSBuild \
      -logFile -
else
    echo "Unity 2021.3.15f is required. Can't generate framework"
    exit 1
fi

# Function to copy the content of one file to another if their hashes differ
function copy_if_differ() {
  original_file_path="$1"
  new_file_path="$2"

  # Get the hash of the original file
  original_file_hash=$(shasum -a 256 "$original_file_path" | cut -f 1 -d " ")

  # Get the hash of the new file
  new_file_hash=$(shasum -a 256 "$new_file_path" | cut -f 1 -d " ")

  # Compare the hashes
  if [ "$original_file_hash" != "$new_file_hash" ]; then
    echo "modifying $original_file_path"
    # Copy the content of the original file to the new file
    cp "$new_file_path" "$original_file_path"
  fi
}

xcodeProject="$project_path/Builds/iOS/Unity-iPhone.xcodeproj"

awkAutomatic="awk '{gsub(/ProvisioningStyle = Manual/, \"ProvisioningStyle = Automatic\"); print}' \"$xcodeProject/project.pbxproj\" > \"$project_path/Builds/iOS/project.pbxproj_tmp\""
/bin/bash -c "$awkAutomatic"
copy_if_differ "$xcodeProject/project.pbxproj" "$project_path/Builds/iOS/project.pbxproj_tmp"

awkAutomatic="awk '{gsub(/DEVELOPMENT_TEAM = \"\"/, \"DEVELOPMENT_TEAM = $(printf '%q' '"$dev_team"')\"); print}' \"$xcodeProject/project.pbxproj\" > \"$project_path/Builds/iOS/project.pbxproj_tmp\""
/bin/bash -c "$awkAutomatic"
copy_if_differ "$xcodeProject/project.pbxproj" "$project_path/Builds/iOS/project.pbxproj_tmp"

awkAutomatic="awk '{gsub(/CODE_SIGN_IDENTITY = \"\"/, \"CODE_SIGN_IDENTITY = $(printf '%q' '"Apple Development"')\"); print}' \"$xcodeProject/project.pbxproj\" > \"$project_path/Builds/iOS/project.pbxproj_tmp\""
/bin/bash -c "$awkAutomatic"
copy_if_differ "$xcodeProject/project.pbxproj" "$project_path/Builds/iOS/project.pbxproj_tmp"

xcodeBuild="xcodebuild -project \"$xcodeProject\" -scheme Unity-iPhone -derivedDataPath \"$project_path/Builds/iOS/DerivedData\" -IDEBuildOperationMaxNumberOfConcurrentCompileTasks=`sysctl -n hw.ncpu`"
/bin/bash -c "$xcodeBuild"

if $install_to_device; then
    ipa=$(find "$project_path/Builds/iOS" -path "*/Products/*Release*/*.app")
    echo "Installing $ipa"
    if command -v ideviceinstaller &>/dev/null; then
        ideviceinstaller -i "$ipa"
    else
        echo "ideviceinstaller is required."
        echo "You can install it from brew:"
        echo "brew install libimobiledevice"
        echo "brew install ideviceinstaller"
        exit 1
    fi
fi

# Check the exit code of the Unity process
if [ $? -eq 0 ]
then
  echo "Build successful!"
else
  echo "Build failed!"
  exit 1
fi
