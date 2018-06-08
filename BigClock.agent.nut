// Big Clock
// Copyright 2014-18, Tony Smith

// IMPORTS
#require "Rocky.class.nut:2.0.1"

// If you are NOT using Squinter or a similar tool, comment out the following line...
#import "~/Dropbox/Programming/Imp/Codes/bigclock.nut"
// ...and uncomment and fill in this line:
// const APP_CODE = "YOUR_APP_UUID";

// CONSTANTS
const RESTART_TIMEOUT = 120;
const CHECK_TIME = 43200;
const HTML_STRING = @"
#import "bigclock_ui.html"
";

// GLOBALS
local settings = null;
local api = null;
local agentRestartTimer = null;
local firstTime = false;    // USE 'true' TO ZAP THE RTC
local firstRun = false;     // USE 'true' TO ZAP THE STORED DEFAULTS
local debug = false;

// CLOCK FUNCTIONS
function sendPrefsToDevice(value) {
    // Big Clock has requested the current set-up data
    if (debug) server.log("Sending stored preferences to the device");

    if (firstTime) {
        // If firstTime is valid, this is a first run, so send the
        // clock a message to set the current time
        device.send("bclock.first.time", true);
        firstTime = false;
    }

    // Send the prefs
    device.send("bclock.set.prefs", settings);
}

function appResponse() {
    // Responds to the app's request for the clock's set-up data
    // Generates a string in the form:
    //
    //   1.1.1.1.01.1.01.1.d.1
    //
    // for the values
    //   0. mode
    //   1. bst state
    //   2. colon flash
    //   3. colon state
    //   4. brightness
    //   5. utc state
    //   6. utc offset
    //   7. display state
    //   8. connection status
    //   9. debug status
    //
    // UTC offset is the value for the app's UI slider, ie. 0 to 24
    // (mapping in device code to offset values of +12 to -12)

    // Add Mode as a 1-digit value
    local rs = "0.";
    if (settings.mode == true) rs = "1.";

    // Add BST status as a 1-digit value
    rs = rs + ((settings.bst) ? "1." : "0.");

    // Add colon flash status as a 1-digit value
    rs = rs + ((settings.flash) ? "1." : "0.");

    // Add colon state as a 1-digit value
    rs = rs + ((settings.colon) ? "1." : "0.");

    // Add brightness as a two-digit value
    rs = rs + settings.brightness.tostring() + ".";

    // Add UTC status as a 1-digit value
    rs = rs + ((settings.utc) ? "1." : "0.");

    // Add UTC offset
    local s = settings.offset + 12;
    rs = rs + s.tostring() + ".";

	// Add clock state as 1-digit value
	rs = rs + ((settings.on) ? "1." : "0.");

    // Add d to indicate disconnected, or c
    rs = rs + (device.isconnected() ? "c." : "d.");

    // Add debug state
    rs = rs + (debug ? "1" : "0");

    return rs;
}

function resetToDefaults() {
    // Reset settings values to the defaults
    server.save({});
    resetSettings();
    firstTime = true;
    server.save(settings);
}

function resetSettings() {
    // Cache the clock preferences
    // The table is formatted thus:
    //    ON: true/false for display on
    //    MODE: true/false for 24/12-hour view
    //    BST: true/false for adapt for daylight savings/stick to GMT
    //    COLON: true/false for colon shown if NOT flashing
    //    FLASH: true/false for colon flash
    //    UTC: true/false for UTC set/unset
    //    OFFSET: -12 to +12 for GMT offset
    //    BRIGHTNESS: 1 to 15 for boot-set LED brightness
    //    DEBUG: true/false

    settings = {};
    settings.on <- true;
    settings.mode <- true;
    settings.bst <- true;
    settings.colon <- true;
    settings.flash <- true;
    settings.utc <- false;
    settings.offset <- 0;
    settings.brightness <- 15;
    settings.debug <- false;
    debug = false;
}

// PROGRAM START

// IMPORTANT Set firstRun at the top of the listing to reset saved settings
if (firstRun) resetToDefaults();

local savedSettings = server.load();

if (savedSettings.len() != 0) {
    // Table is NOT empty so set 'settings' to the loaded table
    settings = savedSettings;
    debug = settings.debug;
} else {
    // Table is empty, so this must be a first run
    if (debug) server.log("First run - performing setup");
    resetSettings();
    server.save(settings);
    firstTime = true;
}

// Register device event triggers
device.on("bclock.get.prefs", sendPrefsToDevice);

// Set up the API
api = Rocky();

// GET call to the root so return the web app
api.get("/", function(context) {
    context.send(200, format(HTML_STRING, http.agenturl()));
});

// GET call to /settings  - return the settings string
api.get("/settings", function(context) {
    context.send(200, appResponse());
});

