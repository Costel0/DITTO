// Cloud Functions package bootstrap.
//
// Keep large subsystems isolated in their own modules while loading them as
// part of the deployed backend bundle. Map administration itself is NOT
// exposed as a client callable; scripts and future gameplay code reuse the
// functions/map module directly.
require("./map");

module.exports = require("./index");
