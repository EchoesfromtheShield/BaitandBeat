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

			sig = (pad * (1.00 + signalLag * 0.08)) + (fishVoice * 1.05);
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
			var freq = note.clip(28, 5200);
			var timbreLag = timbre.clip(0, 1);
			var motionX = motion_x.clip(0, 1);
			var motionY = motion_y.clip(0, 1);
			var isDrum = Select.kr(safeMode, [1, 1, 1, 0, 0]);
			var voiceFamily = (timbreLag * 7.999).floor;
			var color = ((timbreLag * 8) - voiceFamily).clip(0, 1);
			var drumFamily = voiceFamily;
			var arpFamily = voiceFamily;
			var arcFamily = voiceFamily;
			var kickBase = Select.kr(drumFamily, [34, 40, 45, 52, 58, 66, 72, 86]);
			var kickDecay = Select.kr(drumFamily, [0.16, 0.22, 0.30, 0.38, 0.48, 0.24, 0.34, 0.52]) + (motionX * 0.08);
			var kickEnv = Env.perc(0.001, kickDecay, 1, -6).kr;
			var kickPitch = Env.perc(
				0.001,
				Select.kr(drumFamily, [0.032, 0.046, 0.060, 0.082, 0.115, 0.050, 0.075, 0.135]),
				Select.kr(drumFamily, [34, 48, 64, 82, 118, 96, 142, 176]),
				-7
			).kr;
			var kickClick = HPF.ar(ClipNoise.ar(Env.perc(0.001, 0.008 + color * 0.020).kr * (0.08 + color * 0.36)), 1100 + color * 4200);
			var kickBody = Select.ar(
				drumFamily,
				[
					SinOsc.ar(kickBase + kickPitch, 0, kickEnv * 1.35),
					SinOsc.ar(kickBase + kickPitch, 0, kickEnv * 1.12) + LFTri.ar((kickBase + kickPitch) * 0.5, 0, kickEnv * 0.18),
					SinOsc.ar(kickBase + kickPitch, 0, kickEnv * 0.92) + BPF.ar(ClipNoise.ar(kickEnv * 0.22), 900, 0.42),
					LFTri.ar(kickBase + kickPitch, 0, kickEnv * 1.05),
					Pulse.ar(kickBase + kickPitch, 0.42, kickEnv * 0.65),
					SinOsc.ar(kickBase + kickPitch, 0, kickEnv * 0.88) + Ringz.ar(ClipNoise.ar(kickEnv * 0.08), kickBase * 2.8, 0.12),
					SinOsc.ar(kickBase + kickPitch, 0, kickEnv * 0.70) + RLPF.ar(Saw.ar((kickBase + kickPitch) * 0.5, kickEnv * 0.22), 620, 0.2),
					LFTri.ar(kickBase + kickPitch, 0, kickEnv * 0.86) + BPF.ar(ClipNoise.ar(kickEnv * 0.28), 2600, 0.18)
				]
			);
			var kick = kickBody + kickClick;
			var snareDecay = Select.kr(drumFamily, [0.11, 0.16, 0.22, 0.30, 0.40, 0.18, 0.26, 0.36]);
			var snareEnv = Env.perc(0.001, snareDecay, 1, -4).kr;
			var snareTone = SinOsc.ar(Select.kr(drumFamily, [105, 145, 190, 245, 310, 370, 430, 520]), 0, snareEnv * (0.10 + color * 0.34));
			var snareNoise = BPF.ar(
				WhiteNoise.ar(snareEnv * (0.58 + color * 0.90)),
				Select.kr(drumFamily, [760, 1150, 1700, 2450, 3600, 5100, 2950, 980]),
				Select.kr(drumFamily, [0.18, 0.26, 0.36, 0.52, 0.20, 0.14, 0.42, 0.30])
			);
			var snareClap = HPF.ar(DelayC.ar(WhiteNoise.ar(snareEnv * 0.30), 0.035, Select.kr(drumFamily, [0.006, 0.010, 0.014, 0.018, 0.024, 0.030, 0.012, 0.020])), 1200);
			var snare = snareNoise + snareTone + snareClap;
			var rimDecay = Select.kr(drumFamily, [0.026, 0.040, 0.055, 0.074, 0.105, 0.135, 0.052, 0.088]);
			var rimEnv = Env.perc(0.001, rimDecay, 1, -8).kr;
			var rim = Ringz.ar(
				ClipNoise.ar(rimEnv * (0.20 + color * 0.44)),
				freq * Select.kr(drumFamily, [1.7, 2.4, 3.2, 4.5, 5.8, 7.2, 9.0, 11.0]),
				rimDecay
			);
			var arpRel = Select.kr(arpFamily, [0.07, 0.11, 0.16, 0.24, 0.34, 0.48, 0.19, 0.28]) + (motionX * 0.52);
			var arpEnv = Env.perc(0.002 + color * 0.010, arpRel, 1, -4).kr;
			var arpCutoff = (freq * Select.kr(arpFamily, [3.4, 5.4, 7.8, 10.5, 14.0, 18.0, 22.0, 8.6]) * (1 + motionY * 2.3)).clip(420, 15000);
			var arpPulse = Pulse.ar(
				freq * [0.996, 1.004],
				Select.kr(arpFamily, [0.18, 0.25, 0.34, 0.45, 0.56, 0.68, 0.40, 0.52]),
				arpEnv * 0.27
			).sum;
			var arpSaw = VarSaw.ar(freq * [0.992, 1.008], 0, 0.22 + color * 0.46, arpEnv * 0.20).sum;
			var arpTri = LFTri.ar(freq * [0.5, 1.002, 2.01], 0, [0.10, 0.22, 0.08] * arpEnv).sum;
			var arpSin = SinOsc.ar(freq * [1, 1.5, 2], 0, [0.23, 0.08, 0.05] * arpEnv).sum;
			var arpFm = SinOsc.ar(freq * 2.0, SinOsc.ar(freq * (4.8 + color * 9.0), 0, 1.4 + color * 3.2), arpEnv * 0.28);
			var arpBell = SinOsc.ar(freq * [1, 2.01, 3.97, 6.05], 0, [0.22, 0.13, 0.07, 0.035] * arpEnv).sum;
			var arpClav = RHPF.ar(Pulse.ar(freq * [0.5, 1, 2.005], 0.22 + color * 0.25, arpEnv * [0.10, 0.23, 0.08]).sum, freq * 5.5, 0.35);
			var interval = Select.kr(arcFamily, [1.122462, 1.189207, 1.259921, 1.33484, 1.498307, 1.681793, 1.781797, 2.0]);
			var arcAtk = Select.kr(arcFamily, [0.18, 0.30, 0.46, 0.64, 0.82, 1.05, 0.54, 0.72]) + motionX * 0.16;
			var arcSus = Select.kr(arcFamily, [0.70, 0.95, 1.25, 1.60, 2.05, 2.45, 1.85, 2.20]);
			var arcRel = Select.kr(arcFamily, [0.45, 0.65, 0.92, 1.25, 1.60, 1.95, 2.30, 1.40]);
			var arcEnv = Env.linen(arcAtk, arcSus, arcRel, 1, -3).kr;
			var arcCutoff = (freq * Select.kr(arcFamily, [1.7, 2.2, 3.1, 4.2, 5.8, 7.4, 9.2, 3.6]) * (1 + motionY * 1.9)).clip(240, 11000);
			var arcA = LFTri.ar(freq * [0.5, 1, interval], 0, [0.12, 0.30, 0.22] * arcEnv).sum;
			var arcB = VarSaw.ar(freq * [0.997, interval * 1.003], 0, 0.26 + color * 0.30, [0.32, 0.22] * arcEnv).sum;
			var arcC = (Pulse.ar(freq * [1, interval], 0.44, [0.18, 0.14] * arcEnv).sum) + BPF.ar(WhiteNoise.ar(arcEnv * 0.045), freq * 8, 0.12);
			var arcD = SinOsc.ar(freq * [1, 1.5, interval, 2], 0, [0.20, 0.08, 0.20, 0.05] * arcEnv).sum + Saw.ar(freq * 0.5, arcEnv * 0.055);
			var arcE = RLPF.ar(Saw.ar(freq * [0.5, 0.997, interval * 1.002], [0.07, 0.20, 0.13] * arcEnv).sum, arcCutoff * 0.72, 0.20);
			var arcF = SinOsc.ar(freq * [0.5, 1, interval, interval * 2], 0, [0.18, 0.20, 0.16, 0.06] * arcEnv).sum + CombC.ar(WhiteNoise.ar(arcEnv * 0.018), 0.08, (1 / freq).clip(0.001, 0.08), 0.7 + color);
			var arcG = VarSaw.ar(freq * [1, 1.005, interval], 0, SinOsc.kr(4.0 + color * 3.0).range(0.28, 0.72), [0.16, 0.15, 0.13] * arcEnv).sum + BPF.ar(ClipNoise.ar(arcEnv * 0.030), 2400 + color * 2600, 0.22);
			var arcH = LFTri.ar(freq * [0.5, 0.75, 1, interval], 0, [0.08, 0.07, 0.22, 0.18] * arcEnv).sum;
			var lifeRel = Select.kr(safeMode, [kickDecay + 0.08, snareDecay + 0.06, rimDecay + 0.04, arpRel + 0.08, arcAtk + arcSus + arcRel + 0.08]);
			var life = Line.kr(1, 0, lifeRel, doneAction: 2);
			var crushRate = motionY.linexp(0, 1, 18000, 3800);
			var crushMix = motionY * isDrum;
			var verbMix = motionX * isDrum;
			var arp;
			var arc;
			var sig;
			var crushed;
			var stereo;
			var drumVerb;

			arp = Select.ar(arpFamily, [arpPulse, arpSaw, arpTri, arpSin, arpFm, arpBell, arpClav, (arpPulse * 0.55) + (arpSaw * 0.42) + (arpFm * 0.36)]);
			arp = RLPF.ar(arp, arpCutoff, (Select.kr(arpFamily, [0.10, 0.14, 0.22, 0.08, 0.18, 0.12, 0.30, 0.16]) - motionY * 0.045).clip(0.04, 0.45));
			arc = Select.ar(arcFamily, [arcA, arcB, arcC, arcD, arcE, arcF, arcG, arcH]);
			arc = RLPF.ar(arc, arcCutoff, (Select.kr(arcFamily, [0.16, 0.22, 0.34, 0.12, 0.20, 0.28, 0.18, 0.26]) - motionY * 0.06).clip(0.05, 0.60));
			sig = Select.ar(safeMode, [kick, snare, rim, arp, arc]);
			crushed = Latch.ar(sig, Impulse.ar(crushRate));
			sig = (sig * (1 - crushMix)) + (crushed * crushMix);

			sig = LeakDC.ar(sig);
			sig = Limiter.ar(sig * amp.clip(0, 2.4) * life * 1.6, 0.95, 0.004);
			stereo = Pan2.ar(sig, pan.clip(-1, 1));
			drumVerb = FreeVerb2.ar(stereo[0], stereo[1], 0.08 + motionX * 0.48, 0.76, 0.32);
			stereo = (stereo * (1 - (verbMix * 0.42))) + (drumVerb * verbMix * 0.62);
			Out.ar(out, stereo);
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
			Synth(\AbyssalFishEvent, [
				\mode, msg[1].asInteger,
				\note, msg[2].asFloat,
				\timbre, msg[3].asFloat,
				\amp, msg[4].asFloat,
				\pan, msg[5].asFloat,
				\motion_x, msg[6].asFloat,
				\motion_y, msg[7].asFloat
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
