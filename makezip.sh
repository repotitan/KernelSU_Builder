#!/bin/bash

zip_ksu=${ZIP_KSU}

COPIED_FILES=""
for file in outw/*; do
    cp "$file" AnyKernel3
    COPIED_FILES="${COPIED_FILES} $(basename $file)"
done

# Enter AnyKernel3 directory
cd AnyKernel3

# Zip the kernel
zip -r9 "${zip_ksu}" *

# Move the ZIP to to Github workspace
mv "${zip_ksu}" "${GITHUB_WORKSPACE}/"
