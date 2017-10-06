// Class-specific constants
const DS3234_CLASS_LOW_            = 0;
const DS3234_CLASS_HIGH_           = 1;
const DS3234_CLASS_CTRL_REG_WRITE  = "\x8E";
const DS3234_CLASS_RAM_START_READ  = "\x00";
const DS3234_CLASS_RAM_START_WRITE = "\x80";

class DS3234RTC {

	// Squirrel class for the Dallas/Maxim DS3234 real time clock used on the
	// SparkFun DeadOn breakout board https://www.sparkfun.com/products/10160
	// Bus: SPI
	// Written by Tony Smith, copyright 2014-17

	static VERSION = "1.0.4";

	_spi = null;
	_cs = null;
	_debug = false;

	constructor(spiBus = null, csPin = null, debug = false) {
		if (spiBus == null) {
			throw "The DS3234RTC class requires a non-null imp SPI bus";
		} else {
			_spi = spiBus;
		}

		if (csPin == null) {
			throw "The DS3234RTC class requires a non-null imp GPIO pin for CS";
		} else {
			_cs = csPin;
		}

		_debug = debug;
	}

	function init() {
		// Configure the SPI bus for SPI Mode 3
		_spi.configure((CLOCK_IDLE_DS3234_CLASS_LOW_ | CLOCK_2ND_EDGE), 3000);

		// Set the Chip Select pin DS3234_CLASS_HIGH_
		_cs.configure(DIGITAL_OUT);
		_cs.write(DS3234_CLASS_HIGH_);

		// Pause 20ms
		imp.sleep(0.02);

		// Initialise the DS3234 with basic settings, ie. zero Control Register
		_cs.write(DS3234_CLASS_LOW_);
		_spi.write(DS3234_CLASS_CTRL_REG_WRITE);
		_spi.write("\x00");
		_cs.write(DS3234_CLASS_HIGH_);
	}

	function setDateAndTime(date, month, year, wday, hour, min, sec) {
		// Sets the RTC's initial values - all parameters are integers
		local dateData = [sec, min, hour, wday, date, month, (year - 2000)];

		for (local i = 0 ; i < 7 ; ++i) {
			dateData[i] = _integerToBCD(dateData[i]);
			if (i == 2) dateData[i] = dateData[i] & 0x3F;

			// DS3234 memory is written at 0x80 and up
			// 0x80 = seconds (0-59)
			// 0x81 = minutes (0-59)
			// 0x82 = hour (0-23)
			// 0x83 = day of week (1-7)
			// 0x84 = day of month (1-31)
			// 0x85 = month (1-12)
			// 0x86 = year (00-99)

			_cs.write(DS3234_CLASS_LOW_);
			local r = blob(1);
			r.writen((i + 0x80), 'b');
			_spi.write(r);
			r = blob(1);
			r.writen(dateData[i], 'b');
			_spi.write(r);
			_cs.write(DS3234_CLASS_HIGH_);
		}

		if (_debug) server.log("RTC set");
	}

	function getDateAndTime() {
		local b = null;
		local dateData = [0, 0, 0, 0, 0, 0, 0];

		for (local i = 0 ; i < 7 ; ++i) {
			// DS3234 memory is read at 0x00 and up
			// 0x00 = seconds (0-59)
			// 0x01 = minutes (0-59)
			// 0x02 = hour (0-23)
			// 0x03 = day of week (1-7)
			// 0x04 = day of month (1-31)
			// 0x05 = month (1-12)
			// 0x06 = year (00-99)

			_cs.write(DS3234_CLASS_LOW_);
			local r = blob(1);
			r.writen(i, 'b');
			_spi.write(r);
			b = _spi.readblob(1);
			dateData[i] = _BCDtoInteger(b[0]);
			_cs.write(DS3234_CLASS_HIGH_);
		}

        if (_debug) {
            local s = ""
            foreach (item in dateData) {
                s = s + item.tostring() + ":";
            }

            s = s.slice(0, s.len() - 1);
            server.log("RTC read: " + s);
        }

		return dateData;
	}

	// ********** PRIVATE FUNCTIONS - DO NOT CALL **********

	function _integerToBCD(value) {
		// DS3234 stores data in Binary Coded Decimal (BCD)
		// Writes must be converted from integer to BCD
		local a = value / 10;
		local b = value - (a * 10);
		return (a << 4) + b;
	}

	function _BCDtoInteger(value) {
		// DS3234 stores data in Binary Coded Decimal (BCD)
		// Reads must be converted to integer from BCD
		local a = (value & 0xF0) >> 4;
		local b = value & 0x0F;
		return (a * 10) + b;
	}
}
