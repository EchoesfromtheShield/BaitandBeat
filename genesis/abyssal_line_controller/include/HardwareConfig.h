#pragma once

#include <Arduino.h>

namespace HardwareConfig {

constexpr uint32_t SERIAL_BAUD = 115200;

// Genesis Mini V1 Rev2 AX22 slot map from the board schematic.
constexpr uint8_t SLOT1_IO0 = 9;
constexpr uint8_t SLOT1_IO1 = 16;
constexpr uint8_t SLOT1_IO2 = 15;

constexpr uint8_t SLOT2_IO0 = 1;
constexpr uint8_t SLOT2_IO1 = 17;
constexpr uint8_t SLOT2_IO2 = 18;

constexpr uint8_t SLOT3_IO0 = 7;
constexpr uint8_t SLOT3_IO1 = 6;
constexpr uint8_t SLOT3_IO2 = 5;

constexpr uint8_t SLOT4_IO0 = 4;
constexpr uint8_t SLOT4_IO1 = 3;
constexpr uint8_t SLOT4_IO2 = 2;

constexpr uint8_t AX22_MOSI = 12;
constexpr uint8_t AX22_MISO = 13;
constexpr uint8_t AX22_SCK = 14;
constexpr uint8_t AX22_SDA = 10;
constexpr uint8_t AX22_SCL = 11;

// Slot 1: rotary encoder module.
constexpr uint8_t ENCODER_A_PIN = SLOT1_IO1;
constexpr uint8_t ENCODER_B_PIN = SLOT1_IO2;
constexpr uint8_t ENCODER_PUSH_PIN = SLOT1_IO0; // unused in M0

// Slot 2: tactile LED button module.
constexpr uint8_t ACTION_BUTTON_PIN = SLOT2_IO1;
constexpr uint8_t ACTION_LED_PIN = SLOT2_IO2;

// Slot 3: vibration motor ERM module.
constexpr uint8_t VIBRATION_MOTOR_PIN = SLOT3_IO1;

constexpr bool ACTIVE_LOW_BUTTON = true;
constexpr bool ACTIVE_HIGH_LED = true;
constexpr bool ACTIVE_HIGH_MOTOR = true;

} // namespace HardwareConfig

