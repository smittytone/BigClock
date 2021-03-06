// Big Clock
// Copyright 2014-19, Tony Smith

// ********** IMPORTS **********
// If you are NOT using Squinter or a similar tool, replace the following #import statement(s)
// with the contents of the named file(s):
#import "../generic-squirrel/utilities.nut"                             // Source code: https://github.com/smittytone/generic-squirrel
#import "../generic-squirrel/disconnect.nut"                            // Source code: https://github.com/smittytone/generic-squirrel
#import "../generic-squirrel/crashreporter.nut"                         // Source code: https://github.com/smittytone/generic-squirrel
#import "../DS3234/ds3234rtc.class.nut"                                 // Source code: https://github.com/smittytone/BigClock
#import "../HT16K33SegmentBig-Squirrel/ht16k33segmentbig.class.nut"     // Source code: https://github.com/smittytone/HT16K33SegmentBig-Squirrel


// ********** CONSTANTS **********
// These values are not user definable, so set as constants to save
// calculation time and memory:
//   1. TICK_DURATION = fraction of a second that each tick takes
//   2. TICK_TOTAL = 2.0 / TICK_DURATION
//   3. HALF_TICK_TOTAL = 1.0 / TICK_DURATION
//   4. DISCONNECT_TIMEOUT = disconnection timeout
const TICK_DURATION = 0.5;
const TICK_TOTAL = 4;
const HALF_TICK_TOTAL = 2;
const DISCONNECT_TIMEOUT = 60;
const RECONNECT_TIMEOUT = 30;
const SYNC_TIME = 15;

// ********** GLOBAL VARIABLES **********
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

local tickCount = 0;
local isDisconnected = false;
local isConnecting = false;
local tickFlag = true;


// ********** TIME FUNCTIONS **********
function getTime() {
    // This is the main clock loop
    // Queue the function to run again in TICK_DURATION seconds
    tickTimer = imp.wakeup(TICK_DURATION, getTime);

    // Get the current time from the RTC and store parameters
    setTime();

    // Adjust the hour for BST and midnight rollover
    if (settings.bst && utilities.bstCheck()) hour++;

    // Update for world time
    if (settings.utc) {
        hour = hour + settings.utcoffset;
    }

    if (hour > 23) hour = 0;
    if (hour < 0) hour = hour + 24;

    // Update the tick counter
    tickCount++;
    tickFlag = false;
    if (tickCount == TICK_TOTAL) tickCount = 0;
    if (tickCount < HALF_TICK_TOTAL) tickFlag = true;

    // Present the current time
    displayTime();
}

function setTime() {
    // Get the current time from the RTC and store parameters
    // FROM 2.4.1: switchable RTC (external or internal)
    if (settings.rtc) {
        local time = rtc.getDateAndTime();
        seconds = time[0];
        minutes = time[1];
        hour = time[2];
        dayw = time[3];
        day = time[4] - 1;
        month = time[5];
        year = time[6];
    } else {
        local time = date();
        seconds = time.sec;
        minutes = time.min;
        hour = time.hour;
        dayw = time.wday;
        day = time.day;
        month = time.month;
        year = time.year;
    }
}

