#!/bin/sh

# build.sh
#
# Created by Vincent Daubry on 19/01/10.
# Copyright 2010 OCTO. All rights reserved.

PROJDIR=${WORKSPACE}/___PROJECT NAME___
PROJECT_NAME=___XCODE PROJECT NAME___
TARGET_SDK="iphonesimulator4.0"
PROJECT_BUILDDIR="${PROJDIR}/build/Release-iphoneos"
TARGET_TEST_NAME="UnitTests"
BUILD_HISTORY_DIR="/Users/barbu/Desktop"
DEVELOPPER_NAME="iPhone Developer: M VINCENT DAUBRY (J9TS3TJRYX)"
PROVISONNING_PROFILE = "/Users/barbu/Desktop/desire.mobileprovision"
 
# compile project
echo Building Project
cd "${PROJDIR}"
xcodebuild -target "${PROJECT_NAME}" -sdk "${TARGET_SDK}" -configuration Release

#Check if build succeeded
if [ $? != 0 ]
then
  exit 1
fi

/usr/bin/xcrun -sdk iphoneos PackageApplication -v "${PROJECT_BUILDDIR}/${APPLICATION_NAME}.app" -o "${BUILD_HISTORY_DIR}/${APPLICATION_NAME}.ipa" --sign "${DEVELOPPER_NAME}" --embed "${PROVISONNING_PROFILE}"
