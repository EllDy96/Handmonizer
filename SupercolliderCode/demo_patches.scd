
Server.killAll

//////////////////3 voices with 6 reagions Harmonizer (4th, 5th, minor 7th)///////////////////////////////////


(
//#1 ======INITIALIZE SC SERVER ======
//if server fails to start and error encountered:  try, try again...it's stubborn sometimes...
o = Server.local.options;
o.sampleRate = 48000;
o.blockSize = 32;
o.inDevice = "Windows WASAPI : Headset Mic (2- Realtek High Definition Audio)";//"ASIO : Focusrite USB ASIO";//"ASIO : UMC ASIO Driver"; //"MME : Gruppo microfoni (Realtek High"; //use system default audio input (change value to manually configure input)
o.outDevice =  "Windows WASAPI : Speakers / Headphones (2- Realtek High Definition Audio)";//"ASIO : Focusrite USB ASIO";// "ASIO : UMC ASIO Driver";  //use system default audio output (change value to manually configure output)
s.latency = 0.02; //0.2 is SC default
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

~patchState = Array.fill(1, {arg i; Bus.control(s, 1)});


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
	var pitch = 1;
	var ratio = 1;

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
	   	  pitch = scaleMIDI[k+2] - scaleMIDI[k] ;
		}, {pitch = 0;});
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


SynthDef.new(\harmonizer, {
	|
	inputBus, inFreqBus, inMidi
    outHarmBus, outVoiceBus
	amph = 1, ampLow = 0, ampHigh = 0
	amp4Up = 1, amp5Up = 1, amp7Up = 1, amp4Low = 0, amp5Low = 0, amp7Low=0
	pitch1 = 3, pitch2 = 7, pitch3 = 12
	|

	var in = In.ar(inputBus, 1);
	var partials, voice, harmonics;
	var fundamental, inFreq, out;
	var fourthUp, fifthUp, sevenUp, fourthLow, fifthLow, sevenLow;

	var grains = 2;

/*
	if (state == 0, {
        //harmonic1 = 3;
		//harmonic2 = 5;
		//harmonic3 = 8;
		postln("State: " + 0);
	}, {
		//harmonic1 = 4;
		//harmonic2 = 5;
		//harmonic3 = 7;
		postln("State: " + 1);
	});

	scaleArray = MiscFuncs.getScaleIntervals.matchAt(1);
	postln(scaleArray);

    (harmonic1-1).do({arg index = 0; p1 = p1+scaleArray[index]});
	(harmonic2-1).do({arg index = 0; p2 = p2+scaleArray[index]});
	(harmonic3-1).do({arg index = 0; p3 = p3+scaleArray[index]});
    postln(p1);
	postln(p2);
	postln(p3);*/

	////////////// Fixed harmony ///////////////

	fourthUp = amp4Up * PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(pitch1), (2.pow(1/12)).pow(pitch1), grainsPeriod: 2);
    fifthUp = amp5Up * PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(pitch2), (2.pow(1/12)).pow(pitch2), grainsPeriod: 2);
	sevenUp = amp7Up * PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(pitch3), (2.pow(1/12)).pow(pitch3), grainsPeriod: 2);

	fourthLow = amp4Low * PitchShiftPA.ar(in, inFreqBus, 0.5*(2.pow(1/12)).pow(pitch1), 0.5*(2.pow(1/12)).pow(pitch1), grainsPeriod: 4);
    fifthLow = amp5Low * PitchShiftPA.ar(in, inFreqBus, 0.5*(2.pow(1/12)).pow(pitch2), 0.5*(2.pow(1/12)).pow(pitch2), grainsPeriod: 4);
	sevenLow = amp7Low  * PitchShiftPA.ar(in, inFreqBus, 0.5*(2.pow(1/12)).pow(pitch3), 0.5*(2.pow(1/12)).pow(pitch3), grainsPeriod: 2);

	harmonics = Mix.new([fourthUp, fifthUp, sevenUp, fourthLow, fifthLow, sevenLow]);
	harmonics = amph * harmonics;

    Out.ar(outVoiceBus, in);
	Out.ar(outHarmBus, harmonics);
}).send(s);



