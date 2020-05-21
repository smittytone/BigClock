// Big Clock
// Copyright 2014-19, Tony Smith

// ********** IMPORTS **********
#require "Rocky.agent.lib.nut:3.0.0"

// If you are NOT using Squinter or a similar tool, comment out the following line...
#import "~/OneDrive/Programming/BigClock/bigclock.nut"
// ...and uncomment and fill in this line:
// const APP_CODE = "YOUR_APP_UUID";
#import "../generic-squirrel/simpleslack.nut"        // Source: https://github.com/smittytone/generic-squirrel
#import "../generic-squirrel/crashReporter.nut"      // Source: https://github.com/smittytone/generic-squirrel

// If you are NOT using Squinter or a similar tool, replace the following #import statement(s)
// with the contents of the named file(s):
const HTML_STRING = @"
#import "bigclock_ui.html"
";                                          // Source code: https://github.com/smittytone/BigClock


// ********** CONSTANTS **********
const RESTART_TIMEOUT = 120;
const CHECK_TIME = 43200;


// ********** MAIN VARIABLES **********
local settings = null;
local api = null;
local agentRestartTimer = null;
local firstTime = false;    // USE 'true' TO ZAP THE RTC
local firstRun = false;     // USE 'true' TO ZAP THE STORED DEFAULTS


// ********** SETTINGS FUNCTIONS **********
function sendPrefsToDevice(ignored) {
    // Big Clock has requested the current set-up data
    if (settings.debug) server.log("Sending stored preferences to the device");

    if (firstTime) {
        // If firstTime is valid, this is a first run, so send the
        // clock a message to set the current time
        device.send("bclock.first.time", true);
        firstTime = false;
    }

    // Send the prefs to the device
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
    rs += ((settings.bst) ? "1." : "0.");

    // Add colon flash status as a 1-digit value
    rs += ((settings.flash) ? "1." : "0.");

    // Add colon state as a 1-digit value
    rs += ((settings.colon) ? "1." : "0.");

    // Add brightness as a two-digit value
    local b = settings.brightness + 1;
    rs += (b.tostring() + ".");

    // Add UTC status as a 1-digit value
    rs += ((settings.utc) ? "1." : "0.");

    // Add UTC offset
    local s = settings.offset + 12;
    rs += (s.tostring() + ".");

	// Add clock state as 1-digit value
	rs += ((settings.on) ? "1." : "0.");

    // Add d to indicate disconnected, or c
    rs += (device.isconnected() ? "c." : "d.");

    // Add debug state
    rs += (settings.debug ? "1" : "0");

    return rs;
}

function resetToDefaults() {
    // Reset settings values to the defaults
    initialiseSettings();
    firstTime = true;
    server.save(settings);
}

function initialiseSettings() {
    // Cache the clock preferences
    // The table is formatted thus:
    //    ON: true/false for display on
    //    MODE: true/false for 24/12-hour view
    //    BST: true/false for adapt for daylight savings/stick to GMT
    //    COLON: true/false for colon shown if NOT flashing
    //    FLASH: true/false for colon flash
    //    UTC: true/false for UTC set/unset
    //    OFFSET: -12 to +12 for GMT offset
    //    BRIGHTNESS: 0 to 15 for boot-set LED brightness
    //    DEBUG: true/false
    settings = {};
    settings.on <- true;
    settings.mode <- true;
    settings.bst <- true;
    settings.colon <- true;
    settings.flash <- true;
    settings.utc <- false;
    settings.offset <- 0;
    settings.brightness <- 7;
    settings.debug <- false;
}

function reportAPIError(func) {
    // Assemble an API response error message
    return ("Mis-formed parameter sent (" + func +")");
}

function debugAPI(context, next) {
    // Display a UI API activity report
    if (settings.debug) {
        server.log("API received a request at " + time() + ": " + context.req.method.toupper() + " @ " + context.req.path.tolower());
        if (context.req.rawbody.len() > 0) server.log("Request body: " + context.req.rawbody.tolower());
    }

    // Invoke the next middleware
    next();
}


// ********** RUNTIME START **********

// ADDED IN 2.4.1
// Load up the crash reporter
#import "~/OneDrive/Programming/Generic/slack.nut"

// IMPORTANT Set firstRun at the top of the listing to reset saved settings
if (firstRun) resetToDefaults();

local savedSettings = server.load();

if (savedSettings.len() != 0) {
    // Table is NOT empty so set 'settings' to the loaded table
    settings = savedSettings;

    // If the debug setting is missing, add it.
    // This may be the case with old settings saves
    if (!("debug" in settings)) {
        settings.debug <- false;
        server.save(settings);
    }
} else {
    // Table is empty, so this must be a first run
    if (settings.debug) server.log("First run - performing setup");
    resetToDefaults();
}

// Register device event triggers
device.on("bclock.get.prefs", sendPrefsToDevice);

