local Config = {}

Config.TICK_S = 1 / 15
Config.DEPTH_STEP = 0.008
Config.CAST_DEPTH = 0.04
Config.EXPLORE_DEPTH_STEP = 0.005
Config.STRUGGLE_TENSION_STEP = 0.0045
Config.STRUGGLE_PULL_TENSION = 0.52
Config.STRUGGLE_PULL_SLEW = 0.09
Config.STRUGGLE_ENCODER_RESISTANCE = 6.5
Config.MAX_DEPTH_M = 900

Config.CREATURE_DEPTH = 0.63
Config.RESONANCE_RADIUS = 0.15
Config.BITE_RADIUS = 0.030
Config.BITE_HOLD_S = 0.45
Config.BITE_OVERLAP_MIN = 0.58
Config.BITE_READY_WINDOW_S = 1.15
Config.HOOK_OVERLAP_RADIUS = 0.105
Config.CREATURE_SWIM_SPEED = 0.17
Config.CREATURE_SWIM_BURST_CHANCE = 0.34
Config.CAMERA_DEPTH_SPAN = 0.18
Config.HOOK_X_0_1 = 0.685

Config.SAFE_TENSION_MIN = 0.40
Config.SAFE_TENSION_MAX = 0.58
Config.SLACK_TENSION = 0.14
Config.OVERLOAD_TENSION = 0.86
Config.SLACK_FAIL_S = 0.35
Config.OVERLOAD_FAIL_S = 0.30
Config.CAPTURE_RATE = 0.13
Config.CAPTURE_DECAY_RATE = 0.07
Config.SURFACE_HOLD_S = 0.45
Config.MESSAGE_HOLD_S = 2.4

Config.BPM = 90
Config.NOTES = {
  { name = "C", hz = 65.406 },
  { name = "C#", hz = 69.296 },
  { name = "D", hz = 73.416 },
  { name = "D#", hz = 77.782 },
  { name = "E", hz = 82.407 },
  { name = "F", hz = 87.307 },
  { name = "F#", hz = 92.499 },
  { name = "G", hz = 97.999 },
  { name = "G#", hz = 103.826 },
  { name = "A", hz = 110.000 },
  { name = "A#", hz = 116.541 },
  { name = "B", hz = 123.471 },
}
Config.SCALES = {
  { name = "Harmonic Minor", intervals = { 0, 2, 3, 5, 7, 8, 11 } },
  { name = "Major", intervals = { 0, 2, 4, 5, 7, 9, 11 } },
  { name = "Natural Minor", intervals = { 0, 2, 3, 5, 7, 8, 10 } },
  { name = "Pentatonic Major", intervals = { 0, 2, 4, 7, 9 } },
  { name = "Pentatonic Minor", intervals = { 0, 3, 5, 7, 10 } },
  { name = "Dorian", intervals = { 0, 2, 3, 5, 7, 9, 10 } },
  { name = "Phrygian", intervals = { 0, 1, 3, 5, 7, 8, 10 } },
  { name = "Lydian", intervals = { 0, 2, 4, 6, 7, 9, 11 } },
  { name = "Mixolydian", intervals = { 0, 2, 4, 5, 7, 9, 10 } },
  { name = "Locrian", intervals = { 0, 1, 3, 5, 6, 8, 10 } },
  { name = "Harmonic Major", intervals = { 0, 2, 4, 5, 7, 8, 11 } },
  { name = "Diminished", intervals = { 0, 1, 3, 4, 6, 7, 9, 10 } },
  { name = "Whole Tone", intervals = { 0, 2, 4, 6, 8, 10 } },
  { name = "Hungarian Major", intervals = { 0, 3, 4, 6, 7, 9, 10 } },
  { name = "Hungarian Minor", intervals = { 0, 2, 3, 6, 7, 8, 11 } },
  { name = "Arabic", intervals = { 0, 2, 4, 5, 6, 8, 10 } },
  { name = "Hirajoshi", intervals = { 0, 2, 3, 7, 8 } },
  { name = "Egyptian", intervals = { 0, 2, 3, 6, 7 } },
  { name = "Blues", intervals = { 0, 3, 5, 6, 7, 10 } },
}
Config.ROOT_NOTE_INDEX = 3
Config.SCALE_INDEX = 5
Config.ROOT_HZ = Config.NOTES[Config.ROOT_NOTE_INDEX].hz
Config.BASE_DRONE_HZ = Config.ROOT_HZ
Config.SCALE = Config.SCALES[Config.SCALE_INDEX].intervals

Config.SERIAL_ENABLED = true
Config.SERIAL_DEVICE = "/dev/ttyACM0"
Config.SERIAL_BAUD = 115200
Config.SERIAL_STATE_INTERVAL_S = 0.2
Config.SERIAL_MAX_LINES_PER_TICK = 8
Config.SERIAL_CONNECTION_TIMEOUT_S = 1.5

return Config
