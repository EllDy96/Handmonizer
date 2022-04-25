
Server.killAll



( //#1 ======INITIALIZE SC SERVER ======
//if server fails to start and error encountered:  try, try again...it's stubborn sometimes...
o = Server.local.options;
o.sampleRate = 44100;
o.blockSize = 512;
o.inDevice = "IN 3-4 (3- BEHRINGER UMC 404HD "; //"MME : Gruppo microfoni (Realtek High"; //use system default audio input (change value to manually configure input)
o.outDevice ="MME : OUT 1-2 (3- BEHRINGER UMC 404HD" ;//"OUT 3-4 (4- BEHRINGER UMC 404HD "; //use system default audio output (change value to manually configure output)
s.latency = 0.05; //0.2 is SC default
s.boot;
)

ServerOptions.devices;
o.inDevice = "MME : Gruppo microfoni (Realtek High";
o.outDevice= "OUT 3-4 (3- BEHRINGER UMC 404HD"
s.boot;
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

)

// Voice tracking & harmonization"C:/Users/david/GitHubRepos/myksupercollider/scooterworks_finn_2008_sc/loops.sc"

(

SynthDef.new(\voiceTracker, {
    |
    outputBus, outFreqBus
    |

    var in, amp, freq, hasFreq, out;
	var t, midinum;
	var harmony, harmony2, partials;

    in = Mix.new(SoundIn.ar([0,1]));// this take the input stereo inut signal

	amp = Amplitude.kr(in, 0.05, 1);
    # freq, hasFreq = Pitch.kr(in);// hasFreq is a true/false tells wheter the pitch is been detected or not

    Out.kr(outFreqBus, freq);
	Out.ar(outputBus, in);
}).send(s);

// the synth which computes the harmonizations with the use of buffers, modified by the GUI
 SynthDef.new(\harmonizerGUI,{
    |
    inputBus, inFreqBus, numVoices = 1
	buffer1, buffer2, buffer3
    voiceOutBus, harmonicsOutBus, gain = 5
    |

	var in = In.ar(inputBus, 1);//read the input buss
	var amp, freq, hasFreq;
	var partials, partials2, partials3, voice, harmonics, par;
    var shift1, shift2, shift3;
	var fundamental, inFreq;


	inFreq = In.kr(inFreqBus, 1);
	fundamental = inFreq.cpsmidi.round(1); // convert from freq to midi note

    // the shift quantities used to compute the new pitch shifted harmonies

	par = Array.new;

	shift1 = WrapIndex.kr(buffer1, fundamental);
	shift2 = WrapIndex.kr(buffer2, fundamental);
	shift3 = WrapIndex.kr(buffer3, fundamental);

	//We saved into partials harmonized pitches array starting from one octava bellow to one octave above
    partials = [
        0.5*shift1,
		1*shift1
    ];
	partials2 = [
        0.5*shift1,
		1*shift1,
		0.5*shift2,
		1*shift2
    ];
	partials3 = [
        0.5*shift1,
		1*shift1,
		0.5*shift2,
		1*shift2,
		0.5*shift3,
		1*shift3
    ];

	par = [partials, partials2, partials3];
	postln(par[2]);
	/*numVoices.do({
		shift = WrapIndex.kr(buffer1, fundamental);
		partials = partials.add(0.5*shift);
		partials = partials.add(shift);
	})*/

    // split two cases: main voice (uneffected and harmonies)
	voice = Mix.new(PitchShift.ar(in, 0.2, 1, 0, 0.004)); //A time domain granular pitch shifter. Grains have a triangular amplitude envelope and an overlap of 4:1, and use linear interpolation of the buffer.
	harmonics = PitchShift.ar(in, 0.2, par[2], 0, 0.004,gain);
	//println(par[2]);
	//postln(numVoices.type);
	Out.ar(voiceOutBus, voice);
	Out.ar(harmonicsOutBus, harmonics);
}).send(s);

 //final summing synth
SynthDef.new(\finalSum, {
    |
    inputBus, outputBus = 0, numVoices = 8, gain = 1
    |

	var input;
    var out;

	input = In.ar(inputBus, 1);

    numVoices.do({
        out = gain*AllpassN.ar(input, 0.040, [0.040.rand, 0.040.rand], 2)
    });

    Out.ar(outputBus, out);
}).send(s);

)

