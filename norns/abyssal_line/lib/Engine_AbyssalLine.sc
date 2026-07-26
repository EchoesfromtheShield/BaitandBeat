Engine_AbyssalLine : CroneEngine {
	var drone;
	var layers;

	/*
	Curated Norns-native voice palette informed by SCLOrkSynths categories
	and argument conventions. The full SCLOrkSynths quark is not loaded at
	runtime; seeds choose among lightweight local variants.
	*/

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
			var drift;
			var edgeDrift;
			var padTone;
			var softEdges;
			var shimmer;
			var pad;
			var sub;
			var padCutoff;
			var padRq;
			var deepDamp;
			var fishVoice;
			var fishCutoff;
			var fishRq;
			var tide;
			var padPresence;
			var sig;

			drift = LFNoise1.kr([0.018, 0.023, 0.031, 0.037, 0.043, 0.051]).range(-0.0025, 0.0025);
			edgeDrift = LFNoise1.kr([0.021, 0.029, 0.036, 0.044]).range(-0.0018, 0.0018);
			padTone = SinOsc.ar(
				rootLag * [0.5, 1, 1.5, 2, 3, 4] * (1 + drift),
				0,
				[0.15, 0.24, 0.18, 0.08, 0.035, 0.018]
			);
			softEdges = LFTri.ar(
				rootLag * [0.5, 1, 1.5, 2] * (1 + edgeDrift),
				0,
				[0.045, 0.060, 0.045, 0.025]
			);
			shimmer = SinOsc.ar(
				rootLag * [3, 4, 4.5, 6] * (1 + LFNoise1.kr([0.027, 0.034, 0.041, 0.052]).range(-0.0015, 0.0015)),
				0,
				[0.018, 0.014, 0.010, 0.006] * brightLag * (1 - (depthLag * 0.45))
			);

			pad = Splay.ar(padTone, 0.44 + (depthLag * 0.18), 0.95);
			pad = pad + Splay.ar(softEdges, 0.28, 0.36);
			pad = pad + Splay.ar(shimmer, 0.74, 0.42);
			sub = SinOsc.ar(rootLag * 0.5, 0, 0.08 + pressureLag * 0.05);
			padCutoff = (depthLag.linexp(0, 1, 4200, 620) * (0.88 + brightLag * 0.22 + fishLag * 0.22)).clip(520, 4800);
			padRq = (0.76 - fishLag * 0.08).clip(0.62, 0.82);
			pad = RLPF.ar(pad + (sub ! 2), padCutoff, padRq);
			pad = LPF.ar(pad, padCutoff * 1.15);
			pad = pad * (0.92 + pressureLag * 0.08);

			fishCutoff = (rootLag * fishLag.linexp(0, 1, 5, 70)).clip(240, 9000);
			fishRq = fishLag.linlin(0, 1, 0.50, 0.04).clip(0.04, 0.50);
			fishVoice = LFTri.ar(
				rootLag * 1.5 * [0.997, 1.003],
				0,
				(0.24 + signalLag * 0.35) * fishLag.pow(1.4)
			);
			fishVoice = RLPF.ar(Splay.ar(fishVoice, 0.34), fishCutoff, fishRq);

			tide = SinOsc.kr(0.014 + depthLag * 0.034, [0, pi]).range(0.88, 1);

			padPresence = (signalLag * 0.08) + (fishLag * 0.12);
			sig = (pad * padPresence) + (fishVoice * 1.35);
			sig = LeakDC.ar(sig);
			sig = FreeVerb2.ar(sig[0], sig[1], 0.26 + depthLag * 0.08, 0.88, 0.72);
			deepDamp = depthLag.linexp(0, 1, 6200, 1200).clip(950, 6200);
			sig = LPF.ar(sig, deepDamp * (1 + fishLag * 0.35));
			sig = Limiter.ar(sig * ampLag * tide * 1.18, 0.95, 0.01);
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
			arg out = 0, mode = 0, note = 110, timbre = 0.5, amp = 0.7, pan = 0,
				motion_x = 0, motion_y = 0;

			var safeMode = mode.clip(0, 4);
			var freq = note.clip(28, 3600);
			var color = timbre.clip(0, 1);
			var motionX = motion_x.clip(0, 1);
			var motionY = motion_y.clip(0, 1);
			var isDrum = Select.kr(safeMode, [1, 1, 1, 0, 0]);
			var kickDecay = 0.30 + (color * 0.08) + (motionX * 0.010);
			var kickEnv = Env.perc(0.001, kickDecay, 1, -6).kr;
			var kickPitch = Env.perc(
				0.001,
				0.070 + (color * 0.018),
				58 + (color * 36),
				-7
			).kr;
			var kickBase = 42 + (color * 6);
			var kickClick = LPF.ar(HPF.ar(WhiteNoise.ar(Env.perc(0.001, 0.010).kr * 0.035), 1400), 4200);
			var kick = SinOsc.ar(kickBase + kickPitch, 0, kickEnv * 1.42) +
				LFTri.ar((kickBase + kickPitch) * 0.5, 0, kickEnv * 0.24) +
				kickClick;
			var snareDecay = 0.12 + (color * 0.22);
			var snareEnv = Env.perc(0.001, snareDecay, 1, -4).kr;
			var snareTone = SinOsc.ar(130 + (color * 280), 0, snareEnv * (0.12 + color * 0.20));
			var snareNoise = BPF.ar(
				WhiteNoise.ar(snareEnv * (0.38 + color * 0.32)),
				900 + (color * 2600),
				0.24 + (color * 0.16)
			);
			var snareClap = HPF.ar(DelayC.ar(WhiteNoise.ar(snareEnv * 0.10), 0.022, 0.006 + color * 0.010), 1200);
			var snare = snareNoise + snareTone + snareClap;
			var rimDecay = 0.026 + (color * 0.045);
			var rimEnv = Env.perc(0.001, rimDecay, 1, -8).kr;
			var rim = Ringz.ar(
				BPF.ar(WhiteNoise.ar(rimEnv * (0.10 + color * 0.13)), 1300 + (color * 1800), 0.26),
				(freq * (1.8 + color * 2.8)).clip(260, 4200),
				rimDecay
			);
			var arpOpen = motionX.max(motionY).clip(0, 1);
			var arpRel = 0.035 + (color * 0.10) + (arpOpen * arpOpen * 0.95);
			var arpEnv = Env.perc(0.002 + color * 0.010, arpRel, 1, -4).kr;
			var arpCutoff = (freq * (3.0 + color * 7.0) * (1 + arpOpen * 5.5)).clip(420, 14500);
			var arpPulse = Pulse.ar(freq * [0.997, 1.003], 0.18 + color * 0.36, arpEnv * 0.32).sum;
			var arpFm = SinOsc.ar(freq * 2.0, SinOsc.ar(freq * (3.0 + color * 5.0), 0, 0.8 + color * 1.4), arpEnv * 0.12);
			var arpBell = SinOsc.ar(freq * [1, 2.01, 3.97], 0, [0.14, 0.06, 0.025] * arpEnv).sum;
			var interval = Select.kr((color * 3.999).floor, [1.189207, 1.33484, 1.498307, 1.681793]);
			var arcAtk = 0.22 + (color * 0.48) + (motionX * 0.025);
			var arcSus = 0.65 + (color * 0.95) + (motionX * 1.45);
			var arcRel = 0.42 + (color * 0.80) + (motionX * 0.75);
			var arcEnv = Env.linen(arcAtk, arcSus, arcRel, 1, -3).kr;
			var arcCutoff = (freq * (2.0 + color * 4.0) * (1 + motionY * 0.20)).clip(260, 5200);
			var arcCore = VarSaw.ar(
				freq * [0.5, 0.997, interval * 1.002],
				0,
				SinOsc.kr(2.8 + color * 2.0).range(0.34, 0.62),
				[0.08, 0.18, 0.12] * arcEnv
			).sum;
			var arcAir = BPF.ar(PinkNoise.ar(arcEnv * 0.012), (freq * (5.0 + color * 3.0)).clip(800, 4800), 0.28);
			var lifeRel = Select.kr(safeMode, [kickDecay + 0.08, snareDecay + 0.06, rimDecay + 0.04, arpRel + 0.08, arcAtk + arcSus + arcRel + 0.08]);
			var life = Line.kr(1, 0, lifeRel, doneAction: 2);
			var crushRate = motionY.linexp(0, 1, 22050, 18000);
			var crushMix = motionY * motionY * isDrum * 0.012;
			var verbMix = motionX * isDrum * 0.72;
			var arp;
			var arc;
			var sig;
			var crushed;
			var stereo;
			var drumVerb;

			arp = (arpPulse * (0.88 - color * 0.18)) + (arpFm * (0.10 + color * 0.18)) + (arpBell * (color * 0.24));
			arp = RLPF.ar(arp, arpCutoff, (0.18 + color * 0.12 - arpOpen * 0.08).clip(0.08, 0.30));
			arc = RLPF.ar(arcCore + arcAir, arcCutoff, (0.22 - motionY * 0.010).clip(0.16, 0.30));
			sig = Select.ar(safeMode, [kick, snare, rim, arp, arc]);
			crushed = Latch.ar(sig, Impulse.ar(crushRate));
			sig = (sig * (1 - crushMix)) + (crushed * crushMix);

			sig = LeakDC.ar(sig);
			sig = HPF.ar(sig, 24);
			sig = LPF.ar(sig, Select.kr(safeMode, [6200, 7600, 5200, 9600, 6200]));
			sig = Compander.ar(sig, sig, 0.42, 1, 0.38, 0.002, 0.075);
			sig = sig.tanh;
			sig = Limiter.ar(sig * amp.clip(0, 1.6) * life * Select.kr(safeMode, [2.12, 1.76, 1.55, 0.66, 0.58]), 0.88, 0.01);
			stereo = Pan2.ar(sig, pan.clip(-1, 1));
			drumVerb = FreeVerb2.ar(stereo[0], stereo[1], 0.04 + motionX * 0.46, 0.76, 0.34);
			stereo = (stereo * (1 - (verbMix * 0.34))) + (drumVerb * verbMix * 0.62);
			Out.ar(out, stereo);
		}).add;

		SynthDef(\AbyssalArpEvent, {
			arg out = 0, note = 220, timbre = 0.5, amp = 0.6, pan = 0,
				motion_x = 0, motion_y = 0;

			var freq = note.clip(40, 4200);
			var color = timbre.clip(0, 1);
			var open = motion_x.max(motion_y).clip(0, 1);
			var rel = 0.045 + (color * 0.08) + (open * open * 0.72);
			var atk = 0.002 + (open * 0.018);
			var env = Env.perc(atk, rel, 1, -3).kr(doneAction: 2);
			var width = (0.24 + (color * 0.30) + (open * 0.10)).clip(0.18, 0.62);
			var cutoff = (freq * (2.4 + (color * 4.2) + (open * 13.5))).clip(360, 11800);
			var rq = (0.24 - (open * 0.10) + (color * 0.05)).clip(0.11, 0.30);
			var core = Pulse.ar(freq * [0.997, 1.003], width, 0.16).sum;
			var octave = Pulse.ar(freq * 0.5, width * 0.85, 0.055);
			var air = SinOsc.ar(freq * [2.001, 3.002], 0, [0.018, 0.010] * open).sum;
			var sig = (core + octave + air) * env;
			var level = amp.clip(0, 1.4) * (1 - (open * 0.26));

			sig = RLPF.ar(sig, cutoff, rq);
			sig = LeakDC.ar(sig);
			sig = HPF.ar(sig, 70);
			sig = LPF.ar(sig, 10500);
			sig = sig.tanh;
			sig = Limiter.ar(sig * level * 0.74, 0.72, 0.006);
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
			drone.set(\amp, 0);
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

		this.addCommand(\fish_event, "ifffffff", { arg msg;
			var mode = msg[1].asInteger;

			if(mode == 3, {
				Synth(\AbyssalArpEvent, [
					\note, msg[2].asFloat,
					\timbre, msg[3].asFloat,
					\amp, msg[4].asFloat,
					\pan, msg[5].asFloat,
					\motion_x, msg[6].asFloat,
					\motion_y, msg[7].asFloat
				]);
			}, {
				Synth(\AbyssalFishEvent, [
					\mode, mode,
					\note, msg[2].asFloat,
					\timbre, msg[3].asFloat,
					\amp, msg[4].asFloat,
					\pan, msg[5].asFloat,
					\motion_x, msg[6].asFloat,
					\motion_y, msg[7].asFloat
				]);
			});
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
