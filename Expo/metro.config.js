const path = require('path');
const { getDefaultConfig } = require('expo/metro-config');
const config = getDefaultConfig(__dirname);
// Both implementations consume the same balance and localization JSON.
config.watchFolders = [path.resolve(__dirname, '../Sources/SpiritboundCore/Resources')];
module.exports = config;
