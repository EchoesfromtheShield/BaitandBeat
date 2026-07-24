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

// Module signal reference from the current Genesis Mini setup:
// - AX22-0003 encoder: P1_IO0 push, P1_IO1 CLK, P1_IO2 DT.
// - AX22-0050 LED button: P2_IO1 button, P2_IO2 LED.
// - AX22-0013 ERM motor: P3_IO1 motor.
//
// The raw GPIO/slot labels below come from the board schematic, but the first
// probe session showed the LED button responding on slot3_io2/GPIO5. For M0 we
// trust the observed LED pin and defer haptics until the ERM pin is verified.

// Slot 1: rotary encoder module.
constexpr uint8_t ENCODER_A_PIN = SLOT1_IO1;
constexpr uint8_t ENCODER_B_PIN = SLOT1_IO2;
constexpr uint8_t ENCODER_PUSH_PIN = SLOT1_IO0; // unused in M0

// Observed tactile LED button module mapping.
constexpr uint8_t ACTION_BUTTON_PIN = SLOT3_IO1;
constexpr uint8_t ACTION_LED_PIN = SLOT3_IO2;

// ERM motor module. Disabled for M0 until its actual GPIO is verified.
constexpr uint8_t VIBRATION_MOTOR_PIN = SLOT3_IO1;
constexpr bool HAS_VIBRATION_MOTOR = false;

constexpr bool ACTIVE_LOW_BUTTON = true;
constexpr bool ACTIVE_HIGH_LED = true;
constexpr bool ACTIVE_HIGH_MOTOR = true;

} // namespace HardwareConfig
