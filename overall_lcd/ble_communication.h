#pragma once

#include "BLECharacteristic.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "utils.h"

#define SERVICE_UUID "69b61d63-0927-4bea-92c7-28a0020a844a"
#define CHARACTERISTIC_TEXT_UUID "9631882c-b69b-4677-9735-da022e2eb58f"
#define CHARACTERISTIC_PICTURE_START_UUID "ec33a9d4-722e-4385-9e71-9ce7acfa82e8"
#define CHARACTERISTIC_PICTURE_UUID "b31c1597-6e57-4871-97f1-39f3ffdeb73a"

namespace BLE_COM {

DisplayMode mode = DisplayMode::IDLE;
bool newMessage = false;

String text = "";
int textX = 0;
int textY = 0;
int textSize = 5;
uint16_t textColor = 0x0000;
uint16_t textBackgroundColor = 0xFFFF;

bool pictureStart = false;
PixelBuffer pixBuffer = PixelBuffer(320, 240, 2500);

class ServerCallbacks : public BLEServerCallbacks {

  void onDisconnect(BLEServer* pServer) {
    mode = DisplayMode::IDLE;
    newMessage = true;
    BLEDevice::startAdvertising();
  }
};

class TextCallbacks : public BLECharacteristicCallbacks {

  void onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue();
    if (value.length() == 0) {
      return;
    }

    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, value);

    if (error) {
      Serial.print("JSON Fehler: ");
      Serial.println(error.c_str());
      return;
    }

    text = doc["text"] | "";
    textX = doc["x"] | 0;
    textY = doc["y"] | 0;
    textSize = doc["textSize"] | 5;
    textColor = doc["textColor"] | 0xFFFF;
    textBackgroundColor = doc["backgroundColor"] | 0xFFFF;

    mode = DisplayMode::TEXT;
    newMessage = true;
  }
};

class PictureStartCallbacks : public BLECharacteristicCallbacks {

  void onWrite(BLECharacteristic *pCharacteristic) {
    pixBuffer.reset();
    
    String value = pCharacteristic->getValue();
    if (value.length() == 0) {
      return;
    }

    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, value);

    if (error) {
      Serial.print("JSON Fehler: ");
      Serial.println(error.c_str());
      return;
    }

    pictureStart = doc["start"] | false;

    mode = DisplayMode::PICTURE;
    newMessage = true;
  }
};

class PictureCallbacks : public BLECharacteristicCallbacks {

  void onWrite(BLECharacteristic *pCharacteristic) {
    newMessage = true;
    uint8_t* data = pCharacteristic->getData();
    size_t length = pCharacteristic->getLength();

    if (length % 2 != 0) {
      Serial.println("FEHLER: Ungerade Anzahl Bytes!");
      return;
    }

    for (size_t i = 0; i < length; i += 2) {
      uint16_t pixel =
        data[i] |
        (data[i + 1] << 8);
      pixBuffer.addPixel(pixel);
    }
  }
};

BLECharacteristic *textCharacteristic;
BLECharacteristic *pictureStartCharacteristic;
BLECharacteristic *pictureCharacteristic;
void ble_init() {
  Serial.println("BLE init gestartet");
  BLEDevice::init("Overall-LCD");

  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);

  textCharacteristic = service->createCharacteristic(
    CHARACTERISTIC_TEXT_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pictureStartCharacteristic = service->createCharacteristic(
    CHARACTERISTIC_PICTURE_START_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pictureCharacteristic = service->createCharacteristic(
    CHARACTERISTIC_PICTURE_UUID,
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_WRITE_NR
  );

  textCharacteristic->setCallbacks(new TextCallbacks());
  pictureStartCharacteristic->setCallbacks(new PictureStartCallbacks());
  pictureCharacteristic->setCallbacks(new PictureCallbacks());

  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();

  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);

  BLEDevice::startAdvertising();
}

}