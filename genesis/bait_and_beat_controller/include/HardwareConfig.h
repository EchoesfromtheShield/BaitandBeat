#pragma once

#include <Arduino.h>

namespace HardwareConfig {

constexpr uint32_t SERIAL_BAUD = 115200;

// Genesis Mini V1 Rev2 AX22 port map.
//
// Important: the physical Axiometa port labels do not match the temporary
// SLOT1/SLOT2/SLOT3/SLOT4 names used by the first pin-probe firmware. Use these
// Axiometa P* names for all application code.
constexpr uint8_t AX_P1_IO0 = 4;
constexpr uint8_t AX_P1_IO1 = 3;
constexpr uint8_t AX_P1_IO2 = 2;

constexpr uint8_t AX_P2_IO0 = 7;
constexpr uint8_t AX_P2_IO1 = 6;
constexpr uint8_t AX_P2_IO2 = 5;

constexpr uint8_t AX_P3_IO0 = 9;
constexpr uint8_t AX_P3_IO1 = 16;
constexpr uint8_t AX_P3_IO2 = 15;

constexpr uint8_t AX_P4_IO0 = 1;
constexpr uint8_t AX_P4_IO1 = 17;
constexpr uint8_t AX_P4_IO2 = 18;

constexpr uint8_t AX22_MOSI = 12;
constexpr uint8_t AX22_MISO = 13;
constexpr uint8_t AX22_SCK = 14;
constexpr uint8_t AX22_SDA = 10;
constexpr uint8_t AX22_SCL = 11;

// Module signal reference from the current Genesis Mini setup, independently
// verified with Axiometa-generated test firmware:
// - AX22-0003 encoder: P1_IO0 push, P1_IO1 CLK, P1_IO2 DT.
// - AX22-0050 LED button: P2_IO1 button, P2_IO2 LED.
// - AX22-0013 ERM motor: P3_IO1 motor.

// P1: rotary encoder module.
constexpr uint8_t ENCODER_A_PIN = AX_P1_IO1;
constexpr uint8_t ENCODER_B_PIN = AX_P1_IO2;
constexpr uint8_t ENCODER_PUSH_PIN = AX_P1_IO0; // unused in M0
constexpr bool HAS_ROTARY_ENCODER = true;

// P2: tactile LED button module.
constexpr uint8_t ACTION_BUTTON_PIN = AX_P2_IO1;
constexpr uint8_t ACTION_LED_PIN = AX_P2_IO2;

// P3: ERM vibration motor module.
constexpr uint8_t VIBRATION_MOTOR_PIN = AX_P3_IO1;
constexpr bool HAS_VIBRATION_MOTOR = true;

constexpr bool ACTIVE_LOW_BUTTON = true;
constexpr bool ACTIVE_HIGH_LED = true;
constexpr bool ACTIVE_HIGH_MOTOR = true;

constexpr uint16_t BITE_HAPTIC_MS = 500;
constexpr uint16_t CAPTURE_HAPTIC_MS = 850;
constexpr uint16_t BUTTON_PRESS_LED_MS = 2000;

} // namespace HardwareConfig
