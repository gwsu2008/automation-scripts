#!/bin/bash +x
info() {
   echo -e "\033[34m[Info]\033[0m $1"
}

error() {
   echo -e "\033[31m[Error] $1\033[0m"
}

success() {
   echo -e "\033[32m[Success]\033[0m $1"
}

warn() {
   echo -e "\033[33m[Warn]\033[0m $1"
}
export LC_ALL=en_US.UTF-8
export DEVICE_NAME='iPhone 11'
export PLATFORM_VERSION=$(xcodebuild -showsdks | grep -Eo "iphonesimulator([0-9]{1,}\.)+[0-9]{1,}" | tr -d 'A-z')
export SIM_RUN_TIME="com.apple.CoreSimulator.SimRuntime.iOS-$(echo $PLATFORM_VERSION | tr '.' '-')"
export SIM_OS=$(xcrun simctl list runtimes | grep "iOS ${PLATFORM_VERSION}" | awk '{ gsub("\\(", "") ; print $3 }')

update_maven_pom() {
    if [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-pre'` -eq 1 ]; then
        info "Maven artifact id [ipa-pre]"
        ARTIFACT_ID='ipa-pre'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-demo'` -eq 1 ]; then
        if [ "${IPA_TYPE}" == 'demo-lobby' ]; then
            info "Maven artifact id [ipa-demo-lobby]"
            ARTIFACT_ID='ipa-demo-lobby'
        else
            info "Maven artifact id [ipa-demo]"
            ARTIFACT_ID='ipa-demo'
        fi
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-prod'` -eq 1 ]; then
        info "Maven artifact id [ipa-prod]"
        ARTIFACT_ID='ipa-prod'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-study'` -eq 1 ]; then
        info "Maven artifact id [ipa-study]"
        ARTIFACT_ID='ipa-study'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-od1'` -eq 1 ]; then
        info "Maven artifact id [ipa-od1]"
        ARTIFACT_ID='ipa-od1'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-od2'` -eq 1 ]; then
        info "Maven artifact id [ipa-od2]"
        ARTIFACT_ID='ipa-od2'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-od3'` -eq 1 ]; then
        info "Maven artifact id [ipa-od3]"
        ARTIFACT_ID='ipa-od3'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-od4'` -eq 1 ]; then
        info "Maven artifact id [ipa-od4]"
        ARTIFACT_ID='ipa-od4'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-od5'` -eq 1 ]; then
        info "Maven artifact id [ipa-od5]"
        ARTIFACT_ID='ipa-od5'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-od6'` -eq 1 ]; then
        info "Maven artifact id [ipa-od6]"
        ARTIFACT_ID='ipa-od6'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-staging'` -eq 1 ]; then
        info "Maven artifact id [ipa-staging]"
        ARTIFACT_ID='ipa-staging'
    else
        # default to api-int artifact
        info "Maven artifact id [ipa-int] because APIGW_ENDPOINT is not defined"
        ARTIFACT_ID='ipa-int'
    fi
    info "Update artifact id to ${ARTIFACT_ID} in ${POM_FILE}"
    sed -i.bak -e "s/ipa-int/${ARTIFACT_ID}/g" ${POM_FILE}
    if [ -f ${WORKSPACE}/devops/ipa/pom-ipa-enterprise.xml ]; then
        info "Update artifact id to ${ARTIFACT_ID} in ${WORKSPACE}/devops/ipa/pom-ipa-enterprise.xml"
        sed -i.bak -e "s/ipa-int/${ARTIFACT_ID}/g" ${WORKSPACE}/devops/ipa/pom-ipa-enterprise.xml
        sed -i.bak -e "s/@POM_VERSION@/${POM_VERSION}/g" ${WORKSPACE}/devops/ipa/pom-ipa-enterprise.xml
    fi
}

####################################################################################################
#
#   Main
#
####################################################################################################
usage() {
	echo "Usage: $0 --ipa-type simulator | enterprise | appstore | demo-lobby"
}
while test $# -gt 0
do
	if [ "$1" == "--api" ]; then
		shift
		APIGW_ENDPOINT=$1
	elif [ "$1" == "--ipa-type" ]; then
		shift
		IPA_TYPE=$1
    elif [ "$1" == "--unit-test" ]; then
		RUN_UNIT_TEST='true'
    elif [ "$1" == "--resign" ]; then
		RESIGN_IPA='true'
	elif [ "$1" == "--help" ]; then
		usage
		exit 0
	elif [ "$1" == "-h" ]; then
		usage
		exit 0
    fi
    shift
done

if [ -z "${RESIGN_IPA}" ]; then
    # set default resign to false to preserve original behavior
    RESIGN_IPA='false'
fi

if [ -z "${IPA_TYPE}" ]; then
    error "IPA_TYPE is not defined in environment variable or command line parameter"
    info "Usage: $0 simulator | enterprise | appstore | demo-lobby"
    exit 1
fi

BUNDLE_ID='com.apps.mobile-app'
PROFILE_NAMEBUNDLE_ID='MobileApp'
PROFILE_ID='951097f2-0e44-4e50-9315-0a5814a6929e'
TEAM_ID='00000000000'

mkdir -p ${WORKSPACE}/Release
mkdir -p ${WORKSPACE}/Debug
mkdir -p ${WORKSPACE}/target
mkdir -p $WORKSPACE/devops/ipa/target

MVN=$(which mvn 2>/dev/null)
if [ $? -ne 0 ]; then
    if [ -f /usr/local/bin/mvn ]; then
        MVN='/usr/local/bin/mvn'
    elif [ -f $MAVEN_HOME/bin/mvn ]; then
        MVN="$MAVEN_HOME/bin/mvn"
    else
        error "Maven installation not found."
        exit 1
    fi
fi

if [ -d $WORKSPACE/mobile-app ]; then
    pushd $WORKSPACE/mobile-app > /dev/null
fi

if [ "${IPA_TYPE}"x != "demo-lobby" ]; then
    if [ -f /usr/local/bin/swiftlint ]; then
        if [ -f $WORKSPACE/mobile-app/.swiftlint.yml ]; then
            info "Found $WORKSPACE/mobile-app/.swiftlint.yml"
        elif [ -f $WORKSPACE/.swiftlint.yml ]; then
            info "Found $WORKSPACE/.swiftlint.yml"
        else
            info "Using .swiftlint.yml from CD repo"
            cp -f ${WORKSPACE}/devops/ipa/.swiftlint.yml ${WORKSPACE}/.swiftlint.yml
            if [ -d $WORKSPACE/mobile-app/ ]; then
                cp -f ${WORKSPACE}/devops/ipa/.swiftlint.yml $WORKSPACE/mobile-app/.swiftlint.yml
            fi
        fi
        info "Run Swiftlint with checkstyle"
        /usr/local/bin/swiftlint lint --no-cache --reporter checkstyle > $WORKSPACE/devops/ipa/target/lint-results.xml
    fi
fi

info "Get current git commit sha1"
CURRENT_GIT_COMMIT=$(git log -n 1 --pretty=format:"%H")
if [ -z "${CURRENT_GIT_COMMIT}" ]; then
    warn "Current workspace $WORKSPACE does not have git repo"
fi

if [ -d $WORKSPACE/mobile-app ]; then
    mv -f * $WORKSPACE/
    mv -f .git $WORKSPACE/
	mv -f .gitignore $WORKSPACE/
	mv -f .gitmodules $WORKSPACE/
    popd > /dev/null
fi

POM_FILE=${WORKSPACE}/devops/ipa/pom-ipa.xml
POM_VERSION=$(${MVN} help:evaluate -f ${POM_FILE} -Dexpression=project.version -q -DforceStdout)
if [ $? -ne 0 ]; then
    error "Failed to get version from pom file"
    exit 1
fi
####### Update Maven pom for artifact deployment #############
update_maven_pom

IPA_TYPE=$(echo ${IPA_TYPE} | tr 'A-Z' 'a-z')
info "IPA build type [${IPA_TYPE}]"
BRANCH_DESC=$(echo ${BRANCH_NAME} | awk -F/ '{print $NF}')
info "POM_VERSION ${POM_VERSION}"
if [ `echo ${POM_VERSION} | grep -c 'SNAPSHOT'` -eq 0 ]; then
    info "POM vesion is release. Get APP_BUILD_NUMBER from POM version"
    APP_BUILD_NUMBER=$(echo ${POM_VERSION} | awk -F- '{print $1}' | awk -F"." '{print $NF}')
    RELEASE_BUILD='true'
    APP_VERSION=$(echo ${POM_VERSION} | awk -F- '{print $1}' | awk -F"." '{print $1"."$2"."$3}')
    BUILD_VERSION="${APP_VERSION}.${APP_BUILD_NUMBER}"
else
	APP_VERSION=$(echo ${POM_VERSION} | awk -F- '{print $1}' | awk -F"." '{print $1"."$2"."$3}')
	if [ -n "${APP_BUILD_NUMBER}" ]; then
        info "Using predefined APP_BUILD_NUMBER"
        BUILD_VERSION="${APP_VERSION}.${APP_BUILD_NUMBER}"
	else
        info "Using jenkins BUILD_NUBMER for APP_BUILD_NUMBER"
        BUILD_VERSION="${APP_VERSION}.${BUILD_NUMBER}"
	fi
fi

if [ "${FEATURE_BUILD}"x == 'true'x ]; then
    echo "BUILD DESCRIPTION: IPA: ${IPA_BRANCH}<br>ICK: ${ICK_BRANCH}<br>IUK: ${IUK_BRANCH}<br>IOC: ${ICO_BRANCH}<br>IFK: ${IFK_BRANCH}"
    
else
    echo "BUILD DESCRIPTION: IPA-${BUILD_VERSION}-${IPA_TYPE}<br>$(echo ${APIGW_ENDPOINT} | awk -F"." '{print $1}')<br>${BRANCH_DESC}"
fi

if [ -z "${BRANCH_NAME}" ]; then
    if [ -n "${IPA_BRANCH}" ]; then
        info "Using IPA_BRANCh as BRANCH_NAME"
        export BRANCH_NAME=${IPA_BRANCH}
    else
        info "BRANCH_NAME is not defined. Set to default master"
        export BRANCH_NAME=master
    fi
fi

if [ "${IPA_TYPE}"x == "simulator"x ]; then
    SDK=$(xcodebuild -showsdks | grep -Eo "iphonesimulator([0-9]{1,}\.)+[0-9]{1,}" | tr -d 'A-z')
else
    SDK=$(xcodebuild -showsdks | grep -Eo "iphoneos([0-9]{1,}\.)+[0-9]{1,}" | tr -d 'A-z')
fi

info "BUILD_MODULES: ${BUILD_MODULES}"
info "Using SDK ${SDK}"
XCODE_PATH=$(xcode-select -print-path)
info "Xcode path ${XCODE_PATH}"
CARTHAGE_VERSION=$(/usr/local/bin/carthage version)
info "carthage version ${CARTHAGE_VERSION}"
info "Xcodebuild version"
xcodebuild -version



pushd $WORKSPACE/mobile-app > /dev/null
for INFO_PLIST in `find . -type f -name '*Info.plist'`; do
    info "Check ${INFO_PLIST} for CFBundleVersion string"
    /usr/libexec/PlistBuddy -c "Print CFBundleVersion" ${INFO_PLIST} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        info "Update CFBundleVersion and CFBundleShortVersionString in ${INFO_PLIST}"
        # CFBundleShortVersionString includes the build number
        info "Set CFBundleShortVersionString ${APP_VERSION} [new-marketing-version]"
        /usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString ${APP_VERSION}" ${INFO_PLIST}
        # CFBundleVersion only version no build number
        info "Set CFBundleVersion ${BUILD_VERSION} [new-version]"
        /usr/libexec/PlistBuddy -c "Set CFBundleVersion ${BUILD_VERSION}" ${INFO_PLIST}
        echo
    else
        info "No Update of $INFO_PLIST needed"
    fi
done
popd > /dev/null
info "RESIGN_IPA: ${RESIGN_IPA}"
TS=$(date +"%-m/%-d/%Y, %-I:%M:%S %p")
info "Generate maven.info file"
echo "version=${BUILD_VERSION}" > ${WORKSPACE}/Release/maven.info
echo "commit_hash=${CURRENT_GIT_COMMIT}" >> ${WORKSPACE}/Release/maven.info
echo "branch_name=${BRANCH_NAME}" >> ${WORKSPACE}/Release/maven.info
echo 'build_time="'${TS}'"' >> ${WORKSPACE}/Release/maven.info
cp -f ${WORKSPACE}/Release/maven.info ${WORKSPACE}/maven.info
info "Update pom with build version"
sed -i.bak -e "s/BUILD_VERSION/${BUILD_VERSION}/g" ${POM_FILE}


if [ -f $WORKSPACE/git-get-changelog.py ]; then
    # Remove $WORKSPACE/previous_build in case wipe workspace did not run
    rm -fr $WORKSPACE/previous_build

    # The delimiter use to search s3 repository
    DELIMTER='.zip'
    info "Generate git change log"
    info "Git-URL=$GIT_URL"
    info "To-Commit=${CURRENT_GIT_COMMIT}"
    info "Job-URL=${JOB_URL}"
    if [ -n "${TO_COMMIT}" ]; then
        if [ "${TO_COMMIT}" != "${CURRENT_GIT_COMMIT}" ]; then
            error "To commit: $TO_COMMIT"
            error "Current commit: ${CURRENT_GIT_COMMIT}"
            error "They are not the same"
            exit 1
        fi
    fi
    if [ -n "${CHANGELOG_FROM_COMMIT}" ]; then
        info "FROM_COMMIT: ${CHANGELOG_FROM_COMMIT} defined"
        echo "/usr/local/bin/python3 $WORKSPACE/git-get-changelog.py --from-commit ${CHANGELOG_FROM_COMMIT} --to-commit ${CURRENT_GIT_COMMIT} --git-url ${GIT_URL} --job-url ${JOB_URL} --pom ${POM_FILE} --delimiter ${DELIMTER} --version IPA-${BUILD_VERSION}"
        /usr/local/bin/python3 $WORKSPACE/git-get-changelog.py --from-commit ${CHANGELOG_FROM_COMMIT} --to-commit ${CURRENT_GIT_COMMIT} --git-url ${GIT_URL} --job-url ${JOB_URL} --pom ${POM_FILE} --delimiter ${DELIMTER} --version IPA-${BUILD_VERSION}
    else
        echo "/usr/local/bin/python3 $WORKSPACE/git-get-changelog.py --to-commit ${CURRENT_GIT_COMMIT} --git-url ${GIT_URL} --job-url ${JOB_URL} --pom ${POM_FILE} --delimiter ${DELIMTER} --version IPA-${BUILD_VERSION}"
        /usr/local/bin/python3 $WORKSPACE/git-get-changelog.py --to-commit ${CURRENT_GIT_COMMIT} --git-url ${GIT_URL} --job-url ${JOB_URL} --pom ${POM_FILE} --delimiter ${DELIMTER} --version IPA-${BUILD_VERSION}
    fi
fi

if [ -d $WORKSPACE/previous_build ]; then
    info "Copy for previous build changelog"
    cp -f $WORKSPACE/previous_build/*-changelog.html $WORKSPACE/changelog.html
    info "Update build version and time stamp for previous changelog.html"
    VERSION_INFO="<big><b>IPA-${BUILD_VERSION}</b></big> (${TS})<br>"
    sed -i.bak -e "/<big><b>/s|<big><b>.*|${VERSION_INFO}|g" $WORKSPACE/changelog.html
    rm -f $WORKSPACE/changelog.html.bak
fi

if [ -f $WORKSPACE/changelog.html ]; then
    cp -f $WORKSPACE/changelog.html ${WORKSPACE}/Release/ipa-changelog.html
fi

if [ ! -f $WORKSPACE/changelog-aggregate.html ]; then
    info "Creating $WORKSPACE/changelog-aggregate.html for dependencies"
    cat $WORKSPACE/changelog.html >> $WORKSPACE/changelog-aggregate.html
    for CHANGELOG_FILE in `find $WORKSPACE/devops/ipa/target/ -type f -name "*changelog.html"`; do
        cat ${CHANGELOG_FILE} >> $WORKSPACE/changelog-aggregate.html
    done
    cp -f $WORKSPACE/changelog-aggregate.html ${WORKSPACE}/Release/changelog-aggregate.html
    if [ ! -f ${WORKSPACE}/Release/ipa-changelog.html ]; then
        cp -f $WORKSPACE/changelog.html {WORKSPACE}/Release/ipa-changelog.html
    fi
fi

if [ -f $WORKSPACE/Podfile ]; then
    info "Create jenkins.build.txt to skip UIKit pod"
    touch jenkins.build.txt
    info "CocoaPods version: $(pod --version)"
    info "Running pod install"
    pod install
    STATUS=$?
    if [ $STATUS -ne 0 ]; then
	    info "Try pod repo update"
        pod repo update
        STATUS=$?
        if [ $STATUS -ne 0 ]; then
            error "Pod installation failed"
            exit 1
        fi
    fi
else
    warn "$WORKSPACE/Podfile not found"
fi

if [ "${BUILD_MODULES}"x  != 'true'x ]; then
    info "Prepare framework for IPA build"
    mkdir -p ${WORKSPACE}/mobile-app/MobileApp/PomFrameworks/
    ICK_FRAMWORK_ZIP=$(ls ${WORKSPACE}/devops/ipa/target/*framework.zip 2>/dev/null)
    if [ -z "${ICK_FRAMWORK_ZIP}" ]; then
        error "CoreKit framework not found in ${WORKSPACE}/devops/ipa/target/"
        exit 1
    fi
    unzip -oqd ${WORKSPACE}/devops/ipa/target/ ${ICK_FRAMWORK_ZIP}
    if [ $? -ne 0 ]; then
        error "Failed to extract ${ICK_FRAMWORK_ZIP}"
        exit 1
    fi
fi

if [ -n "${APIGW_ENDPOINT}" ]; then
    info "APIGW_ENDPOINT: ${APIGW_ENDPOINT} setting xcode build scheme"
    if [ `echo ${APIGW_ENDPOINT} | grep -c 'api-int'` -eq 1  ]; then
         if [ "${IPA_TYPE}"x == "appstore"x ]; then
            XCONFIG='AppStore_Int'
            EXPORTOPTION_PLIST=$WORKSPACE/AppStore_exportOptions.plist
        else
            XCONFIG='Int'
            EXPORTOPTION_PLIST=$WORKSPACE/mobile-app/Enterprise_exportOptions.plist
        fi
    elif [ `echo ${APIGW_ENDPOINT} | grep -c 'api-prod'` -eq 1  ]; then
        info ">>>>> PRODUCTION IPA <<<<< "
        if [ "${IPA_TYPE}"x == "appstore"x ]; then
            XCONFIG='AppStore_Prod'
            EXPORTOPTION_PLIST=$WORKSPACE/AppStore_exportOptions.plist
        else
            XCONFIG='Enterprise_Prod'
            EXPORTOPTION_PLIST=$WORKSPACE/mobile-app/Enterprise_exportOptions.plist
        fi
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-pre'` -eq 1  ]; then
        if [ "${IPA_TYPE}"x == "appstore"x ]; then
            XCONFIG='AppStore_Pre'
            EXPORTOPTION_PLIST=$WORKSPACE/AppStore_exportOptions.plist
        else
            XCONFIG='PRE'
            EXPORTOPTION_PLIST=$WORKSPACE/mobile-app/Enterprise_exportOptions.plist
        fi
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-demo'` -eq 1  ]; then
        if [ "${IPA_TYPE}"x == "demo-lobby" ]; then
            XCONFIG='Demo_Lobby'
            info "Build demo lobby app using ${XCONFIG}"
            EXPORTOPTION_PLIST=$WORKSPACE/mobile-app/Enterprise_exportOptions.plist
        elif [ "${IPA_TYPE}"x == "enterprise"x ]; then
            XCONFIG='Demo'
            EXPORTOPTION_PLIST=$WORKSPACE/mobile-app/Enterprise_exportOptions.plist
        else
            XCONFIG='AppStore_Demo'
            EXPORTOPTION_PLIST=$WORKSPACE/AppStore_exportOptions.plist
        fi
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-study'` -eq 1  ]; then
        if [ "${IPA_TYPE}"x == "enterprise"x ]; then
            XCONFIG='Study'
            EXPORTOPTION_PLIST=$WORKSPACE/mobile-app/Enterprise_exportOptions.plist
        else
            XCONFIG='AppStore_Study'
            EXPORTOPTION_PLIST=$WORKSPACE/AppStore_exportOptions.plist
        fi
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-staging'` -eq 1  ]; then
        if [ "${IPA_TYPE}"x == "appstore"x ]; then
            XCONFIG='AppStore_Staging'
            EXPORTOPTION_PLIST=$WORKSPACE/AppStore_exportOptions.plist
        else
            XCONFIG='Staging'
            EXPORTOPTION_PLIST=$WORKSPACE/mobile-app/Enterprise_exportOptions.plist
        fi
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-od.'` -eq 1  ]; then
        XCONFIG='ODx'
        info "Update BASE_URL to ${APIGW_ENDPOINT} in ODx.xcconfig"
        sed -i.bak -e "s|BASE_URL =.*|BASE_URL = ${APIGW_ENDPOINT}/v2|g" ${WORKSPACE}/mobile-app/Configs/ODx.xcconfig
        EXPORTOPTION_PLIST=$WORKSPACE/mobile-app/Enterprise_exportOptions.plist
    else
        error "Unsupported API Gateway ${APIGW_ENDPOINT}"
        exit 1
    fi
fi

rm -fr ${WORKSPACE}/mobile-app/MobileApp/PomFrameworks/*
mkdir -p ${WORKSPACE}/ArchFrameworks/{simulator,iphoneos}

info "Copy *.framework to ${WORKSPACE}/ArchFrameworks/iphoneos/"
cp -a ${WORKSPACE}/devops/ipa/target/*.framework ${WORKSPACE}/ArchFrameworks/iphoneos/ > /dev/null 2>&1
cp -a ${WORKSPACE}/devops/ipa/target/3rdParty-Frameworks/iphoneos/* ${WORKSPACE}/ArchFrameworks/iphoneos/ > /dev/null 2>&1
cp -a ${WORKSPACE}/devops/ipa/target/3rdParty-Frameworks/*.framework ${WORKSPACE}/ArchFrameworks/iphoneos/ > /dev/null 2>&1

info "Copy *.framework to ${WORKSPACE}/ArchFrameworks/simulator/"
cp -a ${WORKSPACE}/devops/ipa/target/*.framework ${WORKSPACE}/ArchFrameworks/simulator/ > /dev/null 2>&1
cp -a ${WORKSPACE}/devops/ipa/target/3rdParty-Frameworks/simulator/* ${WORKSPACE}/ArchFrameworks/simulator/ > /dev/null 2>&1
cp -a ${WORKSPACE}/devops/ipa/target/3rdParty-Frameworks/*.framework ${WORKSPACE}/ArchFrameworks/simulator/ > /dev/null 2>&1

info "Copy ${WORKSPACE}/devops/ipa/target/ArchFrameworks/*.a"
cp -a ${WORKSPACE}/devops/ipa/target/3rdParty-Frameworks/*.a ${WORKSPACE}/mobile-app/MobileApp/PomFrameworks/ > /dev/null 2>&1

if [ "${RUN_UNIT_TEST}"x == "true"x ]; then
    info "******************* Run unit test for IPA *******************"
    info "Platform Version: ${PLATFORM_VERSION}"
    info "Simulator Runtime: ${SIM_RUN_TIME}"
    info "Simulator OS: ${SIM_OS}"
    DEVICE_TYPE=$(xcrun simctl list -j devicetypes | jq '.devicetypes' | jq --raw-output ".[] | select(.name==\"$DEVICE_NAME\") | .identifier")
    if [ -z "${DEVICE_TYPE}" ]; then
        error "xcrun simctl list devicetypes does not have support for ${DEVICE_NAME}"
        exit 1
    fi
    info "Device type: ${DEVICE_TYPE}"
    DEVICE="${DEVICE_NAME}-${BUILD_NUMBER}"
    DEVICE_ID=$(xcrun simctl create "${DEVICE_NAME}-${BUILD_NUMBER}" ${DEVICE_TYPE} ${SIM_RUN_TIME})
    mkdir -p DerivedData
    echo "xcodebuild clean test -enableCodeCoverage YES -workspace MobileApp.xcworkspace/ -scheme Debug -derivedDataPath $WORKSPACE/DerivedData -destination "name=${DEVICE_NAME},OS=${SIM_OS}" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO | /usr/local/bin/xcpretty -r html -r junit"
    /Users/jenkins/build-wrapper-macosx-x86/build-wrapper-macosx-x86 --out-dir DerivedData/compilation-database xcodebuild clean test -enableCodeCoverage YES -workspace MobileApp.xcworkspace/ -scheme Debug -derivedDataPath $WORKSPACE/DerivedData -destination "name=${DEVICE_NAME},OS=${SIM_OS}" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO | /usr/local/bin/xcpretty -r html -r junit
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "xcodebuild test failed."
        xcrun simctl erase ${DEVICE_ID}
        exit 1
    fi
    info "Wipe the simulator ${DEVICE_NAME}"
    xcrun simctl erase ${DEVICE_ID}    
fi

if [ "${IPA_TYPE}"x == "simulator"x ]; then
    info "******************* Build ${IPA_TYPE} app for iOS Simulator *******************"
    info "XCONFIG ${XCONFIG}"
    echo "xcodebuild -scheme ${XCONFIG} -sdk iphonesimulator${SDK} ONLY_ACTIVE_ARCH=NO -arch x86_64 \
BUILD_DIR=\"../build\" -workspace MobileApp.xcworkspace"
    xcodebuild -scheme ${XCONFIG} -sdk iphonesimulator${SDK} ONLY_ACTIVE_ARCH=NO -arch x86_64 \
-derivedDataPath $WORKSPACE/DerivedData BUILD_DIR="../build" \
-workspace MobileApp.xcworkspace | tee $WORKSPACE/xcodebuild.log | /usr/local/bin/xcpretty
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "xcodebuild ${IPA_TYPE} failed."
        exit 1
    fi
    SIMULATOR_DIR=$(ls $WORKSPACE/build/ | grep iphonesimulator)
    info "Simulator directory: $WORKSPACE/build/${SIMULATOR_DIR}"
    pushd $WORKSPACE/build/${SIMULATOR_DIR}/ > /dev/null
    info "Rename MobileApp.app to ipa-${BUILD_VERSION}-${IPA_TYPE}.app" 
    /bin/mv -f MobileApp.app ipa-${BUILD_VERSION}-${IPA_TYPE}.app
    if [ $? -ne 0 ]; then
        error "MobileApp.app not found"
        exit 1
    fi
    info "Generate IPA build artifact zip."
    cp -a $WORKSPACE/Release/maven.info .
    cp -a $WORKSPACE/Release/*changelog.html .
    cp -a $WORKSPACE/Release/changelog-aggregate.html .
    zip --recurse-paths -x "*.DS_Store" --quiet $WORKSPACE/devops/ipa/target/ipa-artifact.zip ipa-${BUILD_VERSION}-${IPA_TYPE}.app maven.info ipa-changelog.html changelog-aggregate.html
    popd > /dev/null
    success "Build IPA-${BUILD_VERSION}-${IPA_TYPE}.app successful"
else
    info "******************* Build ${IPA_TYPE} app for real devices *******************"
    info "XCONFIG ${XCONFIG}"
    info "Unlock keychain for app signing"
    KEYCHAIN=$(ls $HOME/Library/Keychains/login.keychain-db 2>/dev/null)
    if [ -z "$KEYCHAIN" ]; then
        error "login.keychain not found."
        exit 1
    fi
    /usr/bin/security list-keychains -s $KEYCHAIN
    /usr/bin/security default-keychain -d user -s $KEYCHAIN
    /usr/bin/security unlock-keychain -p "$KEYCHAIN_PASSWD" $KEYCHAIN
    /usr/bin/security show-keychain-info $KEYCHAIN
    /usr/bin/security find-identity -p codesigning -v
    /usr/bin/security find-certificate -a -c "iPhone Distribution" -Z | grep ^SHA-1

    info "Build xarchive compatible with physical devices."
    echo "xcodebuild -workspace MobileApp.xcworkspace -scheme ${XCONFIG} archive \
-archivePath $WORKSPACE/build/MobileApp CONFIGURATION_BUILD_DIR=$WORKSPACE/build -derivedDataPath $WORKSPACE/DerivedData"
    xcodebuild -workspace MobileApp.xcworkspace -scheme ${XCONFIG} archive \
-archivePath $WORKSPACE/build/MobileApp CONFIGURATION_BUILD_DIR=$WORKSPACE/build -derivedDataPath $WORKSPACE/DerivedData | tee $WORKSPACE/xcodebuild.log | /usr/local/bin/xcpretty
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "xcodebuild build ${IPA_TYPE} failed."
        exit 1
    fi
	success "Xcode build xarchive package successful"
    info "Exporting IPA using xarchive package..."
    echo "xcodebuild -exportArchive -archivePath $WORKSPACE/build/MobileApp.xcarchive -exportOptionsPlist ${EXPORTOPTION_PLIST} -exportPath $WORKSPACE/Release"
    xcodebuild -exportArchive -archivePath $WORKSPACE/build/MobileApp.xcarchive -exportOptionsPlist ${EXPORTOPTION_PLIST} -exportPath $WORKSPACE/Release
    if [ $? -ne 0 ]; then
        error "xcodebuild exportArchive ${IPA_TYPE} failed."
        exit 1
    fi

    echo "Get actual IPA file name from Release directory"
    # Get the latest IPA build name
    IPA_BUILD_NAME=$(cd $WORKSPACE/Release; ls *.ipa 2>/dev/null)

	success "Export IPA from xarchive successful"
    info "Rename ${IPA_BUILD_NAME}.ipa to ipa-${BUILD_VERSION}-${IPA_TYPE}.ipa"
    mv -f $WORKSPACE/Release/${IPA_BUILD_NAME} $WORKSPACE/Release/ipa-${BUILD_VERSION}-${IPA_TYPE}.ipa
    if [ $? -ne 0 ]; then
        error "xcodebuild exportArchive IPA file missing."
        exit 1
    fi

    CURRNET_BYTE_SIZE=$(stat -f "%z" $WORKSPACE/Release/ipa-${BUILD_VERSION}-${IPA_TYPE}.ipa)
    if [ $? -ne 0 ]; then
        warn "App file not found ipa-${BUILD_VERSION}-${IPA_TYPE}.ipa"
    else
        MB_SIZE=$(echo "scale=0; ${CURRNET_BYTE_SIZE}/1024/1024" | bc -l)
        info "Current size of the ipa-${BUILD_VERSION}-${IPA_TYPE}.ipa is ${MB_SIZE}MB and limit max is ${MAX_APP_SIZE}"
        if [ -n "${MAX_APP_SIZE}" ]; then
            if [ ${MB_SIZE} -gt ${MAX_APP_SIZE} ]; then
                warn "App size ${MB_SIZE} is larger than max of ${MAX_APP_SIZE}"
                echo "APP_NAME=ipa-${BUILD_VERSION}-${IPA_TYPE}.ipa" > $WORKSPACE/app.size.warning
                echo "MB_SIZE=${MB_SIZE}" >> $WORKSPACE/app.size.warning
            fi
        fi
    fi
    
    if [ "${IPA_TYPE}"x == "enterprise"x ]; then
        pushd ${WORKSPACE}/Release/ > /dev/null
        EXPIRATION_DATE=$(unzip -p ipa-${BUILD_VERSION}-enterprise.ipa \*/embedded.mobileprovision | grep -a -A 2 ExpirationDate | grep date | sed -e 's/^.*<date>\(.*\)<\/date>/\1/')
        info "**************************************************************************************************************"
        info ""
        info "        Eneterprise Build Provisioning Profile expiration date [${EXPIRATION_DATE}]"
        info ""
        info "**************************************************************************************************************"
        popd > /dev/null
    fi

    info "Copy MobileApp.xcarchive package to Release dir for archiving"
    cp -a ${WORKSPACE}/build/MobileApp.xcarchive $WORKSPACE/Release/
    if [ $? -ne 0 ]; then
        error "Copy task failed."
        exit 1
    fi

    info "Copy dSYM package to Release dir for archiving"
    cp -a ${WORKSPACE}/build/*.dSYM $WORKSPACE/Release/
    if [ $? -ne 0 ]; then
        error "Copy task failed."
        exit 1
    fi

    info "Copy bcsymbolmap files to Release dir for archiving"
    cp -a ${WORKSPACE}/build/*.bcsymbolmap $WORKSPACE/Release/
    if [ $? -ne 0 ]; then
        error "Copy task failed."
        exit 1
    fi

    info "Generate IPA build artifact zip."
    (cd $WORKSPACE/Release/; zip --recurse-paths -x "*.DS_Store" --quiet $WORKSPACE/ipa-${BUILD_VERSION}-${IPA_TYPE}.zip ipa-${BUILD_VERSION}-${IPA_TYPE}.ipa *.dSYM MobileApp.xcarchive *.bcsymbolmap maven.info *changelog.html changelog-aggregate.html)
    if [ $? -ne 0 ]; then
        error "Artifact package task failed."
        exit 1
    fi
    mv -f $WORKSPACE/ipa-${BUILD_VERSION}-${IPA_TYPE}.zip $WORKSPACE/devops/ipa/target/ipa-artifact.zip

    if [ "${RESIGN_IPA}"x == 'true'x -a `echo ${APIGW_ENDPOINT} | grep -c 'api-prod'` -eq 1  ]; then
        # Only resign app if end point is prod
        pushd $WORKSPACE > /dev/null
        XCONFIG='mobile-app/Configs/Enterprise_Prod.xcconfig'
        if [ ! -f ${XCONFIG} ]; then
            error "File ${XCONFIG} not found"
            exit 1
        fi
        info "XCONFIG ${XCONFIG}"
        DISPLAY_NAME=$(grep 'D_BUNDLE_DISPLAY_NAME' ${XCONFIG} | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//')
        BUNDLE_ID=$(grep 'D_BUNDLE_ID' ${XCONFIG} | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//')
        PROFILE_NAME=$(grep 'D_PROVISIONING_PROFILE' ${XCONFIG} | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//')
        TEAM_ID=$(grep 'D_TEAM_ID' ${XCONFIG} | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//')
        BUILD_CONFIG=$(grep 'BUILD_CONFIG' ${XCONFIG} | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//')
        APNS_CONFIG=$(grep 'BUILD_CONFIG_VALUE' ${XCONFIG} | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//')
        PROVISIONING_PROFILE=$(grep -a -H "${PROFILE_NAME}" ~/Library/MobileDevice/Profiles/*  | awk -F: '{print $1}' | sed 's/ /\\ /g')
        if [ -z "${PROVISIONING_PROFILE}" ]; then
            error "Provisioning Profile: ${PROFILE_NAME} not found"
            exit 1
        fi
        info "Update xcarchive Info.plist for Enterprise IPA"
        /usr/libexec/PlistBuddy -c "Set :ApplicationProperties:CFBundleIdentifier ${BUNDLE_ID}" build/MobileApp.xcarchive/Info.plist
        /usr/libexec/PlistBuddy -c "Set :ApplicationProperties:Team ${TEAM_ID}" build/MobileApp.xcarchive/Info.plist
        /usr/libexec/PlistBuddy -c "Set :ApplicationProperties:SigningIdentity iPhone Distribution:  Digital Health, Inc." build/MobileApp.xcarchive/Info.plist
        /usr/libexec/PlistBuddy -c "Set :Name ipa-${BUILD_VERSION}-enterprise" build/MobileApp.xcarchive/Info.plist
        if [ $? -ne 0 ]; then
            error "Failed to update build/MobileApp.xcarchive/Info.plist"
            exit 1
        fi
        info "Replace embedded.mobileprovision with Enterprise provisioning profile"
        rm -fr build/MobileApp.xcarchive/Products/Applications/MobileApp.app/_CodeSignature/
        rm -f build/MobileApp.xcarchive/Products/Applications/MobileApp.app/embedded.mobileprovision
        cp -f "${PROVISIONING_PROFILE}" build/MobileApp.xcarchive/Products/Applications/MobileApp.app/embedded.mobileprovision
        if [ $? -ne 0 ]; then
            error "Failed to find Enterprise Provisioning profile"
            exit 1
        fi
        info "Update Application Info.plist for Enterprise IPA"
        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${DISPLAY_NAME}"  build/MobileApp.xcarchive/Products/Applications/MobileApp.app/Info.plist
        /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}"  build/MobileApp.xcarchive/Products/Applications/MobileApp.app/Info.plist
        /usr/libexec/PlistBuddy -c "Set ::apnsID ${APNS_CONFIG}" build/MobileApp.xcarchive/Products/Applications/MobileApp.app/Info.plist
        /usr/libexec/PlistBuddy -c "Set ::buildConfig ${BUILD_CONFIG}" build/MobileApp.xcarchive/Products/Applications/MobileApp.app/Info.plist
        if [ $? -ne 0 ]; then
            error "Failed to update build/MobileApp.xcarchive/Products/Applications/MobileApp.app/Info.plist"
            exit 1
        fi
        info "CodeSign Framework with Enterprise provisioning profile"
        codesign -f -s "iPhone Distribution:  Digital Health, Inc." build/MobileApp.xcarchive/Products/Applications/MobileApp.app/Frameworks/*
        info "CodeSign Application with Enterprise provisioning profile"
        codesign -f -s "iPhone Distribution:  Digital Health, Inc." build/MobileApp.xcarchive/Products/Applications/MobileApp.app
        cat << EOF >> exportOptions.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>compileBitcode</key>
	<false/>
	<key>method</key>
	<string>enterprise</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>uploadBitcode</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
	<key>iCloudContainerEnvironment</key>
	<string>Production</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BUNDLE_ID}</key>
		<string>${PROFILE_NAME}</string>
	</dict>
</dict>
</plist>
EOF
        info "Create new Eneterprise IPA"
        echo "xcodebuild -exportArchive -archivePath build/MobileApp.xcarchive -exportOptionsPlist exportOptions.plist -exportPath Release 2>/dev/null"
        xcodebuild -exportArchive -archivePath build/MobileApp.xcarchive -exportOptionsPlist exportOptions.plist -exportPath Release 2>/dev/null
        info "Generate Enterprise IPA build artifact zip."
        (cd $WORKSPACE/Release/; zip --recurse-paths -x "*.DS_Store" --quiet $WORKSPACE/ipa-${BUILD_VERSION}-enterprise.zip ipa-${BUILD_VERSION}-enterprise.ipa *.dSYM MobileApp.xcarchive *.bcsymbolmap maven.info *changelog.html changelog-aggregate.html)
        if [ $? -ne 0 ]; then
            error "Eneterrise Artifact package task failed."
            exit 1
        fi
        pushd ${WORKSPACE}/Release/ > /dev/null
        EXPIRATION_DATE=$(unzip -p ipa-${BUILD_VERSION}-enterprise.ipa \*/embedded.mobileprovision | grep -a -A 2 ExpirationDate | grep date | sed -e 's/^.*<date>\(.*\)<\/date>/\1/')
        info "**************************************************************************************************************"
        info ""
        info "        Eneterprise Build Provisioning Profile expiration date [${EXPIRATION_DATE}]"
        info ""
        info "**************************************************************************************************************"
        popd > /dev/null
        mv -f $WORKSPACE/ipa-${BUILD_VERSION}-enterprise.zip $WORKSPACE/devops/ipa/target/ipa-artifact-enterprise.zip
        info "Update pom-ipa.xml also deploy enterprise IPA"
        cp -a $WORKSPACE/devops/ipa/pom-ipa-enterprise.xml $WORKSPACE/devops/ipa/pom-ipa.xml
    fi

    # PROD/INT/STUDY iOS NEWRELIC_APP_TOKEN defined in Jenkins Credentials Config
    if [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-int'` -eq 1 ]; then
        info "AWS-INT: build upload the iOS mobile app dSYM to NewRelic using variable INT_IPA_NEWRELIC_APP_TOKEN"
        NEWRELIC_UPLOAD='true'
        NEWRELIC_APP_TOKEN=${INT_IPA_NEWRELIC_APP_TOKEN}
        export NEWRELIC_APP_NAME='iOS Patient App (INT)'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-prod'` -eq 1 ]; then
        info "PROUDCTION: Upload the iOS mobile app dSYM to NewRelic using variable PROD_IPA_NEWRELIC_APP_TOKEN"
        NEWRELIC_APP_TOKEN=${PROD_IPA_NEWRELIC_APP_TOKEN}
        NEWRELIC_UPLOAD='true'
        export NEWRELIC_APP_NAME='iOS Patient App (PROD)'
    elif [ `echo ${APIGW_ENDPOINT} | egrep -c 'api-study'` -eq 1 ]; then
        info "AWS-STUDY: Upload the iOS mobile app dSYM to NewRelic using variable STUDY_IPA_NEWRELIC_APP_TOKEN"
        NEWRELIC_APP_TOKEN=${STUDY_IPA_NEWRELIC_APP_TOKEN}
        NEWRELIC_UPLOAD='true'
        export NEWRELIC_APP_NAME='iOS Patient App (STUDY)'
    else
        NEWRELIC_UPLOAD='false'
    fi

    if [ -n "${NEWRELIC_APP_TOKEN}" ]; then
        if [ "${NEWRELIC_UPLOAD}"x == 'true'x ]; then
            pushd $WORKSPACE/Release > /dev/null
            info "Relocate framewokr dSYM to pushd $WORKSPACE/Release"
            mv -f $WORKSPACE/devops/ipa/target/*.dSYM $WORKSPACE/Release/
            for DSYM in `find . -type d -name "*.dSYM"`; do
                SYM_NAME=$(echo $DSYM | xargs basename)
                BUILD_ID=$(xcrun dwarfdump --uuid "${SYM_NAME}" | tr '[:upper:]' '[:lower:]' | tr -d '-'| awk '{print $2}' | xargs | sed 's/ /,/g')
                info "$SYM_NAME build id: $BUILD_ID"
                /usr/bin/zip --recurse-paths -x "*.DS_Store" --quiet "${SYM_NAME}.zip" "${SYM_NAME}"
                info "Starting NewRelic dSym upload..."
                echo "curl -F dsym=@"${SYM_NAME}.zip" -F buildId="$BUILD_ID" -F appName="${NEWRELIC_APP_NAME}" -H "X-APP-LICENSE-KEY: *******************" https://mobile-symbol-upload.newrelic.com/symbol"
                curl -F dsym=@"${SYM_NAME}.zip" -F buildId="$BUILD_ID" -F appName="${NEWRELIC_APP_NAME}" -H "X-APP-LICENSE-KEY: ${NEWRELIC_APP_TOKEN}" https://mobile-symbol-upload.newrelic.com/symbol
                rm -f "${SYM_NAME}.zip"
            done
            popd > /dev/null
        fi
    else
        info "Skip newrelic upload because NEWRELIC_APP_TOKEN is undefined"
    fi
fi

exit 0

