
Server.killAll;

////////////////////////////////// Two voices with 4 reagions Harmonizer/////////////////////////////////////////////////////
(

{ //#1 ======INITIALIZE SC SERVER ======

	o = Server.local.options;
	o.sampleRate = 48000;
	o.blockSize = 32;
	o.inDevice = nil; // "ASIO : UMC ASIO Driver"; //"MME : Gruppo microfoni (Realtek High"; //use system default audio input (change value to manually configure input)
	o.outDevice = nil; //"ASIO : UMC ASIO Driver"; //use system default audio output (change value to manually configure output)
	s.latency = 0.01; //0.2 is SC default
	s.boot;
	postln("Server section status : RUNNING");
}.defer(1);


//////SYNTHS///////
s.waitForBoot{
	{
		postln("Synth section status : RUNNING");
		SynthDef.new(\voiceTracker, {
			|
			outputBus, outFreqBus, outMidi
			|

			var in, amp, freq, hasFreq, out;
			var midiFundamental;

			in = Mix.new(SoundIn.ar([0,1]));

			# freq, hasFreq = Tartini.kr(in);
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

			fourthUp = amp4Up * PitchShiftPA.ar(in, inFreqBus, pitch1, pitch1, grainsPeriod: 2);
			fifthUp = amp5Up * PitchShiftPA.ar(in, inFreqBus, pitch2, pitch2, grainsPeriod: 2);
			sevenUp = amp7Up * PitchShiftPA.ar(in, inFreqBus, pitch3, pitch3, grainsPeriod: 2);

			fourthLow = amp4Low * PitchShiftPA.ar(in, inFreqBus, 0.5*pitch1, 0.5*pitch1, grainsPeriod: 4);
			fifthLow = amp5Low * PitchShiftPA.ar(in, inFreqBus, 0.5*pitch2, 0.5*pitch2, grainsPeriod: 4);
			sevenLow = amp7Low  * PitchShiftPA.ar(in, inFreqBus, 0.5*pitch3, 0.5*pitch3, grainsPeriod: 2);

			high_harm = Mix.new([fourthUp, fifthUp, sevenUp]);
			low_harm = Mix.new([fourthLow, fifthLow, sevenLow]);


			//harmonics = Mix.new([fourthUp, fifthUp, sevenUp, fourthLow, fifthLow, sevenLow]);

			harmonics = amphmidi * XFade2.ar(low_harm, high_harm, high_low_mix);

			Out.ar(outVoiceBus, ampv * in);
			Out.ar(outHarmBus, amph * harmonics);
		}).send(s);

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
			var highPassedDelay;
			var highPassedSource;

			in = In.ar(inputBus);
			highPassedSource= HPF.ar(in,200);

			delay = CombL.ar(highPassedSource, maxDelTime, delTime, decay);
			//sig = Mix([sig*(1-wetD), delay*wetD]);
			mixDelayed = XFade2.ar(delay, in, mix);

			highPassedDelay= BHiPass.ar(mixDelayed, freq:250);
			Out.ar(outputBus,highPassedDelay);
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
			var highPassedReverb;

			dry = 1 - wetR;
			source = In.ar(inputBus, 1);
			highPassedSource= HPF.ar(source,150); // first apply an high pass filter to the input signal to make the reverbered sound more realistic


			reverb = GVerb.ar( highPassedSource ,20,revTime, 0.5, 0.7 ,25, dry, 0.4, 0.3);
			mixReverbed = Mix([source*(1-wetR), reverb*wetR]);

			highPassedReverb= BHiPass.ar(mixReverbed, freq:250);
			Out.ar(outputBus, highPassedReverb);
		}).send(s);


		//////////////////////////////////Mixing the output/////////////////

		SynthDef.new(\finalMix,{
			|
			inputSignalBus, inputRevBus, inputDelBus, delFader= 0.5, revFader= 0.5
			|

			var signal, rev, del,finalMix;

			signal= In.ar(inputSignalBus,1);
			rev= In.ar(inputRevBus,1);
			del= In.ar(inputDelBus,1);

			finalMix= Mix.ar([signal,revFader*rev, delFader*del]);

			Out.ar([0,1], finalMix);

		}).send(s);

	}.defer(2);


	//////BUSES//////

	{
		postln("Buses section status : RUNNING");
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


	/////// Pitch ratio compute ////////
	{
		~key = 3;
		~scaleType = 0;
	}.defer(9);

	{
		//postln("Scale section 1 status : RUNNING");

		var a = MiscFuncs.getNoteToMidi.matchAt(~key);
		var scaleArray = MiscFuncs.getScaleIntervals.matchAt(~scaleType);
		var diff = 0;
		var i = 0, j = 0;

		~scaleMIDI = Array.fill(33, 0);
		postln("Scale MIDI: " + ~scaleMIDI);


		while({i < 33}, {

			j = j%scaleArray.size;

			diff = diff + scaleArray[j];

			~scaleMIDI[i] = a + diff;

			i = i+1;
			j = j+1;
		});

		postln("Scale MIDI: " + ~scaleMIDI);
	}.defer(10);

	//to change the parameter key and scale type in real time put inside a button function this part of the code till the while
	{
		//postln("Scale section 2 status : RUNNING");
		var fiddle = MykFiddle.new();
		fiddle.run;
		~pitch1 = 0;
		~pitch2 = 0;
		~pitch3 = 0;
		fiddle.callback_({
			arg n;
			var note = n.asInteger;

			var ratio1 = 1, ratio2 = 1, ratio3 = 1;
			var tn1, tn2, tn3;


			for (0, ~scaleMIDI.size-2, {
				arg k;
				if(note == ~scaleMIDI[k] , {
					tn1 = ~scaleMIDI[k+2];
					tn2 = ~scaleMIDI[k+4];
					tn3 = ~scaleMIDI[k+6];
					~pitch1 = tn1 - note;
					~pitch2 = tn2 - note;
					~pitch3 = tn3 - note;
					postln("In scale. ST1 : " + ~pitch1 + " ST2 : " + ~pitch2 + " ST3 : " + ~pitch3);

				});
				/*
				{
				pitch = 7;
				postln("Out of scale. Semitones : " + pitch);
				});
				*/
			});

			postln("ST1 : " + ~pitch1 + " ST2 : " + ~pitch2 + " ST3 : " + ~pitch3);
			ratio1 = (2.pow(1/12)).pow(~pitch1);
			ratio2 = (2.pow(1/12)).pow(~pitch2);
			ratio3 = (2.pow(1/12)).pow(~pitch3);
			postln("PR1 : " + ratio1 + " PR2 : " + ratio2 + " PR3 : " + ratio3);

			~harmonizer.set(\pitch1, ratio1, \pitch2, ratio2, \pitch3, ratio3);
		});

	}.defer(11);
/*

	{
		postln("MIDI section status: RUNNING.");
		MIDIClient.init; // connects to the operating system's MIDI layer, print the lists of available MIDI sources and destinations.
		MIDIIn.connectAll;
		NetAddr("127.0.0.1",57120);

		//////////////////////////////////////////////////////Kbobs///////////////////////////////////////////////
		//Reverb dry/wet knob

		MIDIdef.cc(\firstKnob,{
			arg val, num, chan, src;
			[val/127,chan,num].postln;
			//~revDryWetKnob.set();
			~rev.set(\wetR, val/127);

			postln("the rev dryWet");
		}, ccNum: 1, chan: 0);

		//Delay dry/wet

		MIDIdef.cc(\secondKnob,{
			arg val, num, chan, src;
			var delDryWet= LinLin.kr(val,0,127,-1,1);
			[val/127,num,chan].postln;
			postln(delDryWet);

			~dl.set(\mix, delDryWet);
			postln("Delay Dry wet");
		}, ccNum: 2, chan: 0);

		//Delay fader
		MIDIdef.cc(\thirdKnob,{
			arg val, num, chan, src;
			[val/127,num,chan].postln;

			~finalMix.set(\delFader, val/127);
			postln("Delay Fader");
		}, ccNum: 3, chan: 0);

		//Rev fader
		MIDIdef.cc(\forthKnob,{
			arg val, num, chan, src;
			[val/127,num, chan].postln;

			~finalMix.set(\revFader, val/127);
			postln("Rev Fader");
		}, ccNum: 4, chan: 0);

		//delay Time
		MIDIdef.cc(\fifthKnob,{
			arg val, num, chan, src;
			[val/127,num, chan].postln;

			~dl.set(\delTime, (val/127)*2); // 2 seconds is the The maximum delay time. Used to initialize the delay buffer size.
			postln("Delay time");
		}, ccNum: 5, chan: 0);

		//delay decay Time
		MIDIdef.cc(\sixthKnob,{
			arg val, num, chan, src;
			[val/127,num,chan].postln;

			~dl.set(\decay, (val/127)*4); // 4 second is the the maximum decay time.
			postln("Delay  Decay time");
		}, ccNum: 6, chan: 0);

		//rev Time
		MIDIdef.cc(\seventhKnob,{
			arg val, num, chan, src;
			[val/127,num, chan].postln;

			~rev.set(\revTime, (val/127)*4); // 4 second is the the maximum rev Time.
			postln("rev  Decay time");
		}, ccNum: 7, chan: 0);

		MIDIdef.noteOn(\onOff,{
			arg val, num, chan, src;

			if(~onOff == 0, {
				~onOff = 1;
				~voiceTracker = Synth.new(\voiceTracker, [\outputBus,  ~trackerOut, \outFreqBus, ~fundamentalBus], ~inputGroup);

				NetAddr("127.0.0.1",57120);

				OSCdef('OSCreceiver',
					{
						arg msg;
						var x_map, y_map, z_map, k_map, amp, amp1;
						var high_low_mix;
						var amp5, amp7;
						a = \db.asWarp;

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
						postln("AMP 5 : " + amp5 + "  AMP 7 : " + amp7);

						~harmonizer.set(\high_low_mix, high_low_mix);
						postln("High & Low Mix : " + high_low_mix);


				},"/params");

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

	}.defer(13)

*/
	{
		postln("GUI section status : RUNNING");

		Window.closeAll;
		w = Window.new("gui", Rect.new(200,500, 500, 200)).front.alwaysOnTop_(true);

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


		~b3 = Button(w, Rect(180, 10, 75, 50));
		~b3.string = "EXIT";
		~b3.action_({Window.closeAll});


		~harmony = Button(w, Rect(95, 10, 75, 50));
		~harmony.states = [
			["Harmony ON", Color.black, Color.white],
			["Harmony OFF", Color.white, Color.black],
		];
		~harmony.action_({
			arg view;
			~harmonizer.set(\amph, view.value);


		});
	}.defer(16);

})


