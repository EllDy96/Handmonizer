
Server.killAll


( //#1 ======INITIALIZE SC SERVER ======
//if server fails to start and error encountered:  try, try again...it's stubborn sometimes...
o = Server.local.options;
o.sampleRate = 48000;
o.blockSize = 32;
o.inDevice = nil; //"MME : Gruppo microfoni (Realtek High"; //use system default audio input (change value to manually configure input)
o.outDevice = nil; //use system default audio output (change value to manually configure output)
s.latency = 0.02; //0.2 is SC default
s.boot;
)

ServerOptions.devices;
Exception.debug = true;

(
s.scope; // plotting the wave in time domain
FreqScope.new; // ploting the spectogram
)

///////////////////////////////////// MODEL ////////////////////////////////////////////////////

(

// define a table of reference notes [c c# d ... b]
~table = Array.fill(12, {arg i; i + 60}); // [60,61,...,71]

// define a table of mapped notes (Default values)
~mapped = Array.fill(12, {arg i; i + 64}); // starts from e3 the major third from the 75
~mapped2 = Array.fill(12, {arg i; i + 67});//the fifth
~mapped3 = Array.fill(12, {arg i; i + 71});//the octave

~midiON = 0;

// define a table to store the difference between reference and mapped note
~difference = Array.fill(~table.size, {0});
// define a buffer on the server for consultation from the SynthDef
~diffbuf = Buffer.loadCollection(s, ~table, action:{|msg| msg.postln;});

~difference2 = Array.fill(~table.size, {0});
~diffbuf2 = Buffer.loadCollection(s, ~table, action:{|msg| msg.postln;});
~difference3 = Array.fill(~table.size, {0});
~diffbuf3 = Buffer.loadCollection(s, ~table, action:{|msg| msg.postln;});

~difference.do({arg item, i;   ~difference[i] = (~table[i] - ~mapped[i]).midiratio.reciprocal; });// the do methods is used to iterate through a collection doing what you specify to each member of the array
~difference2.do({arg item, i;  ~difference2[i] = (~table[i] - ~mapped2[i]).midiratio.reciprocal;});
~difference3.do({arg item, i; ~difference3[i] = (~table[i] - ~mapped3[i]).midiratio.reciprocal;});

~diffbuf.setn(0, ~difference);
~diffbuf2.setn(0, ~difference2);
~diffbuf3.setn(0, ~difference3);

~diffbuf.postln;

~pitchRatioControlBuses = Array.fill(1, {arg i; Bus.control(s, 1)});

~keyScale = Array.fill(2, {arg i; Bus.control(s, 1)});


)

////pitch ratio function////
(

~pitchRatioCompute = {
	|
	key = 0
	scaleType = 0
	note = 47
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
	   //postln(k);
	   if( note == scaleMIDI[k] , {
	   	  pitch = scaleMIDI[k+2] - scaleMIDI[k] ;
       },
		{
			pitch=0;
		}
		);
});


ratio = (2.pow(1/12)).pow(pitch);

//postln("Ratio :" + ratio);
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

	//amp = Amplitude.kr(in, 0.05, 0.01, 1);
	# freq, hasFreq = Tartini.kr(in);
	midiFundamental = freq.cpsmidi;
	postln(" this is the mid fund: "+ midiFundamental);


	//Out.kr(outMidi, midiFundamental);
    Out.kr(outFreqBus, freq);
	Out.ar(outputBus, in);
}).send(s);

