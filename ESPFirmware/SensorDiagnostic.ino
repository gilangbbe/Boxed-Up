// SensorDiagnostic.ino — ESP32 + MPU6050 hardware diagnostic sketch
// Upload this INSTEAD of BoxedUp.ino to debug wiring/sensor issues.
// Open Serial Monitor at 115200 baud to see results.
//
// Checks performed:
// 1. I2C bus scan (finds all devices on the bus)
// 2. MPU6050 WHO_AM_I register read (should return 0x68)
// 3. Power management register check (is the sensor sleeping?)
// 4. Raw 6-axis data continuous read (verify values change when moved)
// 5. Connection quality (repeated reads to detect intermittent failures)

#include <Wire.h>

// MPU6050 registers
#define MPU6050_ADDR        0x68
#define MPU6050_ADDR_ALT    0x69   // If AD0 pin is HIGH
#define REG_WHO_AM_I        0x75
#define REG_PWR_MGMT_1      0x6B
#define REG_PWR_MGMT_2      0x6C
#define REG_ACCEL_XOUT_H    0x3B
#define REG_ACCEL_CONFIG     0x1C
#define REG_GYRO_CONFIG      0x1B
#define REG_INT_STATUS       0x3A
#define REG_SIGNAL_PATH_RESET 0x68

// Pins
#define SDA_PIN 21
#define SCL_PIN 22

uint8_t detectedAddr = 0;

