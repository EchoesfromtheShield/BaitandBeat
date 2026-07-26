#include <Arduino.h>
#include "HardwareConfig.h"

#if defined(BAIT_AND_BEAT_PIN_PROBE)

namespace {

struct PinDef {
  const char* label;
  uint8_t pin;
};

PinDef inputPins[] = {
  {"p1_io0", HardwareConfig::AX_P1_IO0},
  {"p1_io1", HardwareConfig::AX_P1_IO1},
  {"p1_io2", HardwareConfig::AX_P1_IO2},
  {"p2_io0", HardwareConfig::AX_P2_IO0},
  {"p2_io1", HardwareConfig::AX_P2_IO1},
  {"p2_io2", HardwareConfig::AX_P2_IO2},
  {"p3_io0", HardwareConfig::AX_P3_IO0},
  {"p3_io1", HardwareConfig::AX_P3_IO1},
  {"p3_io2", HardwareConfig::AX_P3_IO2},
  {"p4_io0", HardwareConfig::AX_P4_IO0},
  {"p4_io1", HardwareConfig::AX_P4_IO1},
  {"p4_io2", HardwareConfig::AX_P4_IO2},
};

PinDef outputPins[] = {
  {"p2_io0", HardwareConfig::AX_P2_IO0},
  {"p2_io1", HardwareConfig::AX_P2_IO1},
  {"p2_io2", HardwareConfig::AX_P2_IO2},
  {"p3_io0", HardwareConfig::AX_P3_IO0},
  {"p3_io1", HardwareConfig::AX_P3_IO1},
  {"p3_io2", HardwareConfig::AX_P3_IO2},
  {"p4_io0", HardwareConfig::AX_P4_IO0},
  {"p4_io1", HardwareConfig::AX_P4_IO1},
  {"p4_io2", HardwareConfig::AX_P4_IO2},
};

constexpr uint8_t INPUT_PIN_COUNT = sizeof(inputPins) / sizeof(inputPins[0]);
constexpr uint8_t OUTPUT_PIN_COUNT = sizeof(outputPins) / sizeof(outputPins[0]);

int lastValues[INPUT_PIN_COUNT];
uint32_t seq = 1;
uint32_t lastReadMs = 0;
uint32_t pulseUntilMs = 0;
int8_t pulsedOutputIndex = -1;
bool outputActive = false;
String incomingLine;

void sendEnvelope(const char* type, const String& payload) {
  Serial.print("{\"v_major\":1,\"v_minor\":0,\"seq\":");
  Serial.print(seq++);
  Serial.print(",\"type\":\"");
  Serial.print(type);
  Serial.print("\",\"payload\":");
  Serial.print(payload);
  Serial.println("}");
}

void allPinsInputPullup() {
  for (uint8_t i = 0; i < INPUT_PIN_COUNT; ++i) {
    pinMode(inputPins[i].pin, INPUT_PULLUP);
  }
}

void sendInputSnapshot(const char* reason) {
  String payload = String("{\"reason\":\"") + reason + "\",\"pins\":{";
  for (uint8_t i = 0; i < INPUT_PIN_COUNT; ++i) {
    if (i > 0) {
      payload += ",";
    }
    payload += "\"";
    payload += inputPins[i].label;
    payload += "\":";
    payload += digitalRead(inputPins[i].pin) == HIGH ? "1" : "0";
  }
  payload += "}}";
  sendEnvelope("PIN_PROBE_INPUT", payload);
}

void readInputs() {
  const uint32_t now = millis();
  if ((now - lastReadMs) < 20 || outputActive) {
    return;
  }
  lastReadMs = now;

  bool changed = false;
  for (uint8_t i = 0; i < INPUT_PIN_COUNT; ++i) {
    const int value = digitalRead(inputPins[i].pin);
    if (value != lastValues[i]) {
      changed = true;
      lastValues[i] = value;
    }
  }

  if (changed) {
    sendInputSnapshot("changed");
  }
}

void sendOutputEvent(const PinDef& pin, bool active, const char* level) {
  String payload = "{\"label\":\"";
  payload += pin.label;
  payload += "\",\"gpio\":";
  payload += pin.pin;
  payload += ",\"level\":\"";
  payload += level;
  payload += "\"";
  payload += ",\"active\":";
  payload += active ? "true" : "false";
  payload += "}";
  sendEnvelope("PIN_PROBE_OUTPUT", payload);
}

int8_t findOutputPin(const String& line) {
  for (uint8_t i = 0; i < OUTPUT_PIN_COUNT; ++i) {
    if (line.indexOf(String("\"label\":\"") + outputPins[i].label + "\"") >= 0) {
      return i;
    }
  }
  return -1;
}

uint32_t parseDurationMs(const String& line) {
  const String key = "\"duration_ms\":";
  const int keyIndex = line.indexOf(key);
  if (keyIndex < 0) {
    return 1000;
  }

  const int valueStart = keyIndex + key.length();
  const uint32_t parsed = line.substring(valueStart).toInt();
  if (parsed < 50) {
    return 50;
  }
  if (parsed > 5000) {
    return 5000;
  }
  return parsed;
}

bool parseLevelHigh(const String& line) {
  if (line.indexOf("\"level\":\"LOW\"") >= 0) {
    return false;
  }
  return true;
}

void stopPulse() {
  if (pulsedOutputIndex < 0) {
    return;
  }

  const PinDef& pin = outputPins[pulsedOutputIndex];
  digitalWrite(pin.pin, LOW);
  pinMode(pin.pin, INPUT_PULLUP);
  outputActive = false;
  pulseUntilMs = 0;
  sendOutputEvent(pin, false, "FLOAT");
  pulsedOutputIndex = -1;
}

void startPulse(int8_t index, bool levelHigh, uint32_t durationMs) {
  stopPulse();

  const PinDef& pin = outputPins[index];
  pinMode(pin.pin, OUTPUT);
  digitalWrite(pin.pin, levelHigh ? HIGH : LOW);
  outputActive = true;
  pulsedOutputIndex = index;
  pulseUntilMs = millis() + durationMs;
  sendOutputEvent(pin, true, levelHigh ? "HIGH" : "LOW");
}

void handleCommand(const String& line) {
  if (line.indexOf("\"type\":\"PIN_PROBE_PULSE\"") >= 0) {
    const int8_t index = findOutputPin(line);
    if (index < 0) {
      sendEnvelope("PIN_PROBE_ERROR", "{\"error\":\"unknown_label\"}");
      return;
    }

    startPulse(index, parseLevelHigh(line), parseDurationMs(line));
    return;
  }

  if (line.indexOf("\"type\":\"PIN_PROBE_SNAPSHOT\"") >= 0) {
    sendInputSnapshot("requested");
    return;
  }

  if (line.indexOf("\"type\":\"PIN_PROBE_STOP\"") >= 0) {
    stopPulse();
    return;
  }
}

void pollSerial() {
  while (Serial.available() > 0) {
    const char c = static_cast<char>(Serial.read());
    if (c == '\r') {
      continue;
    }
    if (c == '\n') {
      if (incomingLine.length() > 0) {
        handleCommand(incomingLine);
        incomingLine = "";
      }
      continue;
    }
    if (incomingLine.length() < 512) {
      incomingLine += c;
    } else {
      incomingLine = "";
    }
  }
}

void updatePulse() {
  if (outputActive && millis() >= pulseUntilMs) {
    stopPulse();
  }
}

} // namespace