SynthDef.new(\harmonizer, {
	|
	inputBus, inFreqBus, inMidi
	//key = 3, scaleType = 0
    outHarmBus, outVoiceBus
	buffer1, buffer2, buffer3
	amp = 1, amp1 = 1, amp2 = 1, amp3 = 1, amph = 1
	pitch1 = 0, pitch2 = 0, pitch3 = 0
	oct1 = 1
	vibRate = 6
	|

	var in = In.ar(inputBus, 1);
	var partials, voice, harmonics;
    var shift1, shift2, shift3;
	var fundamental, inFreq, out;
	var h1, h2, h3;
	var pitchRatio = In.kr(~pitchRatioControlBuses[0], 1);
	var scaleArray;
	var harmonic1 = 3, harmonic2 = 5;
	var pitch = 0;
	var key = In.kr(~keyScale[0], 1);
	var scaleType= In.kr(~keyScale[1], 1);
	var p1 = 0, p2 = 0, p3 = 0;
	var grains = 2;
	//var inMidi= inFreqBus.cpsmidi;




    /*
	scaleArray = MiscFuncs.getScaleIntervals.matchAt(1);
	postln(scaleArray);
	postln(pitch1);

	(harmonic1-1).do({arg index = 0; p1 = p1+scaleArray[index]});
	(harmonic2-1).do({arg index = 0; p2 = p2+scaleArray[index]});
    postln(p1);
	postln(p2);

	*/

	//fundamental = inFreqBus.cpsmidi.round(1);


	p1 = ~pitchRatioCompute.value(0, 0, 47);
	postln("Semitones :" + p1);

	//h1 = PitchShiftPA.ar(in, inFreqBus, ~pitchRatioCompute.value(key, scaleType, inMidi), ~pitchRatioCompute.value(key, scaleType, inMidi), grainsPeriod: 3);
	h1 = PitchShiftPA.ar(in, inFreqBus, p1, p1, grainsPeriod: 3);
	//h2 = PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(p2), (2.pow(1/12)).pow(p2), grainsPeriod: 3);
	//h3 = PitchShiftPA.ar(in, inFreqBus, (2.pow(1/12)).pow(p3), (2.pow(1/12)).pow(p3));

	//harmonics = Mix.new([amp1*h1, amp2*h2]);
	//harmonics = amph * harmonics;

    Out.ar(outVoiceBus, in);
	Out.ar(outHarmBus, h1);
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

    //out = AllpassN.ar(input, 0.040, [0.040.rand, 0.040.rand], 2);

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
~harmonizer = Synth.new(\harmonizer, [\inputBus, ~trackerOut, \inFreqBus, ~fundamentalBus, \inMidi, ~midiFundamental, \outVoiceBus, ~harmonizerVoice, \outHarmBus, ~harmonizerHarm, \buffer1, ~diffbuf.bufnum, \buffer2, ~diffbuf2.bufnum, \buffer3, ~diffbuf3.bufnum ], ~harmonizerGroup);

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
        y_map = LinLin.ar(y,0,1,0,3); // mapping of the index (increase the modulation amplitude)
        z_map = LinLin.ar(z,0,1,0,1);// mapping of the cut off lpf
		k_map = LinLin.ar(k,0,1,0,6); //  mapping of the Reverb amount

		//~finalSum.set(\gain,x_map);
		//~harmonizer.set(\numVoices,y_map);
		//~rev.set(\wetR, x_map);
        /*
		if ( x_map < 1 ,
			{
				~harmonizer.set(\amp3, 0, \amp2, 0, \amp1, 1);
				~harmonizer.postln;
			},
			if(x_map < 2,
					{ ~harmonizer.set(\amp3, 0, \amp2, 1, \amp1, 1);
					  ~harmonizer.postln;
				},{
					~harmonizer.set(\amp3, 1, \amp2, 1, \amp1, 1);
					~harmonizer.postln;
				}
		));*/

		if ( x_map < 1,
			{
				~harmonizer.set(\oct1, 0.5);
		    },
			if(x_map < 2,
		    {
				~harmonizer.set(\oct1, 1);
			},{
			    ~harmonizer.set(\oct1, 2);
			}
		));

		//~harmonizer.set(\amp, x_map, \amp1, y_map);
		//~harmonizer.set(\pitch1, x_map, \pitch2, y_map);

		if ( z_map < 0.5, {
			~harmonizer.set(\amph, 0);
		}, {
			~harmonizer.set(\amph, 1);
		});

		//~harmonizer.set(\vibRate, k_map);



        //Printing the OSC values:
		postln("Tracking parameter: x : "+ x +" - y : "+ y + " - z: "+ z + "palm slope: " + k);
		postln("Mapped parameter: gain: "+x_map +" - numVoices: "+ y_map +" - Reverb: "+ k_map );
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
	                action: {arg thisSlider; ~pitchRatioControlBuses[0].set(thisSlider.value);

	},
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

    ~voiceTracker = Synth.new(\voiceTracker, [\outputBus,  ~trackerOut, \outFreqBus, ~fundamentalBus, \outMidi, ~midiFundamental], ~inputGroup);

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

~scalePopUp = PopUpMenu(w, Rect(10, 100, 100, 30));
~scalePopUp.items = ['Major', 'Minor'];
~scalePopUp.action_({
	arg n;
	~keyScale[1].set(n.value);
	postln(~keyScale[1].get);
});
~keyPopUp= PopUpMenu(w, Rect(10, 10, 100, 30));
~keyPopUp.items = ['a', 'c'];
~keyPopUp.action_({
	arg n;
	~keyScale[0].set(n.value);
	postln(~keyScale[0].get);
});
)



~voiceTracker = Synth.new(\voiceTracker, [\outputBus,  ~trackerOut], ~inputGroup);
~voiceTracker.run(true);
~voicetracker.run(false);
~voiceTracker.set(\gain, 1);
~voiceTracker.set(\gain, 0.5);
~voiceTracker.set(\gain, 0);
~voiceTracker.free;

~finalBus.inspect;
s.trace;

