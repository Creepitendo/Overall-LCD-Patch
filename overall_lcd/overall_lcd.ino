#include <TFT_eSPI.h>
#include <ArduinoJson.h>
#include "utils.h"
#include "ble_communication.h"  
#include "config_json.h"

#define IDLE_TIME 30000
#define TEXTBACKGROUND_TIME 30000
#define TEXT_TIME 300

TFT_eSPI tft = TFT_eSPI();

unsigned int idleUpdateTime = IDLE_TIME;

unsigned int textBackgroundUpdateTime = 0;
unsigned int textUpdateTime = 0;
unsigned int textProgress = 0;
String slicedInput = "";

String input = "Erstiwoche Informatik :D!   ";

void setup() {
  Serial.begin(115200);

  BLE_COM::ble_init();

  tft.init();
  tft.setRotation(1);        
  tft.fillScreen(TFT_BLACK); 

  endianSwap(imgMatrix_RGB565, 190, 190);
}

void loop() {
  if (BLE_COM::newMessage) {
    switch (BLE_COM::mode) {
      case DisplayMode::IDLE:
        idleUpdateTime = IDLE_TIME;
        break;
      case DisplayMode::TEXT:
        textBackgroundUpdateTime = TEXTBACKGROUND_TIME;
        textUpdateTime = TEXT_TIME;
        break;
      case DisplayMode::PICTURE:
        if (BLE_COM::pictureStart){
          tft.fillScreen(0xFFFF);
          BLE_COM::pictureStart = false;
        }
        break;
    }

    BLE_COM::newMessage = false;
  }

  switch (BLE_COM::mode) {
    case DisplayMode::IDLE: {
        if (millis() - idleUpdateTime >= IDLE_TIME) {
          tft.fillScreen(0xFFFF);
          tft.pushImage(65, 25, 190, 190, imgMatrix_RGB565);
          idleUpdateTime = millis();
        }
        break;
    }

    case DisplayMode::TEXT: {
        input = BLE_COM::text + "    ";

        if (millis() - textBackgroundUpdateTime >= TEXTBACKGROUND_TIME) {
          tft.fillScreen(BLE_COM::textBackgroundColor);
          textBackgroundUpdateTime = millis();
        }

        if (millis() - textUpdateTime >= TEXT_TIME) {
          if (textProgress >= input.length()) textProgress = 0;
          slicedInput = input.substring(textProgress, input.length()) + input.substring(0, textProgress);
          tft.setTextSize(BLE_COM::textSize);
          tft.setTextColor(BLE_COM::textColor, BLE_COM::textBackgroundColor);
          tft.drawString(slicedInput, BLE_COM::textX, BLE_COM::textY);
          textProgress++;
          textUpdateTime = millis();
        }
        break;
    }

    case DisplayMode::PICTURE: {
        static uint16_t row[320];
        bool isRowPresent = BLE_COM::pixBuffer.getRow(row);
        
        if (isRowPresent) {
          endianSwap(row, 320, 1);
          tft.pushImage(0, BLE_COM::pixBuffer.getCurrentRowCount(), 320, 1, row);
          BLE_COM::pixBuffer.nextRow();
        }
        break;
    }
  }
}