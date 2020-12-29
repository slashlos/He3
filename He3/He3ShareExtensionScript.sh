#!/bin/sh

#  He3ShareExtensionScript.sh
#  He3
#
#  Created by Carlos D. Santiago on 12/29/20.
#  Copyright © 2020 Carlos D. Santiago. All rights reserved.

set -x
buildPlist="He3/Info.plist"
sharePlist="He3ShareExtension/Info.plist"
testsPlist="He3Tests/Info.plist"
loginPlist="He3Launcher/Info.plist"
qlExtPlist="He3QLExtension/Info.plist"

buildMajor=$(/usr/libexec/PlistBuddy -c "Print CFBuildMajor" $buildPlist)
buildMinor=$(/usr/libexec/PlistBuddy -c "Print CFBuildMinor" $buildPlist)
buildPatch=$(/usr/libexec/PlistBuddy -c "Print CFBuildPatch" $buildPlist)
buildNumber=$(/usr/libexec/PlistBuddy -c "Print CFBuildNumber" $buildPlist)
buildDate=$(date "+%Y%m%d.%H%M%S")

# Increment the buildNumber if asked
buildIncr=$(/usr/libexec/PlistBuddy -c "Print CFBuildIncrement" $buildPlist)
if [ "$buildIncr" = "true" ];
then
    buildNumber=$(($buildNumber + 1))
fi

# Formulate the bundle versions
bundleVersion=$buildMajor.$buildMinor.$buildNumber
bundleShortVersion=$buildMajor.$buildMinor.$buildPatch

# Set the version numbers in the buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildNumber $buildNumber" $buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildDate $buildDate" $buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundleVersion" $buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $bundleShortVersion" $buildPlist

# Propagate to share
/usr/libexec/PlistBuddy -c "Set :CFBuildNumber $buildNumber" $sharePlist
/usr/libexec/PlistBuddy -c "Set :CFBuildDate $buildDate" $sharePlist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundleVersion" $sharePlist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $bundleShortVersion" $sharePlist

# Propagate to tests
/usr/libexec/PlistBuddy -c "Set :CFBuildNumber $buildNumber" $testsPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildDate $buildDate" $testsPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundleVersion" $testsPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $bundleShortVersion" $testsPlist

# Propagate to launcher
/usr/libexec/PlistBuddy -c "Set :CFBuildNumber $buildNumber" $loginPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildDate $buildDate" $loginPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundleVersion" $loginPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $bundleShortVersion" $loginPlist

# Propagate to QL Extension
/usr/libexec/PlistBuddy -c "Set :CFBuildNumber $buildNumber" $qlExtPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildDate $buildDate" $qlExtPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundleVersion" $qlExtPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $bundleShortVersion" $qlExtPlist