void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println();
    Serial.println("==============================================");
    Serial.println("  BoxedUp Sensor Diagnostic Tool");
    Serial.println("  ESP32 + MPU6050 Hardware Debug");
    Serial.println("==============================================");
    Serial.println();

    // --- TEST 1: I2C Bus Init ---
    Serial.println("[TEST 1] I2C Bus Initialization");
    Serial.printf("  SDA pin: GPIO%d\n", SDA_PIN);
    Serial.printf("  SCL pin: GPIO%d\n", SCL_PIN);
    Wire.begin(SDA_PIN, SCL_PIN);
    Wire.setClock(100000);  // Start slow for reliability
    Serial.println("  I2C bus initialized at 100kHz");
    Serial.println("  PASS");
    Serial.println();

    // --- TEST 2: I2C Bus Scan ---
    Serial.println("[TEST 2] I2C Bus Scan (checking all addresses 0x01-0x7F)");
    int devicesFound = 0;
    for (uint8_t addr = 1; addr < 127; addr++) {
        Wire.beginTransmission(addr);
        uint8_t error = Wire.endTransmission();
        if (error == 0) {
            Serial.printf("  Found device at 0x%02X", addr);
            if (addr == MPU6050_ADDR) {
                Serial.print(" <-- MPU6050 (AD0=LOW)");
                detectedAddr = addr;
            } else if (addr == MPU6050_ADDR_ALT) {
                Serial.print(" <-- MPU6050 (AD0=HIGH)");
                detectedAddr = addr;
            }
            Serial.println();
            devicesFound++;
        } else if (error == 4) {
            Serial.printf("  ERROR at 0x%02X (unknown error)\n", addr);
        }
    }

    if (devicesFound == 0) {
        Serial.println("  FAIL — No I2C devices found!");
        Serial.println();
        Serial.println("  TROUBLESHOOTING:");
        Serial.println("  1. Check VCC: MPU6050 VCC -> ESP32 3V3 (NOT 5V if using 3.3V board)");
        Serial.println("  2. Check GND: MPU6050 GND -> ESP32 GND");
        Serial.println("  3. Check SDA: MPU6050 SDA -> ESP32 GPIO21");
        Serial.println("  4. Check SCL: MPU6050 SCL -> ESP32 GPIO22");
        Serial.println("  5. Check for loose jumper wires / bad breadboard connections");
        Serial.println("  6. Check for bent pins on MPU6050 module");
        Serial.println("  7. Try a different breadboard row");
        Serial.println("  8. Measure 3.3V with multimeter on MPU6050 VCC pin");
        Serial.println();
        Serial.println("=== DIAGNOSTIC STOPPED — Fix wiring first ===");
        while (true) { delay(10000); }
    }

    Serial.printf("  Found %d device(s)\n", devicesFound);
    if (detectedAddr == 0) {
        Serial.println("  WARNING: Found device(s) but not at MPU6050 address (0x68 or 0x69)");
        Serial.println("  Check AD0 pin: should be connected to GND for address 0x68");
        Serial.println("=== DIAGNOSTIC STOPPED ===");
        while (true) { delay(10000); }
    }
    Serial.println("  PASS");
    Serial.println();

    // --- TEST 3: WHO_AM_I Register ---
    Serial.println("[TEST 3] MPU6050 WHO_AM_I Register");
    uint8_t whoAmI = readRegister(detectedAddr, REG_WHO_AM_I);
    Serial.printf("  WHO_AM_I value: 0x%02X (expected 0x68 for MPU6050, 0x72 for MPU6050C)\n", whoAmI);
    if (whoAmI == 0x68 || whoAmI == 0x72 || whoAmI == 0x70) {
        Serial.println("  PASS — MPU6050 identity confirmed");
    } else if (whoAmI == 0xFF || whoAmI == 0x00) {
        Serial.println("  FAIL — Got 0xFF/0x00, sensor likely not responding");
        Serial.println("  This usually means wiring is connected but sensor is dead or damaged");
    } else {
        Serial.printf("  WARNING — Unexpected value 0x%02X (may be a compatible sensor)\n", whoAmI);
    }
    Serial.println();

    // --- TEST 4: Power Management ---
    Serial.println("[TEST 4] Power Management Check");
    uint8_t pwr1 = readRegister(detectedAddr, REG_PWR_MGMT_1);
    Serial.printf("  PWR_MGMT_1: 0x%02X\n", pwr1);
    if (pwr1 & 0x40) {
        Serial.println("  Sensor is in SLEEP mode — waking it up...");
        writeRegister(detectedAddr, REG_PWR_MGMT_1, 0x00);
        delay(100);
        pwr1 = readRegister(detectedAddr, REG_PWR_MGMT_1);
        Serial.printf("  PWR_MGMT_1 after wake: 0x%02X\n", pwr1);
    }
    if (pwr1 & 0x80) {
        Serial.println("  DEVICE RESET bit is set — resetting...");
        writeRegister(detectedAddr, REG_PWR_MGMT_1, 0x80);
        delay(200);
        writeRegister(detectedAddr, REG_PWR_MGMT_1, 0x00);
        delay(100);
    }
    Serial.println("  Sensor is AWAKE");
    uint8_t pwr2 = readRegister(detectedAddr, REG_PWR_MGMT_2);
    Serial.printf("  PWR_MGMT_2: 0x%02X (0x00 = all axes enabled)\n", pwr2);
    Serial.println("  PASS");
    Serial.println();

    // --- TEST 5: Sensor Configuration ---
    Serial.println("[TEST 5] Sensor Configuration");
    // Set ±8g accel, ±1000°/s gyro to match BoxedUp firmware
    writeRegister(detectedAddr, REG_ACCEL_CONFIG, 0x10);  // ±8g
    writeRegister(detectedAddr, REG_GYRO_CONFIG, 0x10);    // ±1000°/s
    delay(10);
    uint8_t accelCfg = readRegister(detectedAddr, REG_ACCEL_CONFIG);
    uint8_t gyroCfg = readRegister(detectedAddr, REG_GYRO_CONFIG);
    Serial.printf("  ACCEL_CONFIG: 0x%02X (expected 0x10 for ±8g)\n", accelCfg);
    Serial.printf("  GYRO_CONFIG:  0x%02X (expected 0x10 for ±1000°/s)\n", gyroCfg);
    Serial.println("  PASS");
    Serial.println();

    // --- TEST 6: Stability Test (20 rapid reads) ---
    Serial.println("[TEST 6] I2C Stability Test (20 rapid reads)");
    int failures = 0;
    for (int i = 0; i < 20; i++) {
        uint8_t val = readRegister(detectedAddr, REG_WHO_AM_I);
        if (val != whoAmI) {
            failures++;
            Serial.printf("  Read %d: got 0x%02X (expected 0x%02X) — MISMATCH\n", i, val, whoAmI);
        }
    }
    if (failures == 0) {
        Serial.println("  20/20 reads consistent — PASS");
    } else {
        Serial.printf("  %d/20 reads failed — INTERMITTENT CONNECTION\n", failures);
        Serial.println("  Check for loose wires, bad solder joints, or long jumper wires");
    }
    Serial.println();

    // --- TEST 7: Raw Data Sanity Check ---
    Serial.println("[TEST 7] Raw Sensor Data Sanity Check");
    Serial.println("  Reading 10 samples at rest...");
    int16_t restAx[10], restAy[10], restAz[10];
    int16_t restGx[10], restGy[10], restGz[10];
    bool readErrors = false;

    for (int i = 0; i < 10; i++) {
        if (!readMotion6(detectedAddr, restAx[i], restAy[i], restAz[i], restGx[i], restGy[i], restGz[i])) {
            readErrors = true;
            Serial.printf("  Sample %d: READ FAILED\n", i);
        }
        delay(50);
    }

    if (readErrors) {
        Serial.println("  FAIL — Could not read sensor data");
        Serial.println("  Sensor responds to WHO_AM_I but data registers fail");
        Serial.println("  Try: power cycle the ESP32 and sensor");
    } else {
        // Check accelerometer — at rest, one axis should show ~±4096 (1g at ±8g range)
        int16_t avgAx=0, avgAy=0, avgAz=0;
        for (int i = 0; i < 10; i++) {
            avgAx += restAx[i]/10; avgAy += restAy[i]/10; avgAz += restAz[i]/10;
        }

        float gMag = sqrt((float)avgAx*avgAx + (float)avgAy*avgAy + (float)avgAz*avgAz) / 4096.0;
        Serial.printf("  Avg Accel (raw): X=%d  Y=%d  Z=%d\n", avgAx, avgAy, avgAz);
        Serial.printf("  Gravity magnitude: %.2fg (expected ~1.00g)\n", gMag);

        if (gMag < 0.5 || gMag > 1.5) {
            Serial.println("  WARNING — Gravity reading out of range");
            if (gMag < 0.1) {
                Serial.println("  All axes near zero — sensor may be stuck/dead");
            }
        } else {
            Serial.println("  Gravity check PASS");
        }

        // Check if all values are identical (stuck sensor)
        bool allSame = true;
        for (int i = 1; i < 10; i++) {
            if (restAx[i] != restAx[0] || restAy[i] != restAy[0] || restAz[i] != restAz[0]) {
                allSame = false;
                break;
            }
        }
        if (allSame) {
            Serial.println("  WARNING — All 10 samples identical! Sensor may be frozen");
        } else {
            Serial.println("  Values vary across samples — sensor is alive");
        }

        // Check gyro at rest — should be near zero
        int16_t avgGx=0, avgGy=0, avgGz=0;
        for (int i = 0; i < 10; i++) {
            avgGx += restGx[i]/10; avgGy += restGy[i]/10; avgGz += restGz[i]/10;
        }
        float gyroDrift = sqrt((float)avgGx*avgGx + (float)avgGy*avgGy + (float)avgGz*avgGz);
        Serial.printf("  Avg Gyro (raw):  X=%d  Y=%d  Z=%d\n", avgGx, avgGy, avgGz);
        Serial.printf("  Gyro drift magnitude: %.0f (should be <500 at rest)\n", gyroDrift);
        if (gyroDrift > 500) {
            Serial.println("  WARNING — High gyro drift at rest, possible sensor issue");
        } else {
            Serial.println("  Gyro at rest PASS");
        }
    }

    Serial.println();
    Serial.println("==============================================");
    Serial.println("  DIAGNOSTIC SUMMARY");
    Serial.println("==============================================");
    Serial.printf("  I2C Address: 0x%02X\n", detectedAddr);
    Serial.printf("  WHO_AM_I:    0x%02X\n", whoAmI);
    Serial.printf("  I2C Stability: %d/20 errors\n", failures);
    Serial.println("==============================================");
    Serial.println();
    Serial.println("Starting continuous data stream...");
    Serial.println("Move the sensor to verify axes respond.");
    Serial.println("Format: accX accY accZ | gyroX gyroY gyroZ | mag(g)");
    Serial.println("---");

    // Switch to 400kHz for streaming
    Wire.setClock(400000);
}