void setup() {
  Serial.begin(HardwareConfig::SERIAL_BAUD);
  allPinsInputPullup();
  delay(300);

  for (uint8_t i = 0; i < INPUT_PIN_COUNT; ++i) {
    lastValues[i] = digitalRead(inputPins[i].pin);
  }

  sendEnvelope(
    "PIN_PROBE_HELLO",
    "{\"board\":\"genesis-mini-v1-rev2\",\"notes\":\"command_driven_probe\"}"
  );
  sendInputSnapshot("boot");
}

void loop() {
  pollSerial();
  readInputs();
  updatePulse();
  delay(1);
}

#else

namespace {

constexpr uint8_t PROTOCOL_MAJOR = 1;
constexpr uint8_t PROTOCOL_MINOR = 0;

uint32_t seq = 1;
uint32_t lastHelloMs = 0;
uint32_t lastInputFlushMs = 0;
uint32_t lastStatusBlinkMs = 0;
uint32_t lastGameStateMs = 0;
uint32_t motorUntilMs = 0;
uint32_t ledUntilMs = 0;

bool connected = false;
bool statusLed = false;
int8_t lastEncoderState = 0;
int encoderAccumulator = 0;

bool debouncedButton = false;
bool lastRawButton = false;
uint32_t lastButtonChangeMs = 0;
bool lastBiteReady = false;

String incomingLine;
String remoteState = "BOOT";
float remoteSignal = 0.0f;
float remoteTension = 0.0f;
float remoteCapture = 0.0f;

void sendEnvelope(const char* type, const String& payload);

void setLed(bool on) {
  digitalWrite(
    HardwareConfig::ACTION_LED_PIN,
    on == HardwareConfig::ACTIVE_HIGH_LED ? HIGH : LOW
  );
}

void setMotor(bool on) {
  if (!HardwareConfig::HAS_VIBRATION_MOTOR) {
    return;
  }

  digitalWrite(
    HardwareConfig::VIBRATION_MOTOR_PIN,
    on == HardwareConfig::ACTIVE_HIGH_MOTOR ? HIGH : LOW
  );
}

void pulseMotor(uint16_t durationMs) {
  if (!HardwareConfig::HAS_VIBRATION_MOTOR) {
    return;
  }

  const uint32_t until = millis() + static_cast<uint32_t>(durationMs);
  motorUntilMs = motorUntilMs > until ? motorUntilMs : until;
  String payload = String("{\"pin\":") + HardwareConfig::VIBRATION_MOTOR_PIN;
  payload += ",\"duration_ms\":";
  payload += durationMs;
  payload += "}";
  sendEnvelope("HAPTIC_PULSE", payload);
}

void pulseLed(uint16_t durationMs) {
  const uint32_t until = millis() + static_cast<uint32_t>(durationMs);
  ledUntilMs = ledUntilMs > until ? ledUntilMs : until;
}

void sendEnvelope(const char* type, const String& payload) {
  Serial.print("{\"v_major\":");
  Serial.print(PROTOCOL_MAJOR);
  Serial.print(",\"v_minor\":");
  Serial.print(PROTOCOL_MINOR);
  Serial.print(",\"seq\":");
  Serial.print(seq++);
  Serial.print(",\"type\":\"");
  Serial.print(type);
  Serial.print("\",\"payload\":");
  Serial.print(payload);
  Serial.println("}");
}

void sendHello() {
  String payload = "{\"device_role\":\"genesis\",\"firmware\":\"bait-and-beat-m0-serial\",";
  payload += "\"board\":\"genesis-mini-v1-rev2\",";
  payload += "\"motor_gpio\":";
  payload += HardwareConfig::VIBRATION_MOTOR_PIN;
  payload += ",\"capabilities\":[";
  if (HardwareConfig::HAS_ROTARY_ENCODER) {
    payload += "\"encoder\",";
  }
  payload += "\"button_led\",\"vibration\",\"usb_cdc_serial\"]}";
  sendEnvelope("HELLO", payload);
}

void sendEncoderDelta(int delta) {
  sendEnvelope("INPUT_ENCODER_DELTA", String("{\"delta\":") + delta + "}");
}

void sendButton(const char* eventName) {
  sendEnvelope("INPUT_BUTTON", String("{\"event\":\"") + eventName + "\"}");
}

int8_t readEncoderState() {
  const uint8_t a = digitalRead(HardwareConfig::ENCODER_A_PIN) ? 1 : 0;
  const uint8_t b = digitalRead(HardwareConfig::ENCODER_B_PIN) ? 1 : 0;
  return (a << 1) | b;
}

int8_t decodeEncoderStep(int8_t previous, int8_t current) {
  const uint8_t transition = (previous << 2) | current;
  switch (transition) {
    case 0b0001:
    case 0b0111:
    case 0b1110:
    case 0b1000:
      return 1;
    case 0b0010:
    case 0b0100:
    case 0b1101:
    case 0b1011:
      return -1;
    default:
      return 0;
  }
}

float parseFloatField(const String& line, const char* fieldName, float fallback) {
  const String key = String("\"") + fieldName + "\":";
  const int keyIndex = line.indexOf(key);
  if (keyIndex < 0) {
    return fallback;
  }

  const int valueStart = keyIndex + key.length();
  return line.substring(valueStart).toFloat();
}

String parseStringField(const String& line, const char* fieldName, const String& fallback) {
  const String key = String("\"") + fieldName + "\":\"";
  const int keyIndex = line.indexOf(key);
  if (keyIndex < 0) {
    return fallback;
  }

  const int valueStart = keyIndex + key.length();
  const int valueEnd = line.indexOf("\"", valueStart);
  if (valueEnd < 0) {
    return fallback;
  }

  return line.substring(valueStart, valueEnd);
}

void handleRemoteLine(const String& line) {
  if (line.indexOf("\"type\":\"HELLO_ACK\"") >= 0) {
    connected = true;
    lastBiteReady = false;
    lastGameStateMs = millis();
    sendEnvelope("DEBUG_RX", "{\"remote_type\":\"HELLO_ACK\"}");
    pulseLed(180);
    return;
  }

  if (line.indexOf("\"type\":\"GAME_STATE\"") >= 0) {
    lastGameStateMs = millis();
    sendEnvelope("DEBUG_RX", "{\"remote_type\":\"GAME_STATE\"}");
    const String previousState = remoteState;
    remoteState = parseStringField(line, "state", remoteState);
    remoteSignal = parseFloatField(line, "signal_0_1", remoteSignal);
    remoteTension = parseFloatField(line, "tension_0_1", remoteTension);
    remoteCapture = parseFloatField(line, "capture_progress_0_1", remoteCapture);

    const bool biteReady = line.indexOf("\"bite_ready\":true") >= 0;
    if (biteReady && !lastBiteReady) {
      pulseLed(90);
      pulseMotor(HardwareConfig::BITE_HAPTIC_MS);
    }
    lastBiteReady = biteReady;

    if (remoteState == "SURFACE" && previousState != "SURFACE") {
      pulseLed(420);
      pulseMotor(HardwareConfig::CAPTURE_HAPTIC_MS);
    }
    return;
  }

  if (line.indexOf("\"type\":\"PATTERN_EVENT\"") >= 0) {
    sendEnvelope("DEBUG_RX", "{\"remote_type\":\"PATTERN_EVENT\"}");
    pulseLed(35);
    return;
  }

  if (line.indexOf("\"type\":\"ERROR\"") >= 0) {
    sendEnvelope("DEBUG_RX", "{\"remote_type\":\"ERROR\"}");
    connected = false;
    lastBiteReady = false;
  }
}

bool readRawActionButton() {
  const bool level = digitalRead(HardwareConfig::ACTION_BUTTON_PIN) == HIGH;
  return HardwareConfig::ACTIVE_LOW_BUTTON ? !level : level;
}

void pollEncoder() {
  if (!HardwareConfig::HAS_ROTARY_ENCODER) {
    return;
  }

  const int8_t current = readEncoderState();
  if (current == lastEncoderState) {
    return;
  }

  encoderAccumulator += decodeEncoderStep(lastEncoderState, current);
  lastEncoderState = current;
}

void pollButton() {
  const bool rawPressed = readRawActionButton();
  const uint32_t now = millis();

  if (rawPressed != lastRawButton) {
    lastRawButton = rawPressed;
    lastButtonChangeMs = now;
  }

  if ((now - lastButtonChangeMs) < 25) {
    return;
  }

  if (rawPressed == debouncedButton) {
    return;
  }

  debouncedButton = rawPressed;
  sendButton(debouncedButton ? "press" : "release");
  if (debouncedButton) {
    pulseLed(HardwareConfig::BUTTON_PRESS_LED_MS);
  }
}

void flushInputs() {
  const uint32_t now = millis();
  if ((now - lastInputFlushMs) < 20) {
    return;
  }
  lastInputFlushMs = now;

  if (encoderAccumulator != 0) {
    const int delta = encoderAccumulator;
    encoderAccumulator = 0;
    sendEncoderDelta(delta);
  }
}

void pollSerial() {
  while (Serial.available() > 0) {
    const char c = static_cast<char>(Serial.read());
    if (c == '\r') {
      continue;
    }
    if (c == '\n') {
      if (incomingLine.length() > 0) {
        handleRemoteLine(incomingLine);
        incomingLine = "";
      }
      continue;
    }
    if (incomingLine.length() < 512) {
      incomingLine += c;
    } else {
      incomingLine = "";
    }
  }
}

void updateFeedback() {
  const uint32_t now = millis();

  if (motorUntilMs > 0 && now >= motorUntilMs) {
    motorUntilMs = 0;
  }
  if (HardwareConfig::HAS_VIBRATION_MOTOR) {
    setMotor(motorUntilMs > now);
  }

  bool desiredLed = ledUntilMs > now;

  if (!desiredLed) {
    if (!connected) {
      if ((now - lastStatusBlinkMs) >= 350) {
        lastStatusBlinkMs = now;
        statusLed = !statusLed;
      }
      desiredLed = statusLed;
    } else if (remoteState == "RESONANCE") {
      const uint32_t period = static_cast<uint32_t>(220 - constrain(remoteSignal, 0.0f, 1.0f) * 150);
      desiredLed = (now / max<uint32_t>(period, 60)) % 2 == 0;
    } else if (remoteState == "STRUGGLE") {
      desiredLed = remoteTension >= 0.24f && remoteTension <= 0.56f;
    } else if (remoteState == "SURFACE") {
      desiredLed = true;
    } else {
      desiredLed = false;
    }
  }

  if (connected && lastGameStateMs > 0 && (now - lastGameStateMs) > 3000) {
    connected = false;
  }

  setLed(desiredLed);
}

void sendPeriodicHello() {
  const uint32_t now = millis();
  if (connected) {
    return;
  }

  if ((now - lastHelloMs) >= 1000) {
    lastHelloMs = now;
    sendHello();
  }
}

} // namespace

void setup() {
  if (HardwareConfig::HAS_ROTARY_ENCODER) {
    pinMode(HardwareConfig::ENCODER_A_PIN, INPUT_PULLUP);
    pinMode(HardwareConfig::ENCODER_B_PIN, INPUT_PULLUP);
  }
  pinMode(HardwareConfig::ACTION_BUTTON_PIN, INPUT);
  pinMode(HardwareConfig::ACTION_LED_PIN, OUTPUT);
  if (HardwareConfig::HAS_VIBRATION_MOTOR) {
    pinMode(HardwareConfig::VIBRATION_MOTOR_PIN, OUTPUT);
  }

  setLed(false);
  setMotor(false);

  Serial.begin(HardwareConfig::SERIAL_BAUD);
  if (HardwareConfig::HAS_ROTARY_ENCODER) {
    lastEncoderState = readEncoderState();
  }
  delay(200);
  sendHello();
}

void loop() {
  pollSerial();
  pollEncoder();
  pollButton();
  flushInputs();
  sendPeriodicHello();
  updateFeedback();
  delay(1);
}

#endif
