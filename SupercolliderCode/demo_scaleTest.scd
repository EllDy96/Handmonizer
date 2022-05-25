
Server.killAll

////////////////////////////////// Two voices with 4 reagions Harmonizer/////////////////////////////////////////////////////


( //#1 ======INITIALIZE SC SERVER ======

o = Server.local.options;
o.sampleRate = 48000;
o.blockSize = 32;
o.inDevice =  "Windows WASAPI : Headset Mic (2- Realtek High Definition Audio)"; // "ASIO : UMC ASIO Driver"; //"MME : Gruppo microfoni (Realtek High"; //use system default audio input (change value to manually configure input)
o.outDevice =  "Windows WASAPI : Speakers / Headphones (2- Realtek High Definition Audio)";//"ASIO : UMC ASIO Driver"; //use system default audio output (change value to manually configure output)
s.latency = 0.01; //0.2 is SC default
s.boot;
)

ServerOptions.devices;
ServerOptions.inDevices;
ServerOptions.outDevices;


(
s.scope; // plotting the wave in time domain
FreqScope.new; // ploting the spectogram
)

///////////////////////////////////// MODEL ////////////////////////////////////////////////////

(

~pitchRatioControlBuses = Array.fill(1, {arg i; Bus.control(s, 1)});

~scale = Array.fill(1, {arg i; Bus.control(s, 1)});

)

////pitch ratio function////
(

~pitchRatioCompute = {
	|
	key
	scaleType
	note
	|

	var a = MiscFuncs.getNoteToMidi.matchAt(key);
	var scaleArray = MiscFuncs.getScaleIntervals.matchAt(scaleType);

	var scaleMIDI = Array.fill(33, 0);
	var diff = 0;

	var i = 0, j = 0;
	var pitch = 0;
	var ratio = 1;
	var targetNote;

	while({i < 33}, {

	    j = j%scaleArray.size;

		diff = diff + scaleArray[j];

	    scaleMIDI[i] = a + diff;

	    i = i+1;
	    j = j+1;
	});


   for (0, scaleMIDI.size-2, {
	   arg k;
	   if( note == scaleMIDI[k] , {
			targetNote = scaleMIDI[k+2];
			pitch = targetNote - note;
		},
		{
			targetNote = note;
		});
});

    ratio = (2.pow(1/12)).pow(pitch);
};

)

//////SYNTHS///////

(
SynthDef.new(\voiceTracker, {
    |
    outputBus, outFreqBus, outMidi
    |

    var in, amp, freq, hasFreq, out;
	var midiFundamental;

    in = Mix.new(SoundIn.ar([0,1]));

	# freq, hasFreq = Tartini.kr(in);
	//midiFundamental = freq.cpsmidi;


	//Out.kr(outMidi, midiFundamental);
    Out.kr(outFreqBus, freq);
	Out.ar(outputBus, in);
}).send(s);

SynthDef.new(\pitchRatio, {
	|
	key = 0, scaleType = 0
	ratioOut
	|

	var note = 47;

	var a = MiscFuncs.getNoteToMidi.matchAt(key);
	var scaleArray = MiscFuncs.getScaleIntervals.matchAt(scaleType);

	var scaleMIDI = Array.fill(33, 0);
	var diff = 0;

	var i = 0, j = 0;
	var pitch = 0;
	var ratio = 1;
	var targetNote;

	var fiddle = MykFiddle.new();
    fiddle.run;

	fiddle.callback_({
	    arg n;
		note = n.asInteger;
	    postln("MIDI note: " + note);
    });
	postln("NOTE:" + note);

	while({i < 33}, {

	    j = j%scaleArray.size;

		diff = diff + scaleArray[j];

	    scaleMIDI[i] = a + diff;

	    i = i+1;
	    j = j+1;
	});


   for (0, scaleMIDI.size-2, {
	   arg k;
	   if( note == scaleMIDI[k] , {
			targetNote = scaleMIDI[k+2];
			pitch = targetNote - note;
		},
		{
			targetNote = note;
		});
   });

    ratio = (2.pow(1/12)).pow(pitch);

	Out.kr(ratioOut, ratio);


}).send(s);

SynthDef.new(\harmonizer, {
	|
	inputBus, inFreqBus, outHarmBus, outVoiceBus
	ratioIn
	amph = 1
	|

	//postln("Ratio in : " + ratioIn);
	var in = In.ar(inputBus, 1);
	var grains = 2;
	var freq = In.ar(inFreqBus, 1);
	var ratio = In.ar(ratioIn, 1);

	h = PitchShiftPA.ar(in, freq, ratio, ratio, grainsPeriod: 2);
	//h = PitchShift.ar(in, 0.2, 1.5);

    Out.ar(outVoiceBus, in);
	Out.ar(outHarmBus, h);
}).send(s);



SynthDef.new(\finalSum, {
    |
    inputVoiceBus, inputHarmBus, outputBus
    |

	var input, harmonics;
    var out;


	input = In.ar(inputVoiceBus, 1);
	harmonics = In.ar(inputHarmBus, 1);

	out = Mix.new([input, harmonics]);

	Out.ar([0,1], out);
}).send(s);

)


