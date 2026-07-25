Engine_AbyssalLine : CroneEngine {
	var drone;
	var layers;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		SynthDef(\AbyssalDrone, {
			arg out = 0, root = 55, depth = 0, brightness = 0.5,
				pressure = 0, signal = 0, fish = 0, amp = 0;

			var rootLag = root.lag3(0.35).clip(20, 220);
			var depthLag = depth.lag3(0.75).clip(0, 1);
			var brightLag = brightness.lag3(0.9).clip(0, 1);
			var pressureLag = pressure.lag3(1.2).clip(0, 1);
			var signalLag = signal.lag3(0.35).clip(0, 1);
			var fishLag = fish.lag3(0.18).clip(0, 1);
			var ampLag = amp.lag3(1.8).clip(0, 1.6);
			var unison;
			var supersaw;
			var sub;
			var padCutoff;
			var padRq;
			var fishVoice;
			var fishCutoff;
			var fishRq;
			var water;
			var tide;
			var sig;

			unison = depthLag.linlin(0, 1, 0.004, 0.045);
			supersaw = Saw.ar(
				rootLag * [0.5, 0.5, 1, 1, 1.189207, 1.189207, 1.498307, 1.498307, 2, 2] *
					(1 + ([-2.1, 1.8, -1.4, 1.2, -0.9, 0.78, -0.55, 0.48, -0.24, 0.21] * unison)),
				[0.30, 0.30, 0.42, 0.42, 0.24, 0.24, 0.18, 0.18, 0.08, 0.08]
			);

			supersaw = Splay.ar(supersaw, 0.34 + (depthLag * 0.34), 1.05);
			sub = SinOsc.ar(rootLag * 0.5, 0, 0.18 + pressureLag * 0.08);
			padCutoff = (brightLag.linexp(0, 1, 620, 5600) * (1 + depthLag * 0.22)).clip(420, 6200);
			padRq = (0.42 - signalLag * 0.08).clip(0.24, 0.48);
			supersaw = RLPF.ar(supersaw + (sub ! 2), padCutoff, padRq);
			supersaw = LPF.ar(supersaw, padCutoff * 1.08);
			supersaw = (supersaw * (1.12 + depthLag * 0.22)).tanh;

			fishCutoff = (rootLag * fishLag.linexp(0, 1, 5, 70)).clip(240, 9000);
			fishRq = fishLag.linlin(0, 1, 0.50, 0.04).clip(0.04, 0.50);
			fishVoice = LFTri.ar(
				rootLag * 1.5 * [0.997, 1.003],
				0,
				(0.24 + signalLag * 0.35) * fishLag.pow(1.4)
			);
			fishVoice = RLPF.ar(Splay.ar(fishVoice, 0.34), fishCutoff, fishRq);

			water = LPF.ar(PinkNoise.ar(0.0005 + pressureLag * 0.0012), 520 + depthLag * 420);
			tide = SinOsc.kr(0.018 + depthLag * 0.045, [0, pi]).range(0.84, 1);

			sig = (supersaw * (1.22 + signalLag * 0.12)) + (fishVoice * 1.18) + (water ! 2);
			sig = LeakDC.ar(sig);
			sig = FreeVerb2.ar(sig[0], sig[1], 0.17 + depthLag * 0.07, 0.64, 0.22);
			sig = Limiter.ar(sig * ampLag * tide * 2.35, 0.95, 0.01);
			Out.ar(out, sig);
		}).add;

		SynthDef(\AbyssalStrike, {
			arg out = 0, kind = 0, note = 110, pull = 0, tension = 0, pan = 0;

			var safeKind = kind.clip(0, 3);
			var rel = Select.kr(safeKind, [0.18, 0.65, 0.055, 0.10]);
			var atk = Select.kr(safeKind, [0.002, 0.006, 0.001, 0.001]);
			var toneAmp = Select.kr(safeKind, [1.0, 1.2, 0.78, 0.55]);
			var clickAmp = Select.kr(safeKind, [0.28, 0.12, 0.60, 0.45]);
			var freq = note.clip(28, 5200);
			var pitchEnv = Env.perc(0.001, 0.05, 0.07 + tension.clip(0, 1) * 0.08, -5).kr;
			var env = Env.perc(atk, rel, 1, -4).kr(doneAction: 2);
			var clickEnv = Env.perc(0.001, 0.018, 1, -7).kr;
			var knockEnv = Env.perc(0.001, 0.08 + pull.clip(0, 1) * 0.15, 1, -5).kr;
			var sweptFreq = (freq * (1 + pitchEnv)).clip(24, 6200);
			var tone = (
				Pulse.ar(sweptFreq, 0.48, 0.38) +
				SinOsc.ar(sweptFreq, 0, 0.42) +
				LFTri.ar(sweptFreq * 0.5, 0, 0.36)
			) * toneAmp;
			var knock = SinOsc.ar((freq * 0.25).clip(30, 180), 0, knockEnv * 1.15);
			var click = HPF.ar(WhiteNoise.ar(clickEnv * clickAmp * (1 + tension.clip(0, 1))), 1600);
			var body = RLPF.ar(
				tone + knock,
				(sweptFreq * (3.5 + tension.clip(0, 1) * 10.0)).clip(180, 14000),
				0.11
			);
			var amp = 0.42 + pull.clip(0, 1) * 0.26 + tension.clip(0, 1) * 0.38;
			var sig = Limiter.ar(((body * env * amp) + (click * 1.4)) * 2.1, 0.95, 0.004);

			Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)));
		}).add;

		SynthDef(\AbyssalFishEvent, {
			arg out = 0, mode = 0, note = 110, timbre = 0.5, amp = 0.7, pan = 0;

			var safeMode = mode.clip(0, 4);
			var freq = note.clip(28, 5200);
			var timbreLag = timbre.clip(0, 1);
			var lifeRel = Select.kr(safeMode, [0.45, 0.34, 0.18, 0.52, 3.1]);
			var life = Line.kr(1, 0, lifeRel, doneAction: 2);
			var kickEnv = Env.perc(0.001, 0.30, 1, -6).kr;
			var kickPitch = Env.perc(0.001, 0.075, 58 + timbreLag * 44, -7).kr;
			var kickClick = HPF.ar(WhiteNoise.ar(Env.perc(0.001, 0.014).kr * 0.22), 1800);
			var kick = SinOsc.ar(42 + kickPitch, 0, kickEnv * 1.35) + kickClick;
			var snareEnv = Env.perc(0.001, 0.22 + timbreLag * 0.10, 1, -4).kr;
			var snareTone = SinOsc.ar(150 + timbreLag * 70, 0, snareEnv * 0.24);
			var snare = BPF.ar(WhiteNoise.ar(snareEnv * 1.0), 1700 + timbreLag * 2400, 0.45) + snareTone;
			var rimEnv = Env.perc(0.001, 0.075, 1, -8).kr;
			var rim = Ringz.ar(WhiteNoise.ar(rimEnv * 0.42), freq * (2.8 + timbreLag * 2.6), 0.045 + timbreLag * 0.045);
			var arpEnv = Env.perc(0.003, 0.24 + timbreLag * 0.16, 1, -4).kr;
			var interval = Select.kr((timbreLag * 3.999).floor, [1.189207, 1.33484, 1.498307, 1.781797]);
			var arcEnv = Env.linen(0.42 + timbreLag * 0.35, 1.25, 0.90, 1, -3).kr;
			var arp;
			var arc;
			var sig;

			arp = Pulse.ar(freq * [0.997, 1.003], 0.42 + timbreLag * 0.18, arpEnv * 0.36).sum;
			arp = RLPF.ar(arp, (freq * (5 + timbreLag * 16)).clip(800, 14000), 0.10 + timbreLag * 0.12);
			arc = (
				LFTri.ar(freq, 0, 0.34) +
				LFTri.ar(freq * interval, 0, 0.24) +
				Saw.ar(freq * 0.5, 0.10)
			) * arcEnv;
			arc = RLPF.ar(arc, (freq * (2.2 + timbreLag * 7)).clip(450, 9000), 0.18);
			sig = Select.ar(safeMode, [kick, snare, rim, arp, arc]);

			sig = LeakDC.ar(sig);
			sig = Limiter.ar(sig * amp.clip(0, 2.4) * life * 1.6, 0.95, 0.004);
			Out.ar(out, Pan2.ar(sig, pan.clip(-1, 1)));
		}).add;

		SynthDef(\AbyssalLayer, {
			arg out = 0, gate = 1, layer = 0, root = 55, rate = 0.3,
				texture = 0.4, amp = 0.1, pan = 0;

			var safeLayer = layer.clip(0, 2);
			var base = root * Select.kr(safeLayer, [0.5, 1, 1.5]);
			var trig = Dust.kr(rate.clip(0.05, 3.5)) + Impulse.kr((rate * 0.33).clip(0.03, 1.5));
			var ratio = Demand.kr(trig, 0, Dseq([1, 1.189207, 1.33484, 1.498307, 1.781797, 2], inf));
			var env = Decay2.kr(trig, 0.01, 0.18 + texture.clip(0, 1) * 1.1);
			var tick = HPF.ar(WhiteNoise.ar(Decay2.kr(trig, 0.001, 0.026) * (0.035 + texture * 0.06)), 1600);
			var freq = (base * ratio * (1 + LFNoise1.kr(0.08) * 0.01)).clip(24, 4800);
			var tone = SinOsc.ar(freq * [1, 1.004], 0, env * 0.62).sum;
			var haze = BPF.ar(PinkNoise.ar(env * texture.clip(0, 1) * 0.13), freq * 2.1, 0.18);
			var body = RLPF.ar(tone + haze + tick, (freq * (2.0 + texture * 3.0)).clip(120, 8000), 0.21);
			var voiceEnv = Env.asr(2.0, 1, 3.0).kr(gate: gate, doneAction: 2);

			Out.ar(out, Pan2.ar(body * amp.clip(0, 0.8) * voiceEnv * 2.0, pan.clip(-1, 1)));
		}).add;

		Server.default.sync;

		layers = Array.fill(3, { nil });
		drone = Synth(\AbyssalDrone, [\amp, 0]);

		this.addCommand(\start, "", {
			drone.set(\amp, 0.85);
		});

		this.addCommand(\stop, "", {
			drone.set(\amp, 0);
		});

		this.addCommand(\drone, "fffffff", { arg msg;
			drone.set(
				\root, msg[1].asFloat,
				\depth, msg[2].asFloat,
				\brightness, msg[3].asFloat,
				\pressure, msg[4].asFloat,
				\signal, msg[5].asFloat,
				\fish, msg[6].asFloat,
				\amp, msg[7].asFloat
			);
		});

		this.addCommand(\strike, "iffff", { arg msg;
			Synth(\AbyssalStrike, [
				\kind, msg[1].asInteger,
				\note, msg[2].asFloat,
				\pull, msg[3].asFloat,
				\tension, msg[4].asFloat,
				\pan, msg[5].asFloat
			]);
		});

		this.addCommand(\fish_event, "iffff", { arg msg;
			Synth(\AbyssalFishEvent, [
				\mode, msg[1].asInteger,
				\note, msg[2].asFloat,
				\timbre, msg[3].asFloat,
				\amp, msg[4].asFloat,
				\pan, msg[5].asFloat
			]);
		});

		this.addCommand(\capture_layer, "ifffff", { arg msg;
			var index = msg[1].asInteger.clip(1, 3) - 1;
			layers[index].notNil.if({
				layers[index].set(\gate, 0);
			});

			layers[index] = Synth(\AbyssalLayer, [
				\layer, index,
				\root, msg[2].asFloat,
				\rate, msg[3].asFloat,
				\texture, msg[4].asFloat,
				\pan, msg[5].asFloat,
				\amp, msg[6].asFloat
			]);
		});

		this.addCommand(\clear_layers, "", {
			layers.do({ arg layerSynth;
				layerSynth.notNil.if({
					layerSynth.set(\gate, 0);
				});
			});
			layers = Array.fill(3, { nil });
		});
	}

	free {
		drone.notNil.if({
			drone.free;
		});

		layers.do({ arg layerSynth;
			layerSynth.notNil.if({
				layerSynth.set(\gate, 0);
			});
		});
	}
}