void loop() {
    int16_t ax, ay, az, gx, gy, gz;

    if (readMotion6(detectedAddr, ax, ay, az, gx, gy, gz)) {
        float fax = ax / 4096.0;
        float fay = ay / 4096.0;
        float faz = az / 4096.0;
        float frx = gx / 32.8;
        float fry = gy / 32.8;
        float frz = gz / 32.8;
        float mag = sqrt(fax*fax + fay*fay + faz*faz);

        Serial.printf("A: %+7.3f %+7.3f %+7.3f | G: %+8.2f %+8.2f %+8.2f | %.3fg",
                       fax, fay, faz, frx, fry, frz, mag);

        // Visual bar for magnitude
        if (mag > 2.0) {
            Serial.print("  <<<< IMPACT!");
        } else if (mag > 1.5) {
            Serial.print("  << motion");
        }
        Serial.println();
    } else {
        Serial.println("READ ERROR — check wiring!");
    }

    delay(100);  // 10 Hz for readable serial output
}

// --- Helper Functions ---

uint8_t readRegister(uint8_t addr, uint8_t reg) {
    Wire.beginTransmission(addr);
    Wire.write(reg);
    if (Wire.endTransmission(false) != 0) return 0xFF;
    Wire.requestFrom(addr, (uint8_t)1);
    if (Wire.available()) return Wire.read();
    return 0xFF;
}

void writeRegister(uint8_t addr, uint8_t reg, uint8_t value) {
    Wire.beginTransmission(addr);
    Wire.write(reg);
    Wire.write(value);
    Wire.endTransmission();
}

bool readMotion6(uint8_t addr, int16_t &ax, int16_t &ay, int16_t &az,
                 int16_t &gx, int16_t &gy, int16_t &gz) {
    Wire.beginTransmission(addr);
    Wire.write(REG_ACCEL_XOUT_H);
    if (Wire.endTransmission(false) != 0) return false;

    Wire.requestFrom(addr, (uint8_t)14);
    if (Wire.available() < 14) return false;

    ax = (Wire.read() << 8) | Wire.read();
    ay = (Wire.read() << 8) | Wire.read();
    az = (Wire.read() << 8) | Wire.read();
    Wire.read(); Wire.read();  // skip temperature
    gx = (Wire.read() << 8) | Wire.read();
    gy = (Wire.read() << 8) | Wire.read();
    gz = (Wire.read() << 8) | Wire.read();
    return true;
}
