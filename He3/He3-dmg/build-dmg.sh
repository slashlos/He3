#!/bin/sh
#set -x
export |sort>~/Desktop/env.txt

buildPlist="${PROJECT}/Info.plist"

buildMajor=$(/usr/libexec/PlistBuddy -c "Print CFBuildMajor" $buildPlist)
buildMinor=$(/usr/libexec/PlistBuddy -c "Print CFBuildMinor" $buildPlist)
buildNumber=$(/usr/libexec/PlistBuddy -c "Print CFBuildNumber" $buildPlist)
buildDate=$(date "+%Y%m%d.%H%M%S")

dmgName="${PROJECT} $buildMajor.$buildMinor.$buildNumber"; export dmgName
dmgFile="/users/${USER}/Desktop/$dmgName.dmg"; export dmgFile
test -f ${dmgFile} && rm -v ${dmgFile}
appPath=`find $SYMROOT -name $PROJECT.app -print`; export appPath

### ~/GitHub/create-dmg/create-dmg --window-size 500 300 --background "${PROJECT_DIR}/${PROJECT}/Assets/background.png" --icon-size 96 --volname "${dmgName}" --app-drop-link 380 205 --icon ${PROJECT_DIR}/${PROJECT}/Assets/${PROJECT}.icns 110 205 ${dmgFile} ${appPath}/

tmp="/tmp/helium$$.json"
cat > $tmp << EOF
{
    "title": "$dmgName",
    "icon-size" : 96,
    "icon": "${PROJECT_DIR}/${PROJECT}/Assets/${PROJECT}.icns",
    "background": "${PROJECT_DIR}/${PROJECT}/Assets/background.png",
    "contents": [
        { "x": 400, "y": 200, "type": "link", "path": "/Applications" },
        { "x": 100, "y": 200, "type": "file", "path": "$appPath" }
    ]
}
EOF
appdmg ${tmp} "${dmgFile}"