// POST to /settings - update the settings and inform the device
api.post("/settings", function(context) {
    try {
        local data = http.jsondecode(context.req.rawbody);

        // Check for a mode-set message
        if ("setmode" in data) {
            if (data.setmode == "1") {
                settings.mode = true;
            } else if (data.setmode == "0") {
                settings.mode = false;
            } else {
                if (debug) server.error("Mis-formed parameter to setmode");
                context.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(settings) > 0) server.error("Could not save mode setting");
            if (debug) server.log("Clock mode turned to " + (settings.mode ? "24 hour" : "12 hour"));
            device.send("bclock.set.mode", settings.mode);
        }

        // Check for a BST set/unset message
        if ("setbst" in data) {
            if (data.setbst == "1") {
                settings.bst = true;
            } else if (data.setbst == "0") {
                settings.bst = false;
            }  else {
                if (debug) server.error("Mis-formed parameter to setbst");
                context.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(settings) > 0) server.error("Could not save BST/GMT setting");
            if (debug) server.log("Clock bst observance turned " + (settings.bst ? "on" : "off"));
            device.send("bclock.set.bst", settings.bst);
        }

        // Check for a set brightness message
        if ("setbright" in data) {
            settings.brightness = data.setbright.tointeger();
            if (server.save(settings) != 0) server.error("Could not save brightness setting");
            if (debug) server.log(format("Brightness set to %i", settings.brightness));
            device.send("bclock.set.brightness", settings.brightness);
        }

        // Check for a set flash message
        if ("setflash" in data) {
            if (data.setflash == "1") {
                settings.flash = true;
            } else if (data.setflash == "0") {
                settings.flash = false;
            } else {
                if (debug) server.error("Mis-formed parameter to setflash");
                context.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(settings) > 0) server.error("Could not save colon flash setting");
            if (debug) server.log("Clock colon flash turned " + (settings.flash ? "on" : "off"));
            device.send("bclock.set.flash", settings.flash);
        }

        // Check for a set colon show message
        if ("setcolon" in data) {
            if (data.setcolon == "1") {
                settings.colon = true;
            } else if (data.setcolon == "0") {
                settings.colon = false;
            } else {
                if (debug) server.error("Attempt to pass an mis-formed parameter to setcolon");
                context.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(settings) > 0) server.error("Could not save colon visibility setting");
            if (debug) server.log("Clock colon turned " + (settings.colon ? "on" : "off"));
            device.send("bclock.set.colon", settings.colon);
        }

        // Check for set light message
        if ("setlight" in data) {
            if (data.setlight == "1") {
                settings.on = true;
            } else if (data.setlight == "0") {
                settings.on = false;
            } else {
                if (debug) server.error("Attempt to pass an mis-formed parameter to setlight");
                contex.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(settings) > 0) server.error("Could not save display light setting");
            if (debug) server.log("Clock display turned " + (settings.on ? "on" : "off"));
            device.send("bclock.set.light", settings.on);
        }

        if ("setutc" in data) {
            if (data.setutc == "0") {
                settings.utc = false;
                device.send("bclock.set.utc", "N");
            } else if (data.setutc == "1") {
                settings.utc = true;
                if ("utcval" in data) {
                    // Store offset as a value from -12 to +12, derived from the value 0 to 24 returned by the web app
                    settings.offset = data.utcval.tointeger() - 12;
                    device.send("bclock.set.utc", settings.offset);
                } else {
                    device.send("bclock.set.utc", settings.offset);
                }
            } else {
                if (debug) server.error("Attempt to pass an mis-formed parameter to setutc");
                contex.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(settings) > 0) server.error("Could not save world time setting");
            if (debug) server.log("World time turned " + (settings.utc ? "on" : "off") + ", offset: " + settings.offset);
        }

        context.send(200, "OK");
    } catch (err) {
        server.error(err);
        context.send(400, "Bad data posted");
        return;
    }

    context.send(200, "OK");
});

api.post("/action", function(context) {
    try {
        local data = http.jsondecode(context.req.rawbody);

        if ("action" in data) {
            if (data.action == "reset") {
                resetToDefaults();
                sendPrefsToDevice(true);
                if (debug) server.log("Clock settings reset");
                if (server.save(settings) != 0) server.error("Could not save clock settings after reset");
            }

            if (data.action == "debug") {
                if (data.value == "1") {
                    debug = true;
                } else if (data.value == "0") {
                    debug = false;
                }

                settings.debug = debug;
                device.send("bclock.set.debug", debug);
                server.log("Debug mode " + (debug ? "on" : "off"));
                if (server.save(settings) != 0) server.error("Could not save clock settings after reset");
            }
        }

        context.send(200, "OK");
    } catch (err) {
        context.send(400, "Bad data posted");
        server.error(err);
        return;
    }
});

// GET at /controller/info returns app info for Controller
api.get("/controller/info", function(context) {
    local info = { "appcode": APP_CODE,
                   "watchsupported": "true" };
    context.send(200, http.jsonencode(info));
});

// GET call to /controller/state returns device status
api.get("/controller/state", function(context) {
    local data = (device.isconnected() ? "1" : "0");
    context.send(200, data);
});