//   EFFECTS

(

SynthDef.new(\reverbEffect, {
    |
    inputBus, outputBus, wetR = 0
    |

    // room size
    var source;
    var reverb;
    var mixReverbed;
	var dry;

	dry = 1 - wetR;
	source = In.ar(inputBus, 1);
	reverb = GVerb.ar(source, 20, 6, 0.5, 1, 100, dry, 0.5, 0.4);

	//mixReverbed = (reverb * wetR) + source * (1 - wetR);
    mixReverbed = Mix([source*(1-wetR), reverb*wetR]);

    Out.ar(outputBus, mixReverbed);
}).send(s);

)



(

// create the busses

~root;
~trackerOut = Bus.audio(s, 1);
~harmonizerOut = Bus.audio(s, 8);
~finalBus = Bus.audio(s, 1);

// this bus contains the frequency of the note sung by the user
~fundamentalBus = Bus.control(s, 1); // used for control not as audio signal

// effect bus
~revIn = Bus.audio(s, 1);

// Create the groups
~inputGroup = Group.new;
~harmonizerGroup = Group.after(~inputGroup);

~outputGroup = Group.after(~harmonizerGroup);
// uncomment this to add the effects bus
//~effectsGroup = Group.after(~harmonizerGroup);
//~outputGroup = Group.after(~effetcsGroup);


// instances of the various model Synth
~harmonizer = Synth.new(\harmonizerGUI, [\inputBus, ~trackerOut, \inFreqBus, ~fundamentalBus, \voiceOutBus, ~finalBus, \harmonicsOutBus, ~harmonizerOut, \buffer1, ~diffbuf.bufnum, \buffer2, ~diffbuf2.bufnum, \buffer3, ~diffbuf3.bufnum ], ~harmonizerGroup );

//instance of the effect
//~rev = Synth.after(~harmonizer, \reverbEffect, [\inputBus, ~revIn, \outputBus, ~dlIn], ~effectsGroup);


~finalSum = Synth.new(\finalSum, [\inputBus, ~finalBus], ~outputGroup);

)

(

NetAddr("127.0.0.1",57120);

OSCdef('OSCreceiver',
	{
		arg msg;
		var x_map, y_map, z_map, k_map;

		x = msg[1]; // x centroid  -> feedback     ->the sphere radius
		y = msg[2];//  y  centroid -> index        ->the spere rays
        z = msg[3];// palm length  -> LPF cut-off  ->the double squares
		k = msg[4];// palm slope   -> Reverb amount->the square magnitude


		x_map= LinLin.ar(x,0,1,0,1);// mapping the feedback
        y_map= LinLin.ar(y,0,1,0,2).round.asInteger; // mapping of the index (increase the modulation amplitude)
        z_map= LinLin.ar(z, 0, 1, 20,2000);// mapping of the cut off lpf
		k_map= LinLin.ar(k,0,1,0,10); //  mapping of the Reverb amount

		~finalSum.set(\gain,x_map);
		//~harmonizer.set(\numVoices,y_map);
		//~rev.set(\wetR, x_map);


        //Printing the OSC values:
		postln("Tracking parameter: x: "+x+" - y: "+ y + " - z: "+ z);
		postln("Mapped parameter: gain: "+x_map +" - numVoices: "+ y_map +" - Reverb: "+ k_map );
	},"/params");

)


~root = Synth(\voiceTracker, [\outputBus,  ~trackerOut, \outFreqBus, ~fundamentalBus], ~inputGroup);



~finalSum.set(\gain,0.5);
~harmonizer.set(\numVoices,1);
~harmonizer.set(\gain,0);
~rev.set(\wetR, -5);
