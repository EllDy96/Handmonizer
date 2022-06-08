






Server.killAll

////////////////////////////////// Two voices with 4 reagions Harmonizer/////////////////////////////////////////////////////


( //#1 ======INITIALIZE SC SERVER ======

o = Server.local.options;
o.sampleRate = 48000;
o.blockSize = 32;
o.inDevice = nil;   //"ASIO : UMC ASIO Driver"; //"MME : Gruppo microfoni (Realtek High"; //use system default audio input (change value to manually configure input)
o.outDevice = nil; //"ASIO : UMC ASIO Driver"; //use system default audio output (change value to manually configure output)
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
    Out.kr(outFreqBus, freq);
	Out.ar(outputBus, in);
}).send(s);

/*
SynthDef.new(\pitchRatio, {
	|
	ratioOut
	|

	var key = 0, scaleType = 0;

	var note = 47;

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
	postln("Pitch Ratio: " + ratio);

	Out.kr(ratioOut, ratio);

}).send(s);
*/

SynthDef.new(\harmonizer, {
	|
	inputBus, inFreqBus, outHarmBus, outVoiceBus
	ratio = 1
	amph = 1
	|

	//postln("Ratio in : " + ratioIn);
	var in = In.ar(inputBus, 1);
	var grains = 2;
	var freq = In.ar(inFreqBus, 1);

	h = amph * PitchShiftPA.ar(in, freq, ratio, ratio, grainsPeriod: 2);
	//h = PitchShift.ar(in, 0.2, ratio);

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
//~pitchRatioSynth = Synth.new(\pitchRatio, [\ratioOut, ~pitchRatioBus], ~harmonizerGroup);
~harmonizer = Synth.new(\harmonizer, [\inputBus, ~trackerOut, \inFreqBus, ~fundamentalBus, \ratioIn, ~pitchRatioBus, \outVoiceBus, ~harmonizerVoice, \outHarmBus, ~harmonizerHarm], ~harmonizerGroup);

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

/////// Pitch ratio compute ////////

(

var key = 0, scaleType = 1;
var setkey = MiscFuncs.getNoteToMidi.matchAt(key);
var scaleArray = MiscFuncs.getScaleIntervals.matchAt(scaleType);


var fiddle = MykFiddle.new();
fiddle.run;



fiddle.callback_({
	arg n;
	var note = n.asInteger;



	var key = 0, scaleType = 0;

	//var a = MiscFuncs.getNoteToMidi.matchAt(key);
	//var scaleArray = MiscFuncs.getScaleIntervals.matchAt(scaleType);

	var scaleMIDI = Array.fill(33, 0);

	var diff = 0;

	var i = 0, j = 0;
	var pitch = 0;
	var ratio = 1;
	var targetNote;

	postln("MIDI note: " + note);

	while({i < 33}, {

		j = j%scaleArray.size;

		diff = diff + scaleArray[j];

		scaleMIDI[i] = setkey + diff;

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
			//pitch= 7;
			postln("out of the scale");
		});
	});

	ratio = (2.pow(1/12)).pow(pitch);
	postln("Pitch Ratio: " + ratio);

	~harmonizer.set(\ratio, ratio);
});

)

(

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
)