SynthDef.new(\finalSum, {
    |
    inputVoiceBus, inputHarmBus, outputBus
    |

	var input, harmonics;
    var out;

	var add;

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

// Create the groups
~inputGroup = Group.new;
~harmonizerGroup = Group.after(~inputGroup);
~outputGroup = Group.after(~harmonizerGroup);

// instances of the various model Synth
~harmonizer = Synth.new(\harmonizer, [\inputBus, ~trackerOut, \inFreqBus, ~fundamentalBus, \outVoiceBus, ~harmonizerVoice, \outHarmBus, ~harmonizerHarm], ~harmonizerGroup);

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


		x_map = LinLin.ar(x,0,1,0,3);// mapping the feedback
        y_map = LinLin.ar(y,0,1,0,1); // mapping of the index (increase the modulation amplitude)
        z_map = LinLin.ar(z,0,1,0,2);// mapping of the cut off lpf
		k_map = LinLin.ar(k,0,1,-1,1); //  mapping of the Reverb amount


		if(x_map < 1,
			{
				if(y_map < 0.5,
					{
						~harmonizer.set(\amp4Up, 0, \amp5Up, 0, \amp4Low, 0.7, \amp5Low, 0, \amp7Low, 0, \amp7Up, 0);
						postln("fourth low");
				},
					{
						~harmonizer.set(\amp4Up, 0.5, \amp5Up, 0, \amp4Low, 0, \amp5Low, 0, \amp7Low, 0, \amp7Up, 0);
						postln("fourth high");
				});
			},
			{
				if(x_map < 2, {

				if(y_map < 0.5,
					{
						~harmonizer.set(\amp4Up, 0, \amp5Up, 0, \amp4Low, 0.7, \amp5Low, 0.7, \amp7Low, 0, \amp7Up, 0);
						postln("fourth and fifth low");
				},
					{
						~harmonizer.set(\amp4Up, 0.5, \amp5Up, 0.5, \amp4Low, 0, \amp5Low, 0, \amp7Low, 0, \amp7Up, 0);
						postln("fourth and fifth up");
				});
			},
			{
				if(y_map < 0.5,
					{
						~harmonizer.set(\amp4Up, 0, \amp5Up, 0, \amp4Low, 0.7, \amp5Low, 0.7, \amp7Low, 0.7, \amp7Up, 0);
						postln("three voices low");
				},
					{
						~harmonizer.set(\amp4Up, 0.5, \amp5Up, 0.5, \amp4Low, 0, \amp5Low, 0, \amp7Low, 0, \amp7Up, 0.5);
						postln("three voices up");
				});
		})});


		~harmonizer.set(\ampLow, 1-y_map, \ampHigh, y_map);

		//postln("Amp low: " + (1-y_map) + "  Amp high: " + y_map);



		if ( z_map < 0.15, {
			~harmonizer.set(\amph, 0);
			postln("harmony is off");
		}, {
			~harmonizer.set(\amph, z_map);
			postln("harmony is on");

		});

		if (k_map>= 0.8,{
			~finalSum.set(\mix, 1);
			postln( "delaaaay OFF");

		},
		{
		~finalSum.set(\mix, k_map);
		});



        //Printing the OSC values:
		postln("Mapped parameter: X: "+ x_map  + " - Y: " + y_map + " - ON/OFF: "+ z_map + " - Delay mix : " + k_map);
	},"/params");

)

(

Window.closeAll;
w = Window.new("gui", Rect.new(500, 500, 375, 100)).front.alwaysOnTop_(true);


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


~sc = PopUpMenu(w, Rect(265, 10, 100, 30));
~sc.items = ['Patch 1', 'Patch 2'];
~sc.action_({
	arg view;

	postln("Patch : " + view.value);

	if (view.value == 0, {
		~harmonizer.set(\pitch1, 3, \pitch2, 7, \pitch3, 12);
	},{
		~harmonizer.set(\pitch1, 5, \pitch2, 7, \pitch3, 10);
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

)