//////BUSES//////

(

// create the busses
~trackerOut = Bus.audio(s, 1);
~harmonizerVoice = Bus.audio(s, 1);
~harmonizerHarm = Bus.audio(s, 1);
//~finalBus = Bus.audio(s, 1);

// this bus contains the frequency of the note sung by the user
~fundamentalBus = Bus.control(s, 1);
~midiFundamental = Bus.control(s, 1);
~pitchRatioBus = Bus.control(s, 1);

// Create the groups
~inputGroup = Group.new;
~harmonizerGroup = Group.after(~inputGroup);
~outputGroup = Group.after(~harmonizerGroup);

// instances of the various model Synth
~pitchRatioSynth = Synth.new(\pitchRatio, [\ratioOut, ~pitchRatioBus], ~harmonizerGroup);
~harmonizer = Synth.after(\harmonizer, [\inputBus, ~trackerOut, \inFreqBus, ~fundamentalBus, \outVoiceBus, ~harmonizerVoice, \outHarmBus, ~harmonizerHarm, \ratioIn, ~pitchRatioBus], ~harmonizerGroup);

~finalSum = Synth.new(\finalSum, [\inputVoiceBus, ~harmonizerVoice, \inputHarmBus, ~harmonizerHarm], ~outputGroup);
)


(

NetAddr("127.0.0.1",57120);

OSCdef('OSCreceiver',
	{
		arg msg;
		var x_map, y_map, z_map, k_map, amp, amp1;

		x = msg[1]; // x centroid  -> feedback     ->the sphere radius
		y = msg[2];//  y  centroid -> index        ->the spere rays
        z = msg[3];// palm length  -> LPF cut-off  ->the double squares
		k = msg[4];// palm slope   -> Reverb amount->the square magnitude


		x_map = LinLin.ar(x,0,1,0,2);// mapping the feedback
        y_map = LinLin.ar(y,0,1,0,2); // mapping of the index (increase the modulation amplitude)
        z_map = LinLin.ar(z,0,1,0,1);// mapping of the cut off lpf
		k_map = LinLin.ar(k,0,1,-1,1); //  mapping of the Reverb amount


		if(x_map < 1,
			{
				if(y_map < 1,
					{
						~harmonizer.set(\amp3Up, 0, \amp5up, 0, \amp3Low, 0.5, \amp5Low, 0);
						postln("only the third low");
				},
					{
						~harmonizer.set(\amp3Up, 1, \amp5up, 0, \amp3Low, 0, \amp5Low, 0);
						postln("only the third high");
				});
		},
			{
				if(y_map < 1,
					{
						~harmonizer.set(\amp3Up, 0, \amp5up, 0, \amp3Low, 0.5, \amp5Low, 0.5);
						postln("only the third and the fifth low");
				},
					{
						~harmonizer.set(\amp3Up, 1, \amp5up, 1, \amp3Low, 0, \amp5Low, 0);
						postln("only the third and the fifth up");
				});
		});



		if ( z_map < 0.2, {
			~harmonizer.set(\amph, 0);
			postln("harmony is off");
		}, {
			~harmonizer.set(\amph, 1);
			postln("harmony is on");

		});


        //Printing the OSC values:
		postln("Mapped parameter: X: "+ x_map  + " - Y: " + y_map + " - ON/OFF: "+ z_map );
	},"/params");

)

(

Window.closeAll;
w = Window.new("gui", Rect.new(200,500, 500, 200)).front.alwaysOnTop_(true);

~slider = EZSlider(
					parent: w,
					bounds: Rect(85, 20, 300, 20),
					label: "P.R.",
					controlSpec: ControlSpec(minval: -12, maxval: 12, warp: \lin, step: 1, units:\semitones),
	                action: {arg thisSlider; ~pitchRatioControlBuses[0].set(thisSlider.value)},
					initVal: 0,
					initAction: true,
					labelWidth: 60,
					numberWidth: 60,
					unitWidth: 30,
					labelHeight: 20,
				);

~b1 = Button(w, Rect(50, 50, 50, 50));
~b1.string = "ON";
~b1.action_({

    ~voiceTracker = Synth.new(\voiceTracker, [\outputBus,  ~trackerOut, \outFreqBus, ~fundamentalBus], ~inputGroup);

});

~b2 = Button(w, Rect(100, 50, 50, 50));
~b2.string = "OFF";
~b2.action_({

    ~voiceTracker.free;

});

~b3 = Button(w, Rect(200, 50, 100, 50));
~b3.string = "EXIT";
~b3.action_({Window.closeAll});

~b4 = Button(w, Rect(50, 150, 50, 50));
~b4.string = "Major";
~b4.action_({~scale[0].set(0)});

~b5 = Button(w, Rect(100, 150, 50, 50));
~b5.string = "Minor";
~b5.action_({~scale[0].set(1)});

~sc = PopUpMenu(w, Rect(10, 10, 100, 30));
~sc.items = ['Major', 'Minor'];
~sc.action_({
	~scale = ~sc.value;
	postln(~scale);
});
)


