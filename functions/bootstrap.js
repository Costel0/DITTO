// Cloud Functions package bootstrap.
//
// Keep large subsystems isolated while exporting the deployed callable surface
// from a single package entry point.
require("./map");

const deployedFunctions = require("./index");
const {initializeBunker} = require("./onboarding");

module.exports = {
  ...deployedFunctions,
  // Override the legacy initializer exported by index.js. The callable name
  // remains exactly the same for Flutter, but first profile setup now reserves
  // the player's real map sector in the same logical onboarding operation.
  initializeBunker,
};
