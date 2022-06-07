

Server.killAll


(
s.scope; // plotting the wave in time domain
FreqScope.new; // ploting the spectogram
a
)
//////////////////3 voices with 6 reagions Harmonizer (4th, 5th, minor 7th)///////////////////////////////////

(
{
	//#1 ======INITIALIZE SC SERVER ======
	//if server fails to start and error encountered:  try, try again...it's stubborn sometimes...
	o = Server.local.options;
	o.sampleRate = 48000;
	o.blockSize = 32;
	o.outDevice =  "ASIO : UMC ASIO Driver";
	o.inDevice = "ASIO : UMC ASIO Driver";
	s.latency = 0.001; //0.2 is SC default
	s.boot;
	postln("Server section.");
}.defer(1);

//ServerOptions.devices;
//ServerOptions.inDevices;
//ServerOptions.outDevices;




///////////////////////////////////// MODEL ////////////////////////////////////////////////////


//////SYNTHS///////
s.waitForBoot{
	{
		postln("Synth section.");
		SynthDef.new(\voiceTracker, {
			|
			outputBus, outFreqBus, outMidi
			|

			var in, amp, freq, hasFreq, out;
			var midiFundamental;
			var inputAmp,threshhold,gate;


			in = Mix.new(SoundIn.ar([0,1]));

			/////////////Noise-Gate//////////////
			inputAmp = Amplitude.kr(in);//traking the input amplitude
			threshhold = 0.02;	// noise gating threshold
			gate = Lag.kr(inputAmp > threshhold, 0.01);// using Lag to smoothing out control signals.
			in= in*gate;

			//PithTraking
			# freq, hasFreq = Tartini.kr(in);
			//midiFundamental = freq.cpsmidi;


			//Out.kr(outMidi, midiFundamental);
			Out.kr(outFreqBus, freq);
			Out.ar(outputBus, in);
		}).send(s);

		SynthDef.new(\harmonizer, {
			|
			inputBus, inFreqBus, inMidi
			outHarmBus, outVoiceBus
			buffer1, buffer2, buffer3
			amph = 1, ampv = 1, amphmidi = 1
			amp4Up = 1, amp5Up = 1, amp7Up = 1, amp4Low = 1, amp5Low = 1, amp7Low=1
			pitch1 = 4, pitch2 = 7, pitch3 = 12
			high_low_mix = 0
			|

			var in = In.ar(inputBus, 1);
			var voice, harmonics;
			var fundamental, inFreq, out;
			var fourthUp, fifthUp, sevenUp, fourthLow, fifthLow, sevenLow;
			var scaleArray;
			var harmonic1 = 4, harmonic2 = 5, harmonic3 = 7;
			var pitch = 0;
			var p1 = 0, p2 = 0, p3 = 0;
			var grains = 2;
			var high_harm, low_harm;


			////////////// Fixed harmony ///////////////

			fourthUp = amp4Up * PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(pitch1), (2.pow(1/12)).pow(pitch1), grainsPeriod: 2);
			fifthUp = amp5Up * PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(pitch2), (2.pow(1/12)).pow(pitch2), grainsPeriod: 2);
			sevenUp = amp7Up * PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(pitch3), (2.pow(1/12)).pow(pitch3), grainsPeriod: 2);

			fourthLow = amp4Low * PitchShiftPA.ar(in, inFreqBus, 0.5*(2.pow(1/12)).pow(pitch1), 0.5*(2.pow(1/12)).pow(pitch1), grainsPeriod: 4);
			fifthLow = amp5Low * PitchShiftPA.ar(in, inFreqBus, 0.5*(2.pow(1/12)).pow(pitch2), 0.5*(2.pow(1/12)).pow(pitch2), grainsPeriod: 4);
			sevenLow = amp7Low  * PitchShiftPA.ar(in, inFreqBus, 0.5*(2.pow(1/12)).pow(pitch3), 0.5*(2.pow(1/12)).pow(pitch3), grainsPeriod: 2);

			high_harm = Mix.new([fourthUp, fifthUp, sevenUp]);
			low_harm = Mix.new([fourthLow, fifthLow, sevenLow]);

			//harmonics = Mix.new([fourthUp, fifthUp, sevenUp, fourthLow, fifthLow, sevenLow]);

			harmonics = amphmidi * XFade2.ar(low_harm, high_harm, high_low_mix);

			Out.ar(outVoiceBus, ampv * in);
			Out.ar(outHarmBus, amph * harmonics);
		}).send(s);

		/////////////////////////////////////////////////FINAL MIX/////////////////////////////////////////////

		SynthDef.new(\finalSum, {
			|
			inputVoiceBus, inputHarmBus, outputBus, mix = -0.5
			|

			var input, harmonics;
			var out;

			var add;
			var delay;
			var mixDelayed;

			input = In.ar(inputVoiceBus, 1);
			harmonics = In.ar(inputHarmBus, 1);


			out = Mix.new([input, harmonics]);

			Out.ar(outputBus, out);
		}).send(s);



		/////////////////////////////////Effects///////////////////////////////

		//// Check the effect in parallel instead of in Cascade
		SynthDef(\delayEffect, {
			|
			inputBus, outputBus, mix= 0.5, delTime=0.5, decay=2 //wetD = 0.5
			|
			var in, delay, mixDelayed,  maxDelTime=2;

			in = In.ar(inputBus);
			delay = CombL.ar(in, maxDelTime, delTime, decay);
			//sig = Mix([sig*(1-wetD), delay*wetD]);
			mixDelayed = XFade2.ar(delay, in, mix);

			Out.ar(outputBus,mixDelayed);
		}).send(s);


		SynthDef.new(\reverbEffect, {
			|
			inputBus, outputBus, wetR = 0.5, revTime= 4
			|

			// room size
			var source;
			var reverb;
			var mixReverbed;
			var dry;
			var highPassedSource;

			dry = 1 - wetR;
			source = In.ar(inputBus, 1);
			highPassedSource= HPF.ar(source,100); // first apply an high pass filter to the  input signal to make the reverbered sound more realistic
			//reverb = GVerb.ar(source, 20, 6, 0.5, 1, 100, dry, 0.5, 0.4);
			reverb = GVerb.ar( highPassedSource , 15,revTime, 0.5, 1, 20, dry, 0.4, 0.3);

			//mixReverbed = (reverb * wetR) + source * (1 - wetR);

			mixReverbed = Mix([source*(1-wetR), reverb*wetR]);


			Out.ar(outputBus, mixReverbed);
		}).send(s);


		//////////////////////////////////Mixing the output/////////////////

		SynthDef.new(\finalMix,{
			|
			inputSignalBus, inputRevBus, inputDelBus, delFaider= 0.5, revFader= 0.5
			|

			var signal, rev, del,finalMix;

			signal= In.ar(inputSignalBus,1);
			rev= In.ar(inputRevBus,1);
			del= In.ar(inputDelBus,1);

			finalMix= Mix.ar([signal, revFader*rev, delFaider*del]);

			Out.ar([0,1], finalMix);

		}).send(s);
	}.defer(2);
	////////////////////////////////BUSES///////////////////

	{
		postln("Buses section.");
		// create the busses
		~trackerOut = Bus.audio(s, 1);
		~harmonizerVoice = Bus.audio(s, 1);
		~harmonizerHarm = Bus.audio(s, 1);

		~delBus = Bus.audio(s, 1);
		~revBus = Bus.audio(s, 1);

		~finalBus = Bus.audio(s, 1);

		// this bus contains the frequency of the note sung by the user
		~fundamentalBus = Bus.control(s, 1);
		~midiFundamental = Bus.control(s, 1);

		// Create the groups
		~inputGroup = Group.new;
		~harmonizerGroup = Group.after(~inputGroup);
		~effectsGroup = Group.after(~harmonizerGroup);
		~outputGroup = Group.after(~effectsGroup);

		// instances of the various model Synth
		~harmonizer = Synth.new(\harmonizer, [\inputBus, ~trackerOut, \inFreqBus, ~fundamentalBus, \outVoiceBus, ~harmonizerVoice, \outHarmBus, ~harmonizerHarm], ~harmonizerGroup);

		~finalSum = Synth.after(~harmonizer, \finalSum, [\inputVoiceBus, ~harmonizerVoice, \inputHarmBus, ~harmonizerHarm, \outputBus, ~finalBus], ~harmonizerGroup);

		~dl = Synth.new(\delayEffect, [\inputBus, ~finalBus, \outputBus, ~delBus], ~effectsGroup);

		~rev = Synth.after(~dl,\reverbEffect, [\inputBus, ~finalBus, \outputBus, ~revBus], ~effectsGroup);

		~finalMix= Synth.new(\finalMix,[\inputSignalBus,~finalBus, \inputRevBus,~revBus, \inputDelBus, ~delBus], ~outputGroup);

		~onOff = 0;
		~onOffHarm = 1;

	}.defer(5);
	//****************************************MIDI SETUP*******************************************/

	//Istantiation of the Midi keyboard for a monophonic synthetizer

	{
		postln("MIDI section.");
		MIDIClient.init; // connects to the operating system's MIDI layer, print the lists of available MIDI sources and destinations.
		MIDIIn.connectAll;
		NetAddr("127.0.0.1",57120);

		MIDIdef.cc(\firstKnob,{
			arg val, num, chan, src;
			[val/127,chan].postln;
			//~revDryWetKnob.set();
			~rev.set(\wetR, val/127);
			//postln("the rev dryWet: " + val/127);
		}, ccNum: 1, chan: 0);

		MIDIdef.noteOn(\firstPad,{
			arg val, num, chan, src;

			postln('PATCH 2 : 3 - 5');
			~harmonizer.set(\pitch1, 4, \pitch2, 7, \pitch3, 0);

			OSCdef('OSCreceiver',
				{
					arg msg;
					var x_map, y_map, z_map, k_map, amp, amp1;
					var high_low_mix;
					var amp5, amp7;

					x = msg[1]; // x centroid  -> feedback     ->the sphere radius
					y = msg[2];//  y  centroid -> index        ->the spere rays
					z = msg[3];// palm length  -> LPF cut-off  ->the double squares
					k = msg[4];// palm slope   -> Reverb amount->the square magnitude


					x_map = LinLin.ar(x,0,1,0,2);// mapping the feedback
					y_map = LinLin.ar(y,0,1,0,1); // mapping of the index (increase the modulation amplitude)
					z_map = LinLin.ar(z,0,1,0,2);// mapping of the cut off lpf
					k_map = LinLin.ar(k,0,1,-1,1); //  mapping of the Reverb amount

					high_low_mix = LinLin.ar(y,0,1,-1.5,1.5);

					amp5 = 0.5*x_map;
					amp7 = 0;

					if ( z_map < 0.15, {
						~harmonizer.set(\amph, 0);
						postln("harmony is off");
						postln("amph : " + z_map);
					}, {
						~harmonizer.set(\amph, z_map);
						postln("harmony is on");
						postln("amph : " + z_map);

					});

					if (k_map>= 0.8,{
						~dl.set(\mix, 1);
						postln( "delaaaay OFF");

					},
					{
						~dl.set(\mix, k_map);
					});

					~harmonizer.set(\amp5Up, amp5, \amp5Low, amp5);
					~harmonizer.set(\amp7Up, amp7, \amp7Low, amp7);
					postln("AMP 5 : " + amp5, "  AMP 7 : " + amp7);

					~harmonizer.set(\high_low_mix, high_low_mix);
					postln("High & Low Mix : " + high_low_mix);


			},"/params");


		},noteNum: 36);

		MIDIdef.noteOn(\secondPad,{
			arg val, num, chan, src;

			postln('PATCH 1: 4 - 5 - 7m');
			~harmonizer.set(\pitch1, 5, \pitch2, 7, \pitch3, 10);

			OSCdef('OSCreceiver',
				{
					arg msg;
					var x_map, y_map, z_map, k_map, amp, amp1;
					var high_low_mix;
					var amp5, amp7;

					x = msg[1]; // x centroid  -> feedback     ->the sphere radius
					y = msg[2];//  y  centroid -> index        ->the spere rays
					z = msg[3];// palm length  -> LPF cut-off  ->the double squares
					k = msg[4];// palm slope   -> Reverb amount->the square magnitude


					x_map = LinLin.ar(x,0,1,0,3);// mapping the feedback
					y_map = LinLin.ar(y,0,1,0,1); // mapping of the index (increase the modulation amplitude)
					z_map = LinLin.ar(z,0,1,0,2);// mapping of the cut off lpf
					k_map = LinLin.ar(k,0,1,-1,1); //  mapping of the Reverb amount

					high_low_mix = LinLin.ar(y,0,1,-1.5,1.5);

					amp5 = 0.5*x_map;
					amp7 = 0.33*x_map;

					if ( z_map < 0.15, {
						~harmonizer.set(\amph, 0);
						postln("harmony is off");
						postln("amph : " + z_map);
					}, {
						~harmonizer.set(\amph, z_map);
						postln("harmony is on");
						postln("amph : " + z_map);

					});

					if (k_map>= 0.8,{
						~dl.set(\mix, 1);
						postln( "delaaaay OFF");

					},
					{
						~dl.set(\mix, k_map);
					});

					~harmonizer.set(\amp5Up, amp5, \amp5Low, amp5);
					~harmonizer.set(\amp7Up, amp7, \amp7Low, amp7);
					postln("AMP 5 : " + amp5, "  AMP 7 : " + amp7);

					~harmonizer.set(\high_low_mix, high_low_mix);
					postln("High & Low Mix : " + high_low_mix);


			},"/params");


		},noteNum: 37);

		MIDIdef.noteOn(\thirdPad,{
			arg val, num, chan, src;

			postln('PATCH 3 : 4 - 4# - 7min');
			~harmonizer.set(\pitch1, 5, \pitch2, 6, \pitch3, 10);

			OSCdef('OSCreceiver',
				{
					arg msg;
					var x_map, y_map, z_map, k_map, amp, amp1;
					var high_low_mix;
					var amp5, amp7;

					x = msg[1]; // x centroid  -> feedback     ->the sphere radius
					y = msg[2];//  y  centroid -> index        ->the spere rays
					z = msg[3];// palm length  -> LPF cut-off  ->the double squares
					k = msg[4];// palm slope   -> Reverb amount->the square magnitude


					x_map = LinLin.ar(x,0,1,0,3);// mapping the feedback
					y_map = LinLin.ar(y,0,1,0,1); // mapping of the index (increase the modulation amplitude)
					z_map = LinLin.ar(z,0,1,0,2);// mapping of the cut off lpf
					k_map = LinLin.ar(k,0,1,-1,1); //  mapping of the Reverb amount

					high_low_mix = LinLin.ar(y,0,1,-1.5,1.5);

					amp5 = 0.5*x_map;
					amp7 = 0.33*x_map;

					if ( z_map < 0.15, {
						~harmonizer.set(\amph, 0);
						postln("harmony is off");
						postln("amph : " + z_map);
					}, {
						~harmonizer.set(\amph, z_map);
						postln("harmony is on");
						postln("amph : " + z_map);

					});

					if (k_map>= 0.8,{
						~dl.set(\mix, 1);
						postln( "delaaaay OFF");

					},
					{
						~dl.set(\mix, k_map);
					});

					~harmonizer.set(\amp5Up, amp5, \amp5Low, amp5);
					~harmonizer.set(\amp7Up, amp7, \amp7Low, amp7);
					postln("AMP 5 : " + amp5, "  AMP 7 : " + amp7);

					~harmonizer.set(\high_low_mix, high_low_mix);
					postln("High & Low Mix : " + high_low_mix);


			},"/params");


		},noteNum: 38);

		MIDIdef.noteOn(\fourthPad,{
			arg val, num, chan, src;

			postln('PATCH 4 : octavier');
			~harmonizer.set(\pitch1, -12);
			~harmonizer.set(\amp5Up, 0, \amp5Low, 0);
			~harmonizer.set(\amp7Up, 0, \amp7Low, 0);
			~harmonizer.set(\amp3Low, 0);

			OSCdef('OSCreceiver',
				{
					arg msg;
					var x_map, y_map, z_map, k_map, amp, amp1;
					var high_low_mix;
					var amp5, amp7;

					x = msg[1]; // x centroid  -> feedback     ->the sphere radius
					y = msg[2];//  y  centroid -> index        ->the spere rays
					z = msg[3];// palm length  -> LPF cut-off  ->the double squares
					k = msg[4];// palm slope   -> Reverb amount->the square magnitude


					x_map = LinLin.ar(x,0,1,0,3);// mapping the feedback
					y_map = LinLin.ar(y,0,1,0,1); // mapping of the index (increase the modulation amplitude)
					z_map = LinLin.ar(z,0,1,0,2);// mapping of the cut off lpf
					k_map = LinLin.ar(k,0,1,-1,1); //  mapping of the Reverb amount

					if ( z_map < 0.15, {
						~harmonizer.set(\amph, 0);
						postln("harmony is off");
						postln("amph : " + z_map);
					}, {
						~harmonizer.set(\amph, z_map);
						postln("harmony is on");
						postln("amph : " + z_map);

					});

					if (k_map>= 0.8,{
						~dl.set(\mix, 1);
						postln( "delaaaay OFF");

					},
					{
						~dl.set(\mix, k_map);
					});


			},"/params");


		},noteNum: 39);

		MIDIdef.noteOn(\onOff,{
			arg val, num, chan, src;

			if(~onOff == 0, {
				~onOff = 1;
				~voiceTracker = Synth.new(\voiceTracker, [\outputBus,  ~trackerOut, \outFreqBus, ~fundamentalBus], ~inputGroup);
				postln("the Harmonizer is On!");
			},
			{
				~onOff = 0;
				~voiceTracker.free;
				postln("the Harmonizer is Off!");
			});


		},noteNum: 40);

		MIDIdef.noteOn(\onOffHarm,{
			arg val, num, chan, src;

			if(~onOffHarm == 0, {
				~onOffHarm = 1;
				~harmonizer.set(\amphmidi, ~onOffHarm);
				postln("harmony on!");
			},
			{
				~onOffHarm = 0;
				~harmonizer.set(\amphmidi, ~onOffHarm);
				postln("harmony off!");
			});


		},noteNum: 41);

		MIDIdef.noteOn(\delayPatch,{
			arg val, num, chan, src;

			~harmonizer.set(\amphmidi, 0);

			OSCdef('OSCreceiver',
				{
					arg msg;
					var x_map, y_map, z_map, k_map, amp, amp1;
					var high_low_mix;
					var amp5, amp7;

					x = msg[1]; // x centroid  -> feedback     ->the sphere radius
					y = msg[2];//  y  centroid -> index        ->the spere rays
					z = msg[3];// palm length  -> LPF cut-off  ->the double squares
					k = msg[4];// palm slope   -> Reverb amount->the square magnitude


					x_map = LinLin.ar(x,0,1,0,3);// mapping the feedback
					y_map = LinLin.ar(y,0,1,0,1); // mapping of the index (increase the modulation amplitude)
					z_map = LinLin.ar(z,0,1,0,2);// mapping of the cut off lpf
					k_map = LinLin.ar(k,0,1,-1,1); //  mapping of the Reverb amount

					if (k_map>= 0.8,{
						~dl.set(\mix, 1);
						postln( "delaaaay OFF");

					},
					{
						~dl.set(\mix, k_map);
					});


			},"/params");


		},noteNum: 42);

		MIDIdef.noteOn(\reverbPatch,{
			arg val, num, chan, src;

			~harmonizer.set(\amphmidi, 0);

			OSCdef('OSCreceiver',
				{
					arg msg;
					var x_map, y_map, z_map, k_map, amp, amp1;
					var high_low_mix;
					var amp5, amp7;

					x = msg[1]; // x centroid  -> feedback     ->the sphere radius
					y = msg[2];//  y  centroid -> index        ->the spere rays
					z = msg[3];// palm length  -> LPF cut-off  ->the double squares
					k = msg[4];// palm slope   -> Reverb amount->the square magnitude


					x_map = LinLin.ar(x,0,1,0,3);// mapping the feedback
					y_map = LinLin.ar(y,0,1,0,1); // mapping of the index (increase the modulation amplitude)
					z_map = LinLin.ar(z,0,1,0,2);// mapping of the cut off lpf
					k_map = LinLin.ar(k,0,1,-1,1); //  mapping of the Reverb amount

					if (k_map>= 0.8,{
						~rev.set(\wetR, 1);
						postln( "delaaaay OFF");

					},
					{
						~rev.set(\wetR, k_map);
					});


			},"/params");


		},noteNum: 43);

	}.defer(8);


	{
		postln("GUI section.");
		Window.closeAll;
		w = Window.new("gui", Rect.new(200,500, 500, 200)).front.alwaysOnTop_(true);


		~decaySlider = EZSlider(
			parent: w,
			bounds: Rect(85,100 , 300, 20),
			label: "Delay Decay",
			controlSpec: ControlSpec(minval: 1, maxval: 10, warp: \lin, step: 1, units:\Decay),
			action: {arg thisSlider; ~dl.set(\decay, thisSlider.value)},
			initVal: 2,
			initAction: true,
			labelWidth: 100,
			numberWidth: 60,
			unitWidth: 45,
			labelHeight: 20,
		);

		~delTimeSlider = EZSlider(
			parent: w,
			bounds: Rect(85, 120, 300, 20),
			label: "Delay Time",
			controlSpec: ControlSpec(minval: 0.1, maxval: 1.9, warp: \lin, step: 0.1, units:\delTime),
			action: {arg thisSlider; ~dl.set(\delTime, thisSlider.value)},
			initVal: 1,
			initAction: true,
			labelWidth: 100,
			numberWidth: 60,
			unitWidth: 45,
			labelHeight: 20,
		);

		//////////Knob for setting the dry/wet of the Reverb //////////////////

		~revDryWetKnob= EZKnob(parent: w,
			bounds:Rect(400, 110, 80, 80) ,
			label: "Rev-Dry/Wet",
			controlSpec: ControlSpec(minval: 0, maxval: 1, warp: \lin, step: 0.1),
			action: {arg thisSlider; ~rev.set(\wetR, thisSlider.value)},
			initVal: 0.5,
			initAction: false,
			labelWidth: 60,
			knobSize: Point(150,200),
			unitWidth: 0,
			labelHeight: 20,
			layout: 'vert');


		~b1 = Button(w, Rect(10, 10, 75, 50));
		~b1.states = [
			["Play", Color.black, Color.green],
			["Stop", Color.white, Color.red],
		];
		~b1.action_({
			arg view;

			if (view.value == 1, {
				~voiceTracker = Synth.new(\voiceTracker, [\outputBus,  ~trackerOut, \outFreqBus, ~fundamentalBus], ~inputGroup);
				postln("the Harmonizer is On!");
			},{
				~voiceTracker.free;
				postln("the Harmonizer is Off!");
			});

		});

		~harmony = Button(w, Rect(95, 10, 75, 50));
		~harmony.states = [
			["Harmony ON", Color.black, Color.white],
			["Harmony OFF", Color.white, Color.black],
		];
		~harmony.action_({
			arg view;
			~harmonizer.set(\amph, view.value);


		});

		~b3 = Button(w, Rect(180, 10, 75, 50));
		~b3.string = "EXIT";
		~b3.action_({Window.closeAll});

		~b4 = Button(w, Rect(50, 150, 50, 50));
		~b4.string = "Major";
		~b4.action_({~scale[0].set(0)});

		~b5 = Button(w, Rect(100, 150, 50, 50));
		~b5.string = "Minor";
		~b5.action_({~scale[0].set(1)});

		/*
		~sc = PopUpMenu(w, Rect(10, 10, 100, 30));
		~sc.items = ['Major', 'Minor'];
		~sc.action_({
		~scale = ~sc.value;
		postln(~scale);
		}); */
	}.defer(10);

}
)


~dl.set(\delTime, 0.3, \decay, 1);

~harmonizer.set(\pitch1, 5, \pitch2, 7, \pitch3, 10);
~harmonizer.set(\pitch1, 4, \pitch2, 7, \pitch3, 12);



