#!/bin/sh

#  He3Versionator.sh
#  He3
#
#  Created by Carlos D. Santiago on 12/29/20.
#  Copyright © 2020-2021 Carlos D. Santiago. All rights reserved.
#
#  Act on CFBuildIncrement tag: major, minor, patch, build
#
#  Always rewrite CFBundleShortVersionString from components.
#  Verify current CFBundleShortVersionString matches its components
#  Always rewrite the build date as now.

set -x
buildPlist="He3/Info.plist"
sharePlist="He3ShareExtension/Info.plist"
testsPlist="He3Tests/Info.plist"
loginPlist="He3Launcher/Info.plist"
qlExtPlist="He3QLExtension/Info.plist"

b_maj=$(/usr/libexec/PlistBuddy -c "Print CFBuildMajor" $buildPlist)
b_min=$(/usr/libexec/PlistBuddy -c "Print CFBuildMinor" $buildPlist)
b_pat=$(/usr/libexec/PlistBuddy -c "Print CFBuildPatch" $buildPlist)
build=$(/usr/libexec/PlistBuddy -c "Print CFBuildNumber" $buildPlist)
buildDate=$(date "+%Y%m%d.%H%M%S")
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $buildPlist)

echo "old ${version} (${build})"

# Verify CFBundleShortVersionString against its components.
IFS="." read major minor patch <<< "$version"
if [[ $major -ne $b_maj || $minor -ne $b_min || $patch -ne $b_pat ]]; then
  echo "Current version:${version} is not ${b_maj}.${b_min}.${b_pat}"
  exit 5
fi

# Increment the build if asked
buildIncr=$(/usr/libexec/PlistBuddy -c "Print CFBuildIncrement" $buildPlist)
if [ "$buildIncr" = "major" ]; then

    major=$(($major + 1))
	minor=0
	patch=0

elif [ "$buildIncr" = "minor" ]; then

    minor=$(($minor + 1))
    patch=0

elif [ "$buildIncr" = "patch" ]; then

    patch=$(($patch + 1))

elif [ "$buildIncr" = "build" ]; then

    build=$(($build + 1))

fi

# Formulate the bundle versions
bundleVersion="${major}.${minor}.${build}"
version="${major}.${minor}.${patch}"

echo "new ${version} (${build})"

# Set the version numbers in the buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildMajor $major" $buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildMinor $minor" $buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildPatch $patch" $buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildNumber $build" $buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildDate $buildDate" $buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundleVersion" $buildPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" $buildPlist

# Propagate to share
/usr/libexec/PlistBuddy -c "Set :CFBuildMajor $major" $sharePlist
/usr/libexec/PlistBuddy -c "Set :CFBuildMinor $minor" $sharePlist
/usr/libexec/PlistBuddy -c "Set :CFBuildPatch $patch" $sharePlist
/usr/libexec/PlistBuddy -c "Set :CFBuildNumber $build" $sharePlist
/usr/libexec/PlistBuddy -c "Set :CFBuildDate $buildDate" $sharePlist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundleVersion" $sharePlist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" $sharePlist

# Propagate to tests
/usr/libexec/PlistBuddy -c "Set :CFBuildMajor $major" $testsPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildMinor $minor" $testsPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildPatch $patch" $testsPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildNumber $build" $testsPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildDate $buildDate" $testsPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundleVersion" $testsPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" $testsPlist

# Propagate to launcher
/usr/libexec/PlistBuddy -c "Set :CFBuildMajor $major" $loginPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildMinor $minor" $loginPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildPatch $patch" $loginPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildNumber $build" $loginPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildDate $buildDate" $loginPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundleVersion" $loginPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" $loginPlist

# Propagate to QL Extension
/usr/libexec/PlistBuddy -c "Set :CFBuildMajor $major" $qlExtPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildMinor $minor" $qlExtPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildPatch $patch" $qlExtPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildNumber $build" $qlExtPlist
/usr/libexec/PlistBuddy -c "Set :CFBuildDate $buildDate" $qlExtPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundleVersion" $qlExtPlist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" $qlExtPlist
