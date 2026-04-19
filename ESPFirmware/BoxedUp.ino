// BoxedUpGlove.ino — ESP32 firmware for the smart glove
// Streams MPU6050 6-axis IMU data over BLE at 50 Hz

#include <Wire.h>
#include <MPU6050.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// BLE UUIDs (custom — must match iPhone app)
#define SERVICE_UUID        "12345678-1234-1234-1234-123456789ABC"
#define MOTION_CHAR_UUID    "12345678-1234-1234-1234-123456789ABD"
#define CONTROL_CHAR_UUID   "12345678-1234-1234-1234-123456789ABE"

MPU6050 mpu;
BLECharacteristic* motionChar;
BLECharacteristic* controlChar;

bool deviceConnected = false;
bool capturing = false;

// Sampling
const int SAMPLE_RATE_HZ = 50;
const int SAMPLE_INTERVAL_US = 1000000 / SAMPLE_RATE_HZ;  // 20000 µs
const int BATCH_SIZE = 5;

// Calibration offsets (set during calibration step)
int16_t axOff = 0, ayOff = 0, azOff = 0;
int16_t gxOff = 0, gyOff = 0, gzOff = 0;

// --- BLE Callbacks ---
class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* s)    { deviceConnected = true;  }
    void onDisconnect(BLEServer* s) { deviceConnected = false; capturing = false; }
};

class ControlCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* c) {
        uint8_t* data = c->getData();
        if (c->getLength() > 0) {
            capturing = (data[0] == 0x01);  // 0x01 = start, 0x00 = stop
        }
    }
};

void setup() {
    Serial.begin(115200);
    Wire.begin(21, 22);           // SDA=21, SCL=22
    Wire.setClock(400000);        // 400 kHz I2C fast mode

    // Init MPU6050
    mpu.initialize();
    mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_8);   // ±8g
    mpu.setFullScaleGyroRange(MPU6050_GYRO_FS_1000);  // ±1000°/s
    mpu.setDLPFMode(MPU6050_DLPF_BW_42);              // 42 Hz low-pass filter

    // Calibrate (keep glove still during startup)
    calibrateSensor();

    // Init BLE
    BLEDevice::init("BoxedUpGlove");
    BLEServer* server = BLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks());

    BLEService* service = server->createService(SERVICE_UUID);

    motionChar = service->createCharacteristic(
        MOTION_CHAR_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    motionChar->addDescriptor(new BLE2902());

    controlChar = service->createCharacteristic(
        CONTROL_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    controlChar->setCallbacks(new ControlCallbacks());

    service->start();
    BLEAdvertising* adv = BLEDevice::getAdvertising();
    adv->addServiceUUID(SERVICE_UUID);
    adv->start();

    Serial.println("[Glove] BLE advertising as 'BoxedUpGlove'");
}

void loop() {
    if (!deviceConnected || !capturing) {
        delay(100);
        return;
    }

    // Collect a batch of samples
    uint8_t buffer[BATCH_SIZE * 28];  // 5 samples × 28 bytes each
    for (int i = 0; i < BATCH_SIZE; i++) {
        unsigned long t = micros();

        int16_t ax, ay, az, gx, gy, gz;
        mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);

        // Convert to physical units (g and °/s) as Float32
        // ±8g range: sensitivity = 4096 LSB/g
        // ±1000°/s range: sensitivity = 32.8 LSB/(°/s)
        float accX = (float)(ax - axOff) / 4096.0f;
        float accY = (float)(ay - ayOff) / 4096.0f;
        float accZ = (float)(az - azOff) / 4096.0f;
        float rotX = (float)(gx - gxOff) / 32.8f;
        float rotY = (float)(gy - gyOff) / 32.8f;
        float rotZ = (float)(gz - gzOff) / 32.8f;

        // Pack into buffer: [timestamp(4) + accXYZ(12) + rotXYZ(12)] = 28 bytes
        uint32_t ts = (uint32_t)(t / 1000);  // milliseconds
        int offset = i * 28;
        memcpy(&buffer[offset +  0], &ts,   4);
        memcpy(&buffer[offset +  4], &accX, 4);
        memcpy(&buffer[offset +  8], &accY, 4);
        memcpy(&buffer[offset + 12], &accZ, 4);
        memcpy(&buffer[offset + 16], &rotX, 4);
        memcpy(&buffer[offset + 20], &rotY, 4);
        memcpy(&buffer[offset + 24], &rotZ, 4);

        // Wait for next sample interval
        unsigned long elapsed = micros() - t;
        if (elapsed < SAMPLE_INTERVAL_US) {
            delayMicroseconds(SAMPLE_INTERVAL_US - elapsed);
        }
    }

    // Send batch over BLE notify
    motionChar->setValue(buffer, BATCH_SIZE * 28);
    motionChar->notify();
}

void calibrateSensor() {
    Serial.println("[Glove] Calibrating — keep still for 2 seconds...");
    long sumAx=0, sumAy=0, sumAz=0, sumGx=0, sumGy=0, sumGz=0;
    int n = 100;
    for (int i = 0; i < n; i++) {
        int16_t ax, ay, az, gx, gy, gz;
        mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);
        sumAx += ax; sumAy += ay; sumAz += az;
        sumGx += gx; sumGy += gy; sumGz += gz;
        delay(20);
    }
    axOff = sumAx / n;
    ayOff = sumAy / n;
    azOff = (sumAz / n) - 4096;  // Remove gravity (1g = 4096 LSB at ±8g)
    gxOff = sumGx / n;
    gyOff = sumGy / n;
    gzOff = sumGz / n;
    Serial.println("[Glove] Calibration complete.");
}