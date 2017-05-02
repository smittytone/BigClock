// Big Clock
// Copyright 2014-17, Tony Smith

#require "utilities.nut:1.0.0"

#import "ds3234rtc.class.nut"

#import "ht16k33segmentbig.class.nut"

// Set the disconnection behaviour
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);

// CONSTANTS

// These values are not user definable, so set as constants to save
// calculation time and memory:
//   1. TICK_DURATION = fraction of a second that each tick takes
//   2. TICK_TOTAL = 2.0 / TICK_DURATION
//   3. HALF_TICK_TOTAL = 1.0 / TICK_DURATION
//   4. DIS_TIMEOUT = disconnection timeout

const TICK_DURATION = 0.5;
const TICK_TOTAL = 4;
const HALF_TICK_TOTAL = 2;
const DIS_TIMEOUT = 60;
const SYNC_TIME = 15;

// GLOBALS

local rtc = null;
local clock = null;
local syncTimer = null;
local tickTimer = null;
local settings = null;

local seconds = 0;
local minutes = 0;
local hour = 0;
local dayw = 0;
local day = 0;
local month = 0;
local year = 0;

local disTime = -1;
local disMessage = "";
local tickCount = 0;
local tickFlag = true;
local debug = true;
local disFlag = false;

// TIME FUNCTIONS

function getTime() {
    // This is the main clock loop
    // Queue the function to run again in TICK_DURATION seconds
    tickTimer = imp.wakeup(TICK_DURATION, getTime);

    // Get the current time from the RTC and store parameters
    local time = rtc.getDateAndTime();
    seconds = time[0];
    minutes = time[1];
    hour = time[2];
    dayw = time[3];
    day = time[4] - 1;
    month = time[5];
    year = time[6];

    // Adjust the hour for BST and midnight rollover
    if (settings.bst && utilities.bstCheck()) hour++;
    if (hour > 23) hour = 0;

    // Update the tick counter
    tickCount++;
    tickFlag = false;
    if (tickCount == TICK_TOTAL) tickCount = 0;
    if (tickCount < HALF_TICK_TOTAL) tickFlag = true;

    // Present the current time
    displayTime();
}

function displayTime() {
    if (!settings.on) {
        clock.clearDisplay();
        return;
    }

    clock.clearBuffer();

    // Set the defaults to the 24-hour reading -
    // We will alter these values if the clock
    // is set to a 12-hour am/pm display
    // Note 'hour' already adjusted for BST
    local colonValue = 0x00;
    local a = hour;
    local b = 0;

    // Hours
    if (settings.mode) {
        // 24-hour clock
        if (a < 10) {
            clock.writeNumber(1, a);
        } else if (a > 9 && a < 20) {
            clock.writeNumber(0, 1)
            clock.writeNumber(1, a - 10);
        } else if (a > 19) {
            clock.writeNumber(0, 2);
            clock.writeNumber(1, a - 20);
        }
    } else {
        // 12-hour clock
        if (a == 12 || a == 0 ) {
            clock.writeNumber(0, 1);
            clock.writeNumber(1, 2);
        } else if (a < 10) {
            clock.writeNumber(1, a);
        } else if (a == 10 || a == 11) {
            clock.writeNumber(0, 1);
            clock.writeNumber(1, a - 10);
        } else if (a > 12 && a < 22) {
            clock.writeNumber(1, a - 12);
        } else if (a == 22 || a == 23) {
            clock.writeNumber(0, 1);
            clock.writeNumber(1, a - 22);
        }

        // Set AM/PM
        colonValue = (a < 12) ? 0x08 : 0x04;
    }

    // Minutes
    if (minutes > 9) {
        a = (minutes / 10).tointeger();
        clock.writeNumber(4, (minutes - (10 * a)));
        clock.writeNumber(3, a);
    } else {
        clock.writeNumber(4, minutes);
        clock.writeNumber(3, 0);
    }

    // Is the clock disconnected? If so, flag the fact
    if (disFlag) colonValue = colonValue | 0x10;

    // Check whether the colon should appear
    if (settings.colon) {
        // Colon is set to be displayed. Will it flash?
        if (settings.flash) {
            if (tickFlag) colonValue = colonValue | 0x02;
        } else {
            colonValue = colonValue | 0x02;
        }
    }

    clock.setColon(colonValue).updateDisplay();
}

function syncText() {
    // Display the word 'SYNC' on the LED
    if (!settings.on) return;
    local letters = [0x6D, 0x6E, 0x00, 0x37, 0x39];
    foreach (index, character in letters) {
        if (index != 2) clock.writeGlyph(index, character);
    }

    clock.updateDisplay();
}

// PREFERENCES FUNCTIONS

function setInitialTime(firstTime) {
    // Set the RTC using the server time
    if (firstTime) {
        if (debug) server.log("Setting RTC with initial time via server");
        local now = date();
        rtc.setDateAndTime(now.day + 1, now.month + 1, now.year, now.wday + 1, now.hour, now.min, now.sec);
    }
}

