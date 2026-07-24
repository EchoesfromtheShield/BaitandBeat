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

			var rootLag = root.lag3(0.8).clip(20, 220);
			var depthLag = depth.lag3(1.4).clip(0, 1);
			var brightLag = brightness.lag3(0.9).clip(0, 1);
			var pressureLag = pressure.lag3(1.2).clip(0, 1);
			var signalLag = signal.lag3(0.35).clip(0, 1);
			var fishLag = fish.lag3(0.18).clip(0, 1);
			var ampLag = amp.lag3(1.6).clip(0, 0.6);
			var partials;
			var droneMix;
			var fifth;
			var water;
			var cutoff;
			var rq;
			var tide;
			var sig;

			partials = SinOsc.ar(
				rootLag * [0.5, 1, 1.5007, 2.003] *
					(1 + LFNoise1.kr([0.031, 0.043, 0.057, 0.071]) * (0.003 + depthLag * 0.006)),
				0,
				[0.34, 0.26, 0.13, 0.08]
			);

			droneMix = Splay.ar(partials, 0.65);
			fifth = SinOsc.ar(rootLag * [1.498, 1.502], 0, fishLag * (0.035 + signalLag * 0.08));
			water = BPF.ar(
				PinkNoise.ar(0.05 + pressureLag * 0.08),
				(rootLag * (1.4 + depthLag * 5.8)).clip(60, 2600),
				0.12 + (1 - brightLag) * 0.25
			);

			cutoff = brightLag.linexp(0, 1, 220, 5800) * (1 + signalLag * 0.45);
			rq = (0.34 - pressureLag * 0.18).clip(0.09, 0.34);
			tide = SinOsc.kr(0.025 + depthLag * 0.09, [0, pi]).range(0.72, 1);

			sig = droneMix + fifth + (water ! 2);
			sig = RLPF.ar(sig, cutoff.clip(120, 9000), rq);
			sig = LeakDC.ar(sig);
			sig = FreeVerb2.ar(sig[0], sig[1], 0.18 + depthLag * 0.22, 0.72, 0.35);
			sig = Limiter.ar(sig * ampLag * tide, 0.82, 0.01);
			Out.ar(out, sig);
		}).add;

		SynthDef(\AbyssalStrike, {
			arg out = 0, kind = 0, root = 55, pull = 0, tension = 0, pan = 0;

			var safeKind = kind.clip(0, 3);
			var ratio = Select.kr(safeKind, [2.0, 0.75, 3.0, 1.5]);
			var rel = Select.kr(safeKind, [0.16, 0.95, 0.08, 0.38]);
			var freq = (root * ratio * (1 + tension.clip(0, 1) * 0.025)).clip(24, 5200);
			var env = Env.perc(0.002, rel, 1, -4).kr(doneAction: 2);
			var tone = SinOsc.ar(freq * [0.997, 1.003], 0, 0.42).sum;
			var edge = HPF.ar(WhiteNoise.ar(tension.clip(0, 1) * 0.08), 1400);
			var body = RLPF.ar(tone + edge, (freq * (1.8 + tension * 5.5)).clip(80, 9000), 0.18);
			var amp = 0.045 + pull.clip(0, 1) * 0.045 + tension.clip(0, 1) * 0.13;

			Out.ar(out, Pan2.ar(body * env * amp, pan.clip(-1, 1)));
		}).add;

		SynthDef(\AbyssalLayer, {
			arg out = 0, gate = 1, layer = 0, root = 55, rate = 0.3,
				texture = 0.4, amp = 0.1, pan = 0;

			var safeLayer = layer.clip(0, 2);
			var base = root * Select.kr(safeLayer, [0.5, 1, 1.5]);
			var trig = Dust.kr(rate.clip(0.05, 3.5)) + Impulse.kr((rate * 0.33).clip(0.03, 1.5));
			var ratio = Demand.kr(trig, 0, Dseq([1, 1.5, 2, 1.25, 0.75, 1.5], inf));
			var env = Decay2.kr(trig, 0.01, 0.18 + texture.clip(0, 1) * 1.1);
			var freq = (base * ratio * (1 + LFNoise1.kr(0.08) * 0.01)).clip(24, 4800);
			var tone = SinOsc.ar(freq * [1, 1.004], 0, env * 0.48).sum;
			var haze = BPF.ar(PinkNoise.ar(env * texture.clip(0, 1) * 0.13), freq * 2.1, 0.18);
			var body = RLPF.ar(tone + haze, (freq * (2.0 + texture * 3.0)).clip(120, 8000), 0.21);
			var voiceEnv = Env.asr(2.0, 1, 3.0).kr(gate: gate, doneAction: 2);

			Out.ar(out, Pan2.ar(body * amp.clip(0, 0.24) * voiceEnv, pan.clip(-1, 1)));
		}).add;

		Server.default.sync;

		layers = Array.fill(3, { nil });
		drone = Synth(\AbyssalDrone, [\amp, 0]);

		this.addCommand(\start, "", {
			drone.set(\amp, 0.22);
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
				\root, msg[2].asFloat,
				\pull, msg[3].asFloat,
				\tension, msg[4].asFloat,
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
