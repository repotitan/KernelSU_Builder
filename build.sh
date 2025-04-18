#!/bin/bash

# Get version from GitHub environment variable
version=${VERSION}
arch=arm64

# Check if version is provided
if [ -z "$version" ]
then
    echo "No version specified. No config or build will be executed. Exiting..."
    exit 1
fi

# Convert the YAML file to JSON
json=$(python -c "import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)" < sources.yaml)

# Check if json is empty
if [ -z "$json" ]
then
    echo "Failed to convert YAML to JSON. Exiting..."
    exit 1
fi

# Parse the JSON file
build_commands=$(echo $json | jq -r --arg version "$version" '.[$version].build[]')

# Check if config_commands and build_commands are empty
if [ -z "$build_commands" ]
then
    echo "Failed to parse JSON. Exiting..."
    exit 1
fi

# Print the commands that will be executed
echo -e "\033[31mBuild.sh will execute following commands corresponding to ${version}:\033[0m"
echo "$build_commands" | while read -r command; do
    echo -e "\033[32m$command\033[0m"
done

config_suffix=$(echo "$json" | jq -r --arg version "$version" '.[$version].config')
if [ $? -ne 0 ] || [ -z "$config_suffix" ]; then
  echo "Error: Failed to extract 'config' from JSON for version '$version'." >&2
  exit 1
fi


dir=$(pwd)
PATCH_DIR="$dir/patches/docker"
DOCKER_DEFCONFIG="$PATCH_DIR/defconfig"
config="$dir/kernel/arch/$arch/configs/$config_suffix"

if [ ! -f "$config" ]; then
    echo "Error: Base kernel config file '$config' not found." >&2
    exit 1
fi

# Enter the kernel directory
cd kernel || exit 1

if [ -d "$PATCH_DIR" ]; then
    if find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' -print -quit | grep -q .; then
        while IFS= read -r -d $'\0' patch_file; do
            if ! git apply --whitespace=fix --verbose "$patch_file"; then
                 echo "Error: Failed to apply patch '$patch_file'." >&2
                 exit 1
            fi
        done < <(find "$PATCH_DIR" -maxdepth 1 -type f -name '*.patch' -print0 | sort -z)
    fi

    if [ -f "$DOCKER_DEFCONFIG" ]; then
        cat "$DOCKER_DEFCONFIG" >> "$config"
    fi
fi

make O=out ARCH=$arch $config_suffix

# Execute the build commands
echo "$build_commands" | while read -r command; do
    eval "$command"
done