function setPrefs(prefs) {
    // Cancel the 'Sync' display timer if it has yet to fire
    if (debug) server.log("Received preferences from agent");
    if (syncTimer) imp.cancelwakeup(syncTimer);
    syncTimer = null;

    // Parse the set-up data table provided by the agent
    settings.mode = prefs.mode;
    settings.bst = prefs.bst;
    settings.flash = prefs.flash;
    settings.colon = prefs.colon;
    settings.utc = prefs.utc;
    settings.offset = 12 - prefs.offset;

    // Clear the display
    if (prefs.on != settings.on) {
        setLight(prefs.on);
        settings.on = prefs.on;
    }

    // Set the brightness
    if (prefs.brightness != settings.brightness) {
        settings.brightness = prefs.brightness;

        // Only set the brightness now if the display is on
        if (prefs.on) clock.setBrightness(settings.brightness);
    }

    // Only call getTime() if we have come here *before*
    // the main clock loop, which sets tickTimer, has started
    if (tickTimer == null) getTime();
}

function setBST(value) {
    // This function is called when the app sets or unsets BST
    if (debug) server.log("Setting BST auto-monitoring " + ((value == 1) ? "on" : "off"));
    settings.bst = value;
}

function setMode(value) {
    // This function is called when 12/24 modes are switched by app
    if (debug) server.log("Setting 24-hour mode " + ((value == 24) ? "on" : "off"));
    settings.mode = value;
}

function setUTC(string) {
    // This function is called when the app sets or unsets UTC
    if (debug) server.log("Setting UTC " + ((string == "N") ? "on" : "off"));
    if (string == "N") {
        settings.utc = false;
    } else {
        settings.utc = true;
        settings.offset = 12 - string.tointeger();
    }
}

function setBright(brightness) {
    // This function is called when the app changes the clock's brightness
    if (debug) server.log("Setting brightness " + brightness);
    if (brightness != settings.brightness) {
        clock.setBrightness(brightness);
        settings.brightness = brightness;
    }
}

function setFlash(value) {
    // This function is called when the app sets or unsets the colon flash
    if (debug) server.log("Setting colon flash " + ((value == 1) ? "on" : "off"));
    settings.flash = value;
}

function setColon(value) {
    // This function is called when the app sets or unsets the colon flash
    if (debug) server.log("Setting colon state " + ((value == 1) ? "on" : "off"));
    settings.colon = value == 1;
}

function setLight(value) {
    if (debug) server.log("Setting light " + ((value == 1) ? "on" : "off"));
    settings.on = value;

    if (value) {
        clock.powerUp();
    } else {
        clock.powerDown();
    }
}

function setDebug(ds) {
    debug = ds;
    server.log("BigClock debug " + ((debug) ? "enabled" : "disabled"));
}

// OFFLINE OPERATION FUNCTIONS

function disHandler(reason) {
    // Called if the server connection is broken or re-established
    // Sets 'disFlag' true if there is no connection
    if (reason != SERVER_CONNECTED) {
        // Server is not connected
        disFlag = true;

        if (disTime == -1) {
            disTime = time();
            local now = date();
            disMessage = "Went offline at " + now.hour + ":" + now.min + ":" + now.sec + ". Reason: " + reason;
        }

        imp.wakeup(DIS_TIMEOUT, reconnect);
    } else {
        // Server is connected
        if (debug) {
            server.log(disMessage);
            server.log("Back online after " + ((time() - disTime) / 1000) + " seconds");
        }

        disTime = -1;
        disFlag = false;
        disMessage = null;

        // Re-acquire the prefs in case they were changed when the clock went offline
        agent.send("bclock.get.prefs", true);
    }
}

function reconnect() {
    if (server.isconnected()) {
        disHandler(SERVER_CONNECTED);
    } else {
        server.connect(disHandler, 30);
    }
}

// MISC FUNCTIONS

function resetSettings() {
    settings = {};
    settings.on <- true;
    settings.mode <- true;
    settings.bst <- true;   // NOTE This now indicates whether we adapt to BST (true) or stick to GMT (false)
    settings.colon <- true;
    settings.flash <- true;
    settings.brightness <- 15;
    settings.utc <- false;
    settings.offset <- 12;
}

// START

// Register the disconnection handler
server.onunexpecteddisconnect(disHandler);

// Set up the RTC
rtc = DS3234RTC(hardware.spi257, hardware.pin1);
rtc.init();

// Set up the display
hardware.i2c89.configure(CLOCK_SPEED_50_KHZ);
clock = HT16K33SegmentBig(hardware.i2c89, 0x70, debug);
clock.init();

// Show the ‘sync’ message then give the text no more than
// SYNC_TIME seconds to appear. If the prefs data comes from the
// agent before then, the text will automatically be cleared
resetSettings();
syncText();
syncTimer = imp.wakeup(SYNC_TIME, getTime);

// Set up Agent notification response triggers
agent.on("bclock.set.prefs", setPrefs);
agent.on("bclock.set.bst", setBST);
agent.on("bclock.set.mode", setMode);
agent.on("bclock.set.utc", setUTC);
agent.on("bclock.set.brightness", setBright);
agent.on("bclock.set.flash", setFlash);
agent.on("bclock.set.colon", setColon);
agent.on("bclock.set.light", setLight);
agent.on("bclock.first.time", setInitialTime);
agent.on("bclock.set.debug", setDebug);

// Get preferences from server
agent.send("bclock.get.prefs", true);
