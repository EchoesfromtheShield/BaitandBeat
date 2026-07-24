#include <Arduino.h>
#include <RotaryEncoder.h>

// This sketch is for Axiometa Studio / Arduino IDE with the official Axiometa
// Genesis Mini board package. It intentionally uses Axiometa P* pin macros.

#define ENC_CLK P1_IO1
#define ENC_DT P1_IO2
#define ENC_BTN P1_IO0

#define BTN_SIG P2_IO1
#define BTN_LED P2_IO2

#define MOTOR P3_IO1

constexpr unsigned long MOTOR_TEST_MS = 1200;
constexpr unsigned long LED_TEST_MS = 1200;
constexpr unsigned long DEBOUNCE_MS = 80;

RotaryEncoder encoder(ENC_CLK, ENC_DT, RotaryEncoder::LatchMode::TWO03);

long lastEncPos = 0;
bool lastButtonLevel = HIGH;
unsigned long lastButtonAt = 0;
unsigned long motorOffAt = 0;
unsigned long ledOffAt = 0;

void printPin(const char* label, int pin) {
  Serial.print(label);
  Serial.print("=");
  Serial.println(pin);
}

void printPinMap() {
  Serial.println("PIN_FINGERPRINT_BEGIN");
  printPin("P1_IO0", P1_IO0);
  printPin("P1_IO1", P1_IO1);
  printPin("P1_IO2", P1_IO2);
  printPin("P2_IO0", P2_IO0);
  printPin("P2_IO1", P2_IO1);
  printPin("P2_IO2", P2_IO2);
  printPin("P3_IO0", P3_IO0);
  printPin("P3_IO1", P3_IO1);
  printPin("P3_IO2", P3_IO2);
  printPin("P4_IO0", P4_IO0);
  printPin("P4_IO1", P4_IO1);
  printPin("P4_IO2", P4_IO2);
  printPin("ENC_CLK", ENC_CLK);
  printPin("ENC_DT", ENC_DT);
  printPin("BTN_SIG", BTN_SIG);
  printPin("BTN_LED", BTN_LED);
  printPin("MOTOR", MOTOR);
  Serial.println("PIN_FINGERPRINT_END");
}

void startMotor(const char* reason, unsigned long durationMs) {
  Serial.print("MOTOR_ON reason=");
  Serial.print(reason);
  Serial.print(" pin=");
  Serial.print(MOTOR);
  Serial.print(" duration_ms=");
  Serial.println(durationMs);

  digitalWrite(MOTOR, HIGH);
  motorOffAt = millis() + durationMs;
}

void startLed(unsigned long durationMs) {
  digitalWrite(BTN_LED, HIGH);
  ledOffAt = millis() + durationMs;
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  printPinMap();

  pinMode(ENC_BTN, INPUT);
  pinMode(BTN_SIG, INPUT);
  pinMode(BTN_LED, OUTPUT);
  pinMode(MOTOR, OUTPUT);

  digitalWrite(BTN_LED, LOW);
  digitalWrite(MOTOR, LOW);

  Serial.println("READY press button or turn encoder");
}

void loop() {
  const unsigned long now = millis();

  encoder.tick();
  const long pos = encoder.getPosition();
  if (pos != lastEncPos) {
    lastEncPos = pos;
    Serial.print("ENCODER_TICK position=");
    Serial.println(pos);
    startMotor("encoder", MOTOR_TEST_MS);
  }

  const bool buttonLevel = digitalRead(BTN_SIG);
  if (buttonLevel == LOW && lastButtonLevel == HIGH && (now - lastButtonAt) > DEBOUNCE_MS) {
    lastButtonAt = now;
    Serial.println("BUTTON_PRESS");
    startLed(LED_TEST_MS);
    startMotor("button", MOTOR_TEST_MS);
  }
  lastButtonLevel = buttonLevel;

  if (motorOffAt > 0 && now >= motorOffAt) {
    digitalWrite(MOTOR, LOW);
    motorOffAt = 0;
    Serial.println("MOTOR_OFF");
  }

  if (ledOffAt > 0 && now >= ledOffAt) {
    digitalWrite(BTN_LED, LOW);
    ledOffAt = 0;
    Serial.println("LED_OFF");
  }
}
