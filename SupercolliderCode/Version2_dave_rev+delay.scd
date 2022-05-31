

Server.killAll


(
s.scope; // plotting the wave in time domain
FreqScope.new; // ploting the spectogram
a
)
//////////////////3 voices with 6 reagions Harmonizer (4th, 5th, minor 7th)///////////////////////////////////


(
//#1 ======INITIALIZE SC SERVER ======
//if server fails to start and error encountered:  try, try again...it's stubborn sometimes...
o = Server.local.options;
//o.sampleRate = nil;
o.blockSize = 32;
o.outDevice =  "Windows WASAPI : Missaggio stereo (Realtek High Definition Audio)";
o.inDevice =  "Windows WASAPI : Gruppo microfoni (Realtek High Definition Audio)";
s.latency = 0.001; //0.2 is SC default
s.boot;
)

ServerOptions.devices;
ServerOptions.inDevices;
ServerOptions.outDevices;




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
	key = 3, scaleType = 0
    outHarmBus, outVoiceBus
	buffer1, buffer2, buffer3
	amph = 1, ampLow = 1, ampHigh = 1
	amp4Up = 1, amp5Up = 1, amp7Up = 1, amp4Low = 1, amp5Low = 1, amp7Low=1
	pitch1 = 0, pitch2 = 0, pitch3 = 0
	|

	var in = In.ar(inputBus, 1);
	var partials, voice, harmonics;
    var shift1, shift2, shift3;
	var fundamental, inFreq, out;
	var fourthUp, fifthUp, sevenUp, fourthLow, fifthLow, sevenLow;
	var pitchRatio = In.kr(~pitchRatioControlBuses[0], 1);
	var scaleArray;
	var harmonic1 = 4, harmonic2 = 5, harmonic3 = 7;
	var pitch = 0;
	var sc_ale = In.kr(~scale[0], 1);
	var p1 = 0, p2 = 0, p3 = 0;
	var grains = 2;
	var kk = 0, st = 0;
	var midiIn = inFreqBus.cpsmidi;


	scaleArray = MiscFuncs.getScaleIntervals.matchAt(1);
	postln(scaleArray);

	(harmonic1-1).do({arg index = 0; p1 = p1+scaleArray[index]});
	(harmonic2-1).do({arg index = 0; p2 = p2+scaleArray[index]});
	(harmonic3-1).do({arg index = 0; p3 = p3+scaleArray[index]});
    postln(p1);
	postln(p2);
	postln(p3);

	/*
	////////// Pitch shift ratio function ///////////

	//p1 = ~pitchRatioCompute.value(kk, st);
	//postln("Pitch ratio :" + p1);

	//h1 = PitchShiftPA.ar(in, inFreqBus, p1, p1, grainsPeriod: 3);
    */

	////////////// Fixed harmony ///////////////

	fourthUp = ampHigh * amp4Up * PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(p1), (2.pow(1/12)).pow(p1), grainsPeriod: 2);
    fifthUp = ampHigh * amp5Up * PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(p2), (2.pow(1/12)).pow(p2), grainsPeriod: 2);
	sevenUp = ampHigh * amp7Up * PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(p3), (2.pow(1/12)).pow(p3), grainsPeriod: 2);

	fourthLow = ampLow * amp4Low * PitchShiftPA.ar(in, inFreqBus, 0.5*(2.pow(1/12)).pow(p1), 0.5*(2.pow(1/12)).pow(p1), grainsPeriod: 4);
    fifthLow = ampLow * amp5Low * PitchShiftPA.ar(in, inFreqBus, 0.5*(2.pow(1/12)).pow(p2), 0.5*(2.pow(1/12)).pow(p2), grainsPeriod: 4);
	sevenLow = ampLow * amp7Low  * PitchShiftPA.ar(in, inFreqBus, 0.5*(2.pow(1/12)).pow(p3), 0.5*(2.pow(1/12)).pow(p3), grainsPeriod: 2);

	harmonics = Mix.new([fourthUp, fifthUp, sevenUp, fourthLow, fifthLow, sevenLow]);
	harmonics = amph * harmonics;

    Out.ar(outVoiceBus, in);
	Out.ar(outHarmBus, harmonics);
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


	//delay = CombL.ar(out, 0.7, 0.3, 2);

	//mixDelayed = XFade2.ar(delay, out, mix);

	Out.ar(outputBus, out);
}).send(s);



/////////////////////////////////Effects///////////////////////////////

//// Check the effect in parallel instead that in Cascade
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
)
////////////////////////////////BUSES///////////////////

(

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

)
//****************************************MIDI SETUP*******************************************/

//Istantiation of the Midi keyboard for a monophonic synthetizer

(

MIDIClient.init; // connects to the operating system's MIDI layer, print the lists of available MIDI sources and destinations.
MIDIIn.connectAll;

//MIDIIn.control = { arg src, chan, num, val;   [chan,num,val/127].postln; };//to map the knob
//MIDIIn.bend = { arg src, chan, bend;    [chan,bend/8192].postln; };//controll the pitch well



/*
~monoNote= Synth(\harmonizer,[\amp,0]);

~noteOnFunc = {arg val, num, chan, src;


	~monoNote.set(\freq, num.midicps,\amp, val/127);// val/127 because we need an amplitude controller, thus the amp to go from 0 to 1


	[chan,num,val].postln;
};
*/

MIDIdef.cc(\firstKnob,{
	arg val, num, chan, src;
	[val/127,chan].postln;
	//~revDryWetKnob.set();
	~rev.set(\wetR, val/127);
	//postln("the rev dryWet: " + val/127);
}, ccNum: 1, chan: 0);

MIDIdef.noteOn(\firstPad,{
	arg val, num, chan, src;

		postln('you press the first pad!');


},noteNum: 36);


/*
	c= MIDIFunc.cc({
		arg val, num, chan, src;

		[chan,num,val].postln;
	postln('Moving the first knob')

	}, ccNum: 1, chan:0,);


// assign the function to the note on message
a = MIDIFunc.noteOn(func:~noteOnFunc);

//note off function
~noteOffFunc = {arg val, num, chan, src;
	~monoNote.set(\amp,0);

};

b = MIDIFunc.noteOff(func:~noteOffFunc);

q = {a.free; b.free};
*/
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

		postln("Amp low: " + (1-y_map) + "  Amp high: " + y_map);



		if ( z_map < 0.15, {
			~harmonizer.set(\amph, 0);
			postln("harmony is off");
		}, {
			~harmonizer.set(\amph, z_map);
			postln("harmony is on");

		});

		if (k_map>= 0.8,{
			~dl.set(\mix, 1);
			postln( "delaaaay OFF");

		},
		{
		~dl.set(\mix, k_map);
		});



        //Printing the OSC values:
		postln("Mapped parameter: X: "+ x_map  + " - Y: " + y_map + " - ON/OFF: "+ z_map + " - Delay mix : " + k_map);
	},"/params");

)

(
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

~dl.set(\delTime, 0.3, \decay, 1);s