// Set up the API
api = Rocky.init();
api.use(debugAPI);

// Set up UI access security: HTTPS only
api.authorize(function(context) {
    // Mandate HTTPS connections
    if (context.getHeader("x-forwarded-proto") != "https") return false;
    return true;
});

api.onUnauthorized(function(context) {
    // Incorrect level of access security
    context.send(401, "Insecure access forbidden");
});

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
        local error = null;

        foreach (setting, value in data) {
            // Check for a mode-set message (value arrives as a bool)
            // eg. { "setmode" : true }
            if (setting == "setmode") {
                if (typeof value != "bool") {
                    error = reportAPIError("setmode");
                    break;
                }

                settings.mode = value;
                device.send("bclock.set.mode", settings.mode);
                if (settings.debug) server.log("UI says change mode to " + (settings.mode ? "24 hour" : "12 hour"));
            }

            // Check for a BST set/unset message (value arrives as a bool)
            // eg. { "setbst" : true }
            if (setting == "setbst") {
                if (typeof value != "bool") {
                    error = reportAPIError("setbst");
                    break;
                }

                settings.bst = value;
                device.send("bclock.set.bst", settings.bst);
                if (settings.debug) server.log("UI says turn auto BST observance " + (settings.bst ? "on" : "off"));
            }

            // Check for a set colon show message (value arrives as a bool)
            // eg. { "setcolon" : true }
            if (setting == "setcolon") {
                if (typeof value != "bool") {
                    error = reportAPIError("setcolon");
                    break;
                }

                settings.colon = value;
                device.send("bclock.set.colon", settings.colon);
                if (settings.debug) server.log("UI says turn colon " + (settings.colon ? "on" : "off"));
            }

            // Check for a set flash message (value arrives as a bool)
            // eg. { "setflash" : true }
            if (setting == "setflash") {
                if (typeof value != "bool") {
                    error = reportAPIError("setflash");
                    break;
                }

                settings.flash = value;
                device.send("bclock.set.flash", settings.flash);
                if (settings.debug) server.log("UI says turn colon flashing " + (settings.flash ? "on" : "off"));
            }

            // Check for set light message (value arrives as a bool)
            // eg. { "setlight" : true }
            if (setting == "setlight") {
                if (typeof value != "bool") {
                    error = reportAPIError("setlight");
                    break;
                }

                settings.on = value;
                device.send("bclock.set.light", settings.on);
                if (settings.debug) server.log("UI says turn display " + (settings.on ? "on" : "off"));
            }

            // Check for a set brightness message (value arrives as a string)
            // eg. { "setbright" : 10 }
            if (setting == "setbright") {
                // Check that the conversion to integer works
                try {
                    value = value.tointeger();
                } catch (err) {
                    error = reportAPIError("setbright");
                    break;
                }

                settings.brightness = value - 1;
                device.send("bclock.set.brightness", settings.brightness);
                if (settings.debug) server.log(format("UI says set display brightness to %i", settings.brightness));
            }

            // UPDATED IN 2.4.0
            // Check for set world time message (value arrives as a table)
            // eg. { "setutc" : { "state" : true, "utcval" : -12 } }
            if (setting == "setutc") {
                if (typeof value != "table") {
                    error = reportAPIError("setutc");
                    break;
                }

                if ("state" in value) {
                    if (typeof value.state != "bool") {
                        error = reportAPIError("setutc.state");
                        break;
                    }

                    settings.utc = value.state;
                }

                if ("offset" in value) {
                    // Check that it can be converted to an integer
                    try {
                        value.offset = value.offset.tointeger();
                    } catch (err) {
                        error = reportAPIError("setutc.offset");
                        break;
                    }

                    settings.offset = value.offset - 12;
                }

                device.send("bclock.set.utc", {"state" : settings.utc, "offset" : settings.offset});
                if (settings.debug) server.log("UI says turn world time mode " + (settings.utc ? "on" : "off") + ", offset: " + settings.offset);
            }

            // FROM 2.4.1
            // Check for set rtc message (value arrives as a bool)
            // eg. { "setrtc" : true }
            if (setting == "setrtc") {
                // Check that the conversion to bool works
                if (typeof value != "bool") {
                    error = reportAPIError("setrtc");
                    break;
                }

                rtc = value;
                device.send("bclock.set.rtc", rtc);
                if (settings.debug) server.log("UI says switch RTC to " + (rtc ? "external" : "internal"));
            }
        }

        if (error != null) {
            context.send(400, error);
            if (settings.debug) server.error(error);
        } else {
            // Save the settings changes
            server.save(settings);
        }
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
                server.save(settings);
                server.log("Clock settings reset");
            }

            if (data.action == "debug") {
                settings.debug = data.debug;
                device.send("bclock.set.debug", settings.debug);
                server.save(settings);
                server.log("Debug mode " + (settings.debug ? "on" : "off"));
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
