#include <Arduino.h>
#include "HardwareConfig.h"

#if defined(ABYSSAL_LINE_PIN_PROBE)

namespace {

struct PinDef {
  const char* label;
  uint8_t pin;
};

PinDef inputPins[] = {
  {"slot1_io0", HardwareConfig::SLOT1_IO0},
  {"slot1_io1", HardwareConfig::SLOT1_IO1},
  {"slot1_io2", HardwareConfig::SLOT1_IO2},
  {"slot2_io0", HardwareConfig::SLOT2_IO0},
  {"slot2_io1", HardwareConfig::SLOT2_IO1},
  {"slot2_io2", HardwareConfig::SLOT2_IO2},
  {"slot3_io0", HardwareConfig::SLOT3_IO0},
  {"slot3_io1", HardwareConfig::SLOT3_IO1},
  {"slot3_io2", HardwareConfig::SLOT3_IO2},
};

PinDef outputPins[] = {
  {"slot2_io0", HardwareConfig::SLOT2_IO0},
  {"slot2_io1", HardwareConfig::SLOT2_IO1},
  {"slot2_io2", HardwareConfig::SLOT2_IO2},
  {"slot3_io0", HardwareConfig::SLOT3_IO0},
  {"slot3_io1", HardwareConfig::SLOT3_IO1},
  {"slot3_io2", HardwareConfig::SLOT3_IO2},
};

constexpr uint8_t INPUT_PIN_COUNT = sizeof(inputPins) / sizeof(inputPins[0]);
constexpr uint8_t OUTPUT_PIN_COUNT = sizeof(outputPins) / sizeof(outputPins[0]);

int lastValues[INPUT_PIN_COUNT];
uint32_t seq = 1;
uint32_t lastReadMs = 0;
uint32_t phaseStartedMs = 0;
uint8_t outputIndex = 0;
bool outputActive = false;

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

void sendOutputEvent(const PinDef& pin, bool active) {
  String payload = "{\"label\":\"";
  payload += pin.label;
  payload += "\",\"gpio\":";
  payload += pin.pin;
  payload += ",\"active\":";
  payload += active ? "true" : "false";
  payload += "}";
  sendEnvelope("PIN_PROBE_OUTPUT", payload);
}

void updateOutputScan() {
  const uint32_t now = millis();

  if (phaseStartedMs == 0) {
    phaseStartedMs = now;
  }

  if (!outputActive && (now - phaseStartedMs) >= 700) {
    allPinsInputPullup();
    const PinDef& pin = outputPins[outputIndex];
    pinMode(pin.pin, OUTPUT);
    digitalWrite(pin.pin, HIGH);
    outputActive = true;
    phaseStartedMs = now;
    sendOutputEvent(pin, true);
    return;
  }

  if (outputActive && (now - phaseStartedMs) >= 220) {
    const PinDef& pin = outputPins[outputIndex];
    digitalWrite(pin.pin, LOW);
    pinMode(pin.pin, INPUT_PULLUP);
    outputActive = false;
    phaseStartedMs = now;
    sendOutputEvent(pin, false);
    outputIndex = (outputIndex + 1) % OUTPUT_PIN_COUNT;
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
    "{\"board\":\"genesis-mini-v1-rev2\",\"notes\":\"do_not_press_button_during_output_scan\"}"
  );
  sendInputSnapshot("boot");
}

void loop() {
  readInputs();
  updateOutputScan();
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

String incomingLine;
String remoteState = "BOOT";
float remoteSignal = 0.0f;
float remoteTension = 0.0f;
float remoteCapture = 0.0f;

void setLed(bool on) {
  digitalWrite(
    HardwareConfig::ACTION_LED_PIN,
    on == HardwareConfig::ACTIVE_HIGH_LED ? HIGH : LOW
  );
}

void setMotor(bool on) {
  digitalWrite(
    HardwareConfig::VIBRATION_MOTOR_PIN,
    on == HardwareConfig::ACTIVE_HIGH_MOTOR ? HIGH : LOW
  );
}

void pulseMotor(uint16_t durationMs) {
  const uint32_t until = millis() + static_cast<uint32_t>(durationMs);
  motorUntilMs = motorUntilMs > until ? motorUntilMs : until;
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
  sendEnvelope(
    "HELLO",
    "{\"device_role\":\"genesis\",\"firmware\":\"abyssal-line-m0-serial\","
    "\"board\":\"genesis-mini-v1-rev2\","
    "\"capabilities\":[\"encoder\",\"button_led\",\"vibration\",\"usb_cdc_serial\"]}"
  );
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
    lastGameStateMs = millis();
    sendEnvelope("DEBUG_RX", "{\"remote_type\":\"HELLO_ACK\"}");
    pulseLed(180);
    pulseMotor(40);
    return;
  }

  if (line.indexOf("\"type\":\"GAME_STATE\"") >= 0) {
    lastGameStateMs = millis();
    sendEnvelope("DEBUG_RX", "{\"remote_type\":\"GAME_STATE\"}");
    remoteState = parseStringField(line, "state", remoteState);
    remoteSignal = parseFloatField(line, "signal_0_1", remoteSignal);
    remoteTension = parseFloatField(line, "tension_0_1", remoteTension);
    remoteCapture = parseFloatField(line, "capture_progress_0_1", remoteCapture);

    if (line.indexOf("\"bite_ready\":true") >= 0) {
      pulseLed(90);
      pulseMotor(70);
    }
    return;
  }

  if (line.indexOf("\"type\":\"PATTERN_EVENT\"") >= 0) {
    sendEnvelope("DEBUG_RX", "{\"remote_type\":\"PATTERN_EVENT\"}");
    pulseLed(35);
    pulseMotor(35);
    return;
  }

  if (line.indexOf("\"type\":\"ERROR\"") >= 0) {
    sendEnvelope("DEBUG_RX", "{\"remote_type\":\"ERROR\"}");
    connected = false;
    pulseMotor(160);
  }
}

bool readRawActionButton() {
  const bool level = digitalRead(HardwareConfig::ACTION_BUTTON_PIN) == HIGH;
  return HardwareConfig::ACTIVE_LOW_BUTTON ? !level : level;
}

void pollEncoder() {
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
    pulseLed(80);
    pulseMotor(30);
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
  setMotor(motorUntilMs > now);

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
  pinMode(HardwareConfig::ENCODER_A_PIN, INPUT_PULLUP);
  pinMode(HardwareConfig::ENCODER_B_PIN, INPUT_PULLUP);
  pinMode(HardwareConfig::ACTION_BUTTON_PIN, INPUT_PULLUP);
  pinMode(HardwareConfig::ACTION_LED_PIN, OUTPUT);
  pinMode(HardwareConfig::VIBRATION_MOTOR_PIN, OUTPUT);

  setLed(false);
  setMotor(false);

  Serial.begin(HardwareConfig::SERIAL_BAUD);
  lastEncoderState = readEncoderState();
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
