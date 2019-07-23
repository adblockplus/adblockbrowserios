# Populate Plist with API Data (Fabric).
API_DATA_ENV_VARS="ABB-Secret-API-Env-Vars.sh"
if [ -f ./$API_DATA_ENV_VARS ]
then
source ./$API_DATA_ENV_VARS
/usr/libexec/PlistBuddy -c "Delete :Fabric" $PROJECT_DIR/AdBlockBrowser/Info.plist
/usr/libexec/PlistBuddy -c "Add :Fabric dict" $PROJECT_DIR/AdBlockBrowser/Info.plist
/usr/libexec/PlistBuddy -c "Add :Fabric:APIKey string \"$FABRIC_API_KEY\"" $PROJECT_DIR/AdBlockBrowser/Info.plist
/usr/libexec/PlistBuddy -c "Add :Fabric:Kits array" $PROJECT_DIR/AdBlockBrowser/Info.plist
/usr/libexec/PlistBuddy -c "Add :Fabric:Kits: dict" $PROJECT_DIR/AdBlockBrowser/Info.plist
/usr/libexec/PlistBuddy -c "Add :Fabric:Kits:0:KitInfo dict" $PROJECT_DIR/Adblock\ Plus/Info.plist
/usr/libexec/PlistBuddy -c "Add :Fabric:Kits:0:KitName string \"Crashlytics\"" $PROJECT_DIR/AdBlockBrowser/Info.plist
else
echo "warning: API data for Fabric not found. The app will run but will not make use of Fabric."
fi
