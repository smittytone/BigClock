// Big Clock
// Copyright 2014-17, Tony Smith

#require "Rocky.class.nut:2.0.0"

// CONSTANTS

const CHECK_TIME = 43200;
const HTML_STRING = @"<!DOCTYPE html><html lang='en-US'><meta charset='UTF-8'>
<html>
    <head>
        <title>Big Clock</title>
        <link rel='stylesheet' href='https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css'>
        <link href='https://fonts.googleapis.com/css?family=Rubik' rel='stylesheet'>
        <link href='https://fonts.googleapis.com/css?family=Monofett' rel='stylesheet'>
        <link href='https://fonts.googleapis.com/css?family=Questrial' rel='stylesheet'>
        <link rel='apple-touch-icon' href='https://smittytone.github.io/images/ati-bclock.png'>
        <link rel='shortcut icon' href='https://smittytone.github.io/images/ico-bclock.ico' />
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
            .center { margin-left: auto; margin-right: auto; margin-bottom: auto; margin-top: auto; }
            body {background-color: #eeeeee;}
            p {color: #111111; font-family: Questrial, sans-serif}
            h2 {color: #ee1111; font-family: Monofett, sans-serif; font-size: 4em}
            h4 {color: #111111; font-family: Questrial, sans-serif}
            td {color: #111111; font-family: Questrial, sans-serif}
            hr {border-color: #ee1111}
            .error-message {color: #111111}
            h4.showhide {cursor: pointer}
        </style>
    </head>
    <body>
        <div class='container' style='padding: 20px;'>
            <div style='border: 2px solid #ee1111' align='center'>
                <h2 align='center'>Big Clock</h2>
                <h4 align='center' class='clock-status'><i><span>This Big Clock is online</span></i></h4>
                <p align='center'>&nbsp;</p>
                <table width='100%%'>
                    <tr>
                        <td style='width:20%%'>&nbsp;</td>
                        <td style='width:60%%'>
                            <hr>
                            <h4 align='center'>General Settings</h4>
                            <div class='mode-checkbox' style='color:#111111;font-family:Questrial, sans-serif'>
                                <input type='checkbox' name='mode' id='mode' value='mode'> 24-Hour Mode (Switch off for AM/PM)
                            </div>
                            <div class='mode-checkbox' style='color:#111111;font-family:Questrial, sans-serif'>
                                <input type='checkbox' name='bst' id='bst' value='bst'> Apply Daylight Savings Time Automatically
                            </div>
                            <div class='seconds-checkbox' style='color:#111111;font-family:Questrial, sans-serif'>
                                <input type='checkbox' name='seconds' id='seconds' value='seconds'> Show Seconds Indicator
                            </div>
                            <div class='flash-checkbox' style='color:#111111;font-family:Questrial, sans-serif'>
                                <input type='checkbox' name='flash' id='flash' value='seconds'> Flash Seconds Indicator
                            </div>
                            <div class='slider'>
                                <p>&nbsp;<br>Clock Brightness</p>
                                <input type='range' name='brightness' id='brightness' value='15' min='1' max='15'>
                                <table width='100%%'>
                                    <tr>
                                        <td width='50%%' valign='top' align='left'><small>Low</small></td>
                                        <td width='50%%' valign='top' align='right'><small>High</small></td>
                                    </tr>
                                </table>
                                <p class='brightness-status' align='right'>Brightness: <span></span></p>
                            </div>
                            <br>
                            <div class='onoff-button' style='color:#111111;font-family:Rubik, sans-serif;weight:bold' align='center'>
                                <button type='submit' id='onoff' style='height:32px;width:200px'>Turn off Display</button>
                            </div>
                            <hr>
                            <h4 align='center'>World Time Settings</h4>
                            <div class='utc-checkbox' style='color:#111111;font-family:Questrial, sans-serif'>
                                <small><input type='checkbox' name='utc' id='utc' value='utc'> Show World Time</small>
                            </div>
                            <div class='utc-slider'>
                                <input type='range' name='utcs' id='utcs' value='0' min='0' max='24'>
                                <table width='100%%'><tr><td width='30%%' align='left'>-12</td><td width='40%%' align='center'>0</td><td width='30%%' align='right'>+12</td></tr></table>
                                <p class='utc-status' align='right'>&nbsp;<br>Offset from local time: <span></span> hours</p>
                            </div>
                            <hr>
                            <div class='advancedsettings'>
                                <h4 class='showhide' align='center'>Click for Advanced Settings</h4>
                                <div class='advanced' align='center'>
                                    <br>
                                    <div class='reset-button' style='color:#111111;font-family:Rubik;weight:bold, sans-serif' align='center'>
                                        <button type='submit' id='reset' style='height:28px;width:200px'>Reset Big Clock</button>
                                    </div>
                                    <br>
                                    <div class='debug-checkbox' style='font-family:Questrial, sans-serif'>
                                        <input type='checkbox' name='debug' id='debug' value='debug'> Debug Mode
                                    </div>
                                </div>
                            </div>
                            <hr>
                        </td>
                        <td style='width:20%%'>&nbsp;</td>
                    </tr>
                </table>
                <p class='text-center'><small>Big Clock &copy; 2014-17 Tony Smith</small><br>&nbsp;<br><a href='https://github.com/smittytone/BigClock' target='_blank'><img src='https://smittytone.github.io/images/rassilonblack.png' width='32' height='32'></a></p>
            </div>
        </div>

        <script src='https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js'></script>
        <script>
            $('.advanced').hide();

            // Variables
            var agenturl = '%s';
            var displayon = true;
            var stateflag = false;

            // Get initial readings
            getState(updateReadout);

            // Set UI click actions: Checkboxes
            $('#mode').click(setmode);
            $('#bst').click(setbst);
            $('#seconds').click(setcolon);
            $('#flash').click(setflash);
            $('#utc').click(setutc);
            $('#debug').click(setdebug);

            // Buttons
            $('.reset-button button').click(reset);
            $('.onoff-button button').click(setlight);

            // Slider
            var slider = document.getElementById('brightness');
            slider.addEventListener('mouseup', updateSlider);
            slider.addEventListener('touchend', updateSlider);
            $('.brightness-status span').text(slider.value);
            $('#brightness').css('background', '#eeeeee');

            // World Time Slider
            slider = document.getElementById('utcs');
            slider.addEventListener('mouseup', updateutc);
            slider.addEventListener('touchend', updateutc);
            $('.utc-status span').text(slider.value);
            $('#utcs').css('background', '#eeeeee');

            $('.showhide').click(function(){
                $('.advanced').toggle();
            });

            // Functions
            function updateSlider() {
                $('.brightness-status span').text($('#brightness').val());
                setbright();
            }

            function updateutc() {
                var u = $('#utcs').val();
                $('.utc-status span').text(u - 12);
                if (document.getElementById('utc').checked == true) {
                    setutc();
                }
            }

            function updateReadout(data) {
                var s = data.split('.');
                document.getElementById('mode').checked = (s[0] == '1') ? true : false;
                document.getElementById('bst').checked = (s[1] == '1') ? true : false;
                document.getElementById('seconds').checked = (s[3] == '1') ? true : false;
                document.getElementById('flash').checked = (s[2] == '1') ? true : false;
                document.getElementById('utc').checked = (s[5] == '1') ? true : false;
                document.getElementById('debug').checked = (s[9] == '1') ? true : false;

                var b = parseInt(s[6]);
                $('.utc-status span').text(b - 12);
                $('#utcs').val(b);

                $('.onoff-button button').text((s[7] == '1') ? 'Turn off Display' : 'Turn on Display');
                displayon = (s[7] == '1');

                b = parseInt(s[4]);
                $('.brightness-status span').text(b);
                $('#brightness').val(b);

                updateState(s[8]);

                // Auto-reload data in 120 seconds
                if (!stateflag) {
                    checkState();
                    stateflag = true;
                }
            }

            function updateState(s) {
                if (s == 'd') {
                    $('.clock-status span').text('This Big Clock is offline');
                } else {
                    $('.clock-status span').text('This Big Clock is online');
                }
            }

            function getState(callback) {
                // Request the current data
                $.ajax({
                    url : agenturl + '/settings',
                    type: 'GET',
                    success : function(response) {
                        if (callback) {
                            callback(response);
                        }
                    },
                    error : function(xhr, textStatus, error) {
                        if (error) {
                            $('.clock-status span').text(error);
                        }
                    }
                });
            }

            function checkState() {
                $.ajax({
                    url : agenturl + '/state',
                    type: 'GET',
                    success : function(response) {
                        updateState(response)
                        setTimeout(checkState, 120000);
                    },
                    error : function(xhr, textStatus, error) {
                        if (error) {
                            $('.clock-status span').text(error);
                        }
                    }
                });
            }

            function setmode() {
                var d = { 'setmode' : ((document.getElementById('mode').checked == true) ? '1' : '0') };
                sendstate(d);
            }

            function setbst() {
                var d = { 'setbst' : ((document.getElementById('bst').checked == true) ? '1' : '0') };
                sendstate(d);
            }

            function setcolon() {
                var d = { 'setcolon' : ((document.getElementById('seconds').checked == true) ? '1' : '0') };
                sendstate(d);
            }

            function setflash() {
                var d = { 'setflash' : ((document.getElementById('flash').checked == true) ? '1' : '0') };
                sendstate(d);
            }

            function setbright() {
                var d = { 'setbright' : ($('#brightness').val()) };
                sendstate(d);
            }

            function setlight() {
                displayon = !displayon;
                $('.onoff-button button').text(displayon ? 'Turn off Display' : 'Turn on Display');
                var s = (displayon ? '1' : '0');
                var d = { 'setlight' :  s };
                sendstate(d);
            }

            function setutc() {
                var d = { 'setutc' : ((document.getElementById('utc').checked == true) ? '1' : '0'), 'utcval' : $('#utcs').val() };
                sendstate(d);
            }

            function sendstate(data) {
                $.ajax({
                    url : agenturl + '/settings',
                    type: 'POST',
                    data: JSON.stringify(data),
                    success: function() {
                        getState(updateReadout);
                    },
                    error : function(xhr, textStatus, error) {
                        if (error) {
                            $('.clock-status span').text(error);
                        }
                    }
                });
            }

            function reset() {
                // Trigger a settings reset
                $.ajax({
                    url : agenturl + '/action',
                    type: 'POST',
                    data: JSON.stringify({ 'action' : 'reset' }),
                    success : function(response) {
                        getState(updateReadout);
                    }
                });
            }

            function setdebug() {
                // Tell the device to enter or leave debug mode
                $.ajax({
                    url : agenturl + '/action',
                    type: 'POST',
                    data: JSON.stringify({ 'action' : 'debug', 'value' : ((document.getElementById('debug').checked == true) ? '1' : '0') }),
                    error : function(xhr, textStatus, error) {
                        if (error) {
                            $('.clock-status span').text(error);
                        }
                    }
                });
            }

            function reboot() {
                // Trigger a device restart
                $.ajax({
                    url : agenturl + '/action',
                    type: 'POST',
                    data: JSON.stringify({ 'action' : 'reboot' }),
                    success : function(response) {
                        getState(updateReadout);
                    },
                    error : function(xhr, textStatus, error) {
                        if (error) {
                            $('.clock-status span').text(error);
                        }
                    }
                });
            }
        </script>
    </body>
</html>";

// 'GLOBALS'

local settings = null;
local api = null;
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

// GET call to /state - return 'c' or 'd' for 'connected' or 'disconnected'
api.get("/state", function(context) {
    local a = (device.isconnected() ? "c" : "d");
    context.send(200, a);
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
