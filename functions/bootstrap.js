// Cloud Functions package bootstrap.
//
// Keep large subsystems isolated while exporting the deployed callable surface
// from a single package entry point.
require("./map");

const deployedFunctions = require("./index");
const {initializeBunker} = require("./onboarding");
const {
  getExpeditionLauncherInfo,
  resolveCompletedOccupations,
  startExpedition,
} = require("./expedition_callables");

module.exports = {
  ...deployedFunctions,
  // Override legacy implementations while keeping the public callable names
  // stable for Flutter.
  initializeBunker,
  getExpeditionLauncherInfo,
  startExpedition,
  resolveCompletedOccupations,
};
