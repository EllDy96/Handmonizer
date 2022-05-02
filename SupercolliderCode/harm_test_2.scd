
Server.killAll


( //#1 ======INITIALIZE SC SERVER ======
//if server fails to start and error encountered:  try, try again...it's stubborn sometimes...
o = Server.local.options;
o.sampleRate = 44100;
o.blockSize = 512;
o.inDevice = nil; //"MME : Gruppo microfoni (Realtek High"; //use system default audio input (change value to manually configure input)
o.outDevice = nil; //use system default audio output (change value to manually configure output)
s.latency = 0.05; //0.2 is SC default
s.boot;
)

ServerOptions.devices;

(
s.scope;// plotting the wave in time domain
FreqScope.new // ploting the spectogram
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
//~pitchRatioControlBuses = Bus.control(s, 1);


)

//////SYNTHS///////

(
SynthDef.new(\voiceTracker, {
    |
    outputBus, outFreqBus
    |

    var in, amp, freq, hasFreq, out;

    in = Mix.new(SoundIn.ar([0,1]));

	amp = Amplitude.kr(in, 0.05, 0.01, 1);
    # freq, hasFreq = Pitch.kr(in);

    //Out.kr(outFreqBus, freq);
	Out.ar(outputBus, in);
}).send(s);


SynthDef.new(\harmonizer, {
	|
	inputBus, inFreqBus
    outHarmBus, outVoiceBus
	buffer1, buffer2, buffer3
	amp = 1, amp1 = 1, amp2 = 1, amp3 = 1
	pitch = 0
	|

	var in = In.ar(inputBus, 1);
	var partials, voice, harmonics;
    var shift1, shift2, shift3;
	var fundamental, inFreq, out;
	var h1, h2, h3;
	var pitchRatio = In.kr(~pitchRatioControlBuses[0], 1);

	//fundamental = inFreqBus.cpsmidi.round(1);

	//shift1 = WrapIndex(buffer1, fundamental);
	//shift2 = WrapIndex.kr(buffer2.midicps.round(1),fundamental);
	//shift3 = WrapIndex.kr(buffer3.midicps.round(1),fundamental);

	h1 = PitchShift.ar(in, 0.2, (2.pow(1/12)).pow(pitch), 0.0, 0.0, amp1);
	//h2 = PitchShift.ar(in, 0.2, (2.pow(1/12)).pow(pitchRatio), 0.0, 0.0, amp2);
	//h3 = PitchShift.ar(in, 0.2, (2.pow(1/12)).pow(pitchRatio), 0.0, 0.0, amp3);

	//harmonics = Mix.new([amp1*h1, amp2*h2, amp3*h3]);

    Out.ar(outVoiceBus, amp*in);
	Out.ar(outHarmBus, amp1*h1);
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

	Out.ar(outputBus, out);
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
//~fundamentalBus = Bus.control(s, 1);

// Create the groups
~inputGroup = Group.new;
~harmonizerGroup = Group.after(~inputGroup);
~outputGroup = Group.after(~harmonizerGroup);

// instances of the various model Synth
~harmonizer = Synth.new(\harmonizer, [\inputBus, ~trackerOut, \outVoiceBus, ~harmonizerVoice, \outHarmBus, ~harmonizerHarm, \buffer1, ~diffbuf.bufnum, \buffer2, ~diffbuf2.bufnum, \buffer3, ~diffbuf3.bufnum ], ~harmonizerGroup);

~finalSum = Synth.new(\finalSum, [\inputVoiceBus, ~harmonizerVoice, \inputHarmBus, ~harmonizerHarm], ~outputGroup);
)


///// GUI //////



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


		x_map= LinLin.ar(x,0,1,-12,12).round.asInteger;// mapping the feedback
        y_map= LinLin.ar(y,0,1,0,2); // mapping of the index (increase the modulation amplitude)
        z_map= LinLin.ar(z, 0, 1, 20,2000);// mapping of the cut off lpf
		k_map= LinLin.ar(k,0,1,0,10); //  mapping of the Reverb amount

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
		));   */

		//~harmonizer.set(\amp, x_map, \amp1, y_map);
		~harmonizer.set(\pitch, x_map);

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
					controlSpec: ControlSpec(minval: -12, maxval: 12, warp: \lin, step: 1, units: \semitones),
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

    ~voiceTracker = Synth.new(\voiceTracker, [\outputBus,  ~trackerOut], ~inputGroup);

});

~b2 = Button(w, Rect(100, 50, 50, 50));
~b2.string = "OFF";
~b2.action_({

    ~voiceTracker.free;

});

~b3 = Button(w, Rect(200, 50, 100, 50));
~b3.string = "EXIT";
~b3.action_({Window.closeAll});

)



~voiceTracker = Synth.new(\voiceTracker, [\outputBus,  ~trackerOut], ~inputGroup);
~voiceTracker.run(true);
~voicetracker.run(false);
~voiceTracker.set(\gain, 1);
~voiceTracker.set(\gain, 0.5);
~voiceTracker.set(\gain, 0);
~voiceTracker.free;

~finalBus.inspect;