function displayTime() {
    if (!settings.on) return;

    // Clear the display
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
    if (isConnecting) {
      // Flash the disconnection indicator if we're
      // disconnected and connecting
      colonValue = colonValue + (!tickFlag ? 0x10 : 0);
    } else if (isDisconnected) {
      // Set the disconnection indicator to solid if we're
      // disconnected but not connecting
      colonValue = colonValue + 0x10;
    }

    // Check whether the colon should appear
    if (settings.colon && (!settings.flash || (settings.flash && tickFlag))) {
        // Colon is set to be displayed. Will it flash?
        colonValue = colonValue + 0x02;
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

// ********** PREFERENCES FUNCTIONS **********
function setInitialTime(ignored) {
    // Set the RTC using the server time
    if (settings.debug) server.log("Setting RTC with initial time via server");
    local now = date();
    rtc.setDateAndTime(now.day + 1, now.month + 1, now.year, now.wday + 1, now.hour, now.min, now.sec);
}

function setPrefs(prefs) {
    // Cancel the 'Sync' display timer if it has yet to fire
    if (settings.debug) server.log("Received preferences from agent");
    if (syncTimer) imp.cancelwakeup(syncTimer);
    syncTimer = null;

    // Parse the set-up data table provided by the agent
    settings.mode = prefs.mode;
    settings.bst = prefs.bst;
    settings.flash = prefs.flash;
    settings.colon = prefs.colon;
    settings.utc = prefs.utc;
    settings.utcoffset = prefs.offset;
    settings.debug = prefs.debug;

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
    if (settings.debug) server.log("Setting BST auto-monitoring " + (value ? "on" : "off"));
    settings.bst = value;
}

function setMode(value) {
    // This function is called when 12/24 modes are switched by app
    if (settings.debug) server.log("Setting 24-hour mode " + (value ? "on" : "off"));
    settings.mode = value;
}

function setUTC(value) {
    // This function is called when the app sets or unsets UTC
    if ("offset" in value) settings.utcoffset = value.offset;
    if ("state" in value) settings.utc = value.state;
    if (settings.debug) server.log("Setting UTC " + (value.state ? "on" : "off") + " with offset " + value.offset);
}

function setBright(brightness) {
    // This function is called when the app changes the clock's brightness
    if (settings.debug) server.log("Setting brightness " + brightness);
    if (brightness != settings.brightness) {
        clock.setBrightness(brightness);
        settings.brightness = brightness;
    }
}

function setFlash(value) {
    // This function is called when the app sets or unsets the colon flash
    if (settings.debug) server.log("Setting colon flash " + (value ? "on" : "off"));
    settings.flash = value;
}

function setColon(value) {
    // This function is called when the app sets or unsets the colon flash
    if (settings.debug) server.log("Setting colon state " + (value ? "on" : "off"));
    settings.colon = value;
}

function setLight(value) {
    if (settings.debug) server.log("Setting light " + (value ? "on" : "off"));
    settings.on = value;

    if (value) {
        clock.powerUp();
    } else {
        clock.powerDown();
    }
}

function setDebug(state) {
    settings.debug = state;
    // clock.setDebug(state);
    server.log("BigClock debug " + (settings.debug ? "enabled" : "disabled"));
}

function setRtc(state) {
    settings.rtc = state;
    // clock.setDebug(state);
    server.log("BigClock RTC: " + (settings.debug ? "external" : "internal"));
}


// ********** OFFLINE OPERATION FUNCTIONS **********
function discoHandler(event) {
    // Called if the server connection is broken or re-established
    if ("message" in event && settings.debug) server.log("Disconnection Manager: " + event.message);

    if ("type" in event) {
        if (event.type == "disconnected") {
            isDisconnected = true;
            isConnecting = false;
        } else if (event.type == "connecting") {
            isConnecting = true;
        } else if (event.type == "connected") {
            isDisconnected = false;
            isConnecting = false;

            // Re-acquire the prefs in case they were changed when the clock went offline
            agent.send("bclock.get.prefs", true);
        }
    }
}


// ********** MISC FUNCTIONS **********
function resetSettings() {
    settings = {};
    settings.on <- true;
    settings.mode <- true;
    settings.bst <- true;   // NOTE This now indicates whether we adapt to BST (true) or stick to GMT (false)
    settings.colon <- true;
    settings.flash <- true;
    settings.brightness <- 7;
    settings.utc <- false;
    settings.utcoffset <- 12;
    settings.debug <- false;
    settings.rtc <- false;
}


// ********** RUNTIME START **********

// ADDED IN 2.4.1
// Set up the crash reporter
crashReporter.init();

// Load in generic boot message code
// If you are NOT using Squinter or a similar tool, replace the following #import statement(s)
// with the contents of the named file(s):
#import "../generic-squirrel/bootmessage.nut"        // Source code: https://github.com/smittytone/generic-squirrel

// Set up the disconnection manager
disconnectionManager.eventCallback = discoHandler;
disconnectionManager.reconnectTimeout = RECONNECT_TIMEOUT;
disconnectionManager.reconnectDelay = DISCONNECT_TIMEOUT;
disconnectionManager.start();

// Set up the RTC
rtc = DS3234RTC(hardware.spi257, hardware.pin1);
rtc.init();

// Set up the display
hardware.i2c89.configure(CLOCK_SPEED_10_KHZ);
clock = HT16K33SegmentBig(hardware.i2c89, 0x70);
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
// FROM 2.4.1: add RTC switch
agent.on("bclock.set.rst", setRtc);

// Get preferences from server
// FROM 2.4.0: comment out as this is handled by the disconnect manager
// agent.send("bclock.get.prefs", true);
