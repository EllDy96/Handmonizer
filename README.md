# Handmonizer: An Artist-Oriented Vocal Improvization Tool
<p align="center">
  <img src="https://github.com/EllDy96/Handmonizer/blob/main/Report/artisticProjectArchitecture.png" width="65%" height="65%" >
</p>


The implementation of Handmonizer, a vocal harmonizer which changes its behaviour using hand motion recognition. The user can change the harmonic patterns if the harmonizer by simply moving their hand in front of a webcam while singing. In addition to that, they can switch between different patches using a MIDI controller to create different harmonic voices. 
There is also a second version where the user can set a specific scale and the harmonization will stay inside that scale. In this case, the hand motion interaction is the same, however the MIDI controller can only be used to control some parameters with the knobs, without changing between patches.

# How to use
To run the SuperCollider code you need to include the two classes cointained in [External Classes](https://github.com/EllDy96/Handmonizer/tree/main/SupercolliderCode/External%20classes) folder into the  SuperCollider external library folder on your computer.
Then you should install the PitchShiftPA class by simply typing and running *Quarks.gui* on SuperCollider. A window with all the available quarks will appear, where you find and install PitchShiftPA.

To run the hand motion recognition web application you need to have [node.js](https://nodejs.org/en/download/) installed on your computer.

In order to use the application you need a webcam and microphone. Clone the repository and inside the Interaction folder run the server using Node.js with the command `node .\server.js` from the PoweShell terminal. Then connect to the url `localhost:55123` in a browser (it may take some seconds to load the ML model). Open Hanmonizer.scd (or scale_handmonizer.scd) in SuperColliderCode folder and run the code following the instructions in the comments.

# Handmonizer Implementation

The Handmonizer structure is based on a node server that allows the communication between the two main parts: the hand gesture recognition and the real time sound harmonization algorithm which communicate through OSC messages. Moreover, a MIDI controller is connected with the harmonizer to switch between different patches during the live performance. In this section we first describe each component separately and finally their communication and parameter mapping.

## Hand Gesture Recognition

The harmonizer can be controlled through hand gestures captured from a webcam. For the hand pose recognition, we use one pre-trained model from [ml5.js](https://ml5js.org}{https://ml5js.org), a JavaScript framework for creative coding built on top of TensorFlow.js that allows the use of GPU-accelerated machine learning algorithms in a web browser. The TensorFlow ecosystem provides an easy-to-use tool to convert pre-trained ML models trained in Python or C++ into web targets. Some of these models were specifically designed with creative applications in mind to facilitate the development of real-time music related Web-application.
We use the model called [Handpose](https://learn.ml5js.org/#/reference/handpose) that performs hand-skeleton finger tracking. It takes the video stream frame by frame and returns the coordinates of 21 hand keypoints over the palm of the hand as shown in this figure.
<p align="center">
  <img src="https://github.com/EllDy96/Handmonizer/blob/main/Report/hand.png" >
</p>

This process is GPU intensive. To achieve the best performance a system with a dedicated GPU is advised.
Based on the coordinates of these 21 points we compute three main parameters

  1. The hand centroid: displayed as the light-green central dot is the arithmetic mean position of the 21 dots.
  2. The palm length: defined as the distance between the tip of the middle finger and the base of the palm (displayed as the length of the white line)
  3. The hand orientation: computed as the slope of the white lines between 0 and pi.

With a custom mapping of that three parameters we define 5 hand gestures that the user can use to change the harmonizer settings in real time.
We retrieve the two coordinates of the centroid in the screen \(x_c, y_c\) and we map each to a specific parameter. 
The palm length is used to implement two gestures. The user could  close the hand to fade out the harmonics or we could move the hand further or closer to the screen to modified the volumes of the harmonized voices. In that way we are able to also map the z-position of the hand in the space.
The palm slope controls the amount of effect (Reverb or Delay) that the user wants to add to the voice, as a dry-wet knob; when the white line is perpendicular to the bottom border the voice has no effect, while it reaches its maximum value when the line is parallel to the lower border. 

## Harmonizer 

The audio signal processing part of the Handmonizer is developed entirely on SuperCollider. The algorithm of the harmonizer is composed of separate pieces of code, including pitch tracking and shifting, effects and communication protocol definitions (OSC, MIDI) for parameter mapping. Here we explain each component separately.

### Pitch tracking and shifting

The very first part of the harmonizer aims at recognizing the signal input. Since we need to perform pitch shifting in order to create harmonic voices, the first thing we need to do is track the fundamental frequency of the input audio signal. For this purpose we use an external class called Tartini instead of the standard Pitch class from SuperCollider since it performs the pitch tracking more precisely and in a shorter amount of time. 
To avoid harmonies that sound very unnatural, the pitch shifting needs to be performed using the Pitch-Synchronous Overlap and Add (PSOLA). One of the main advantages of this method is the preservation of the formant positions (spectral envelope) which allows us to keep the original timber. Here we use a SuperCollider class called PitchShiftPA which is based on PSOLA. We pass the fundamental frequency value tracked Tartini as well as the pitch shift ration which we fix depending on the harmony we want to achieve. The same procedure is used to generate three harmonic voices, both higher and lower with respect with the input signal (six voices in total). The harmonic voices are mixed together in a separate channel so they can be processed without affecting the lead voice. 

### Patches and effects

As mentioned previously, one of the main features needed by the artist is the possibility to switch interactively between different settings. We defined 4 patches following the specifications from the artist: 3rd - 5th; 4th - 5th - 7th; 4th - augmented 4th - 7th; octaver.
These patches include a delay effect that can also be controlled by the user. 
The harmonizer also includes two patches that allow the artist to control only the effect amount for the reverb and delay without having any harmony. These two patches can be used for single voice improvisations over looped backing tracks.

### Crossfading

A special feature of the Handmonizer is the smooth transition between the voices, creating different patterns during the performance without have any sudden jumps in volume level. Here we manipulate the different amplitudes of each voice group before mixing them. A similar procedure is used for the volume fader of the harmonies for which we use a dB scale mapping for a more natural level perception. Finally, wee use XFade2 as a cross-fade knob to control the dry/wet ration for the reverb and delay effects.

### In-scale harmonizer

Finally, we developed a second version in a separate script file. Instead of fixed intervals, the Handmonizer can be used as a classic harmonizer following a specific scale, where the user can set the key and scale type (major, minor, etc). By hard-coding the first MIDI note for each key, we use an external class called MiscFuncs to retrieve the array of MIDI notes for the selected scale. Then to retrieve in real time the precise MIDI note sang by the singer, we use another external class called MyKFiddle. Finally, the algorithm checks if the input note is part of the scale. If this is the case, it computes the pitch ratio and feeds it to the pitch shifter. 
The two classes mentioned above, are developed by [Matthew Yee King](https://github.com/yeeking/myksupercollider) and slightly modified by us to be better adapted to our purpose.


![image](https://github.com/EllDy96/Handmonizer/blob/main/Report/projectArchitecture.png)

## Communication Protocols And Architecture

To switch between patches, we use a MIDI controller where we assign each pad to a patch by changing the necessary parameters. In addition to the patches mentioned above, we use one pad as an ON/OFF toggle button and another pad as a bypass for the harmonic voices. 
The user interface is hosted as a web page/application in an Express server, the connection is set up through the framework Socket.io. All the control parameters mentioned above are computed in the client and then sent to the server. From the server, the parameters are written in OSC messages and forwarded to SuperCollider. 
The hand motion recognition features are sent to SuperCollider as OSC messages in real time and are used to control different parameters that define the harmonizer's performance. We use the x-coordinate of the palm centroid to add more voices as we move from left to right. We can imagine the screen divided into three columns where on the first we only have one additional voice and every time we visit the next column we add one more voice. Similarly, we map the y-coordinate as a switch between low octave and high octave harmonics. We can imagine the screen divided into two rows where the upper row represents the high octave harmonics and the bottom row represents the low octave harmonics. All these changes in number of voices and octaves are performed in a smooth way as explained previously, so the artist can explore different sounds.
Another feature that we use is the palm length represented by the white line in the first figure. We have mapped this feature to the harmony fader using a dB scale to control the volume of the harmonic voices. There are two ways to exploit this feature. The first and most intuitive way is to open and close our hand and the second is to move our hand back and forth. If the artist wants to emphasise the harmonic voices she can simply move her hand closer to the camera.
Finally, we use the hand orientation as an imaginary knob that controls the dry/wet level of the reverb or delay effects. When we keep our hand straight we have a fully dry signal (e.g.: no effect). While we rotate our hand either left or right we add the amount of the wet signal and decrease the amount of the dry signal using a cross-fade effect. 

# Artist Oriented System

<p align="center">
  <img src="https://github.com/EllDy96/Handmonizer/blob/main/Report/IMG_9934.jpeg" width="50%" height="50%" >
</p>




This project was tailored to a specific artist, the well-known Italian singer Maria Pia De Vito. We developed this system in collaboration with her, aiming to enhance her One-Woman-Band live performance. We designed everything following her needs, collecting her feedback in each step. This is a proof of concept design that can be improved in order to be more robust so that it can be used as an improvisation tool in a live concert. 
The artist was able to try the Handmonizer in two different workshops. On the first workshop we presented her with a basic prototype to collect her feedback on the main features. During the second workshop, she was able to try an improved version that included more features according to her indications. 
<p align="center">
  <img src="https://github.com/EllDy96/Handmonizer/blob/main/Report/mariapia_demo.jpg" width="50%" height="50%">
</p>
Finally, we defined an evaluation strategy for artist-oriented tool like that, collecting feedback with a questionnaire addressed to the singer. The aim of the latter is to help other engineers that would like to develop cutting-edge technologies working alongside artists. Here we present her [response](https://github.com/EllDy96/Handmonizer/blob/main/Report/MariapiaEvaluationQuestionaire.pdf).

# Acknowledgements

The authors would like to thank everyone involved in this project. First of all, the singer Maria Pia De Vito for her availability, her kindness and her positivity in introducing some novelty in her performance. A special thanks to Augusto Sarti for creating and organizing this brilliant team. Luca Comanducci for his constant feedback concerning the implementation and report writing. Special thanks to the two professors from Goldsmiths University of London. Mark D'Inverno for his insight concerning the evaluation procedure and Mathew Yee King for his availability and valuable SuperCollider support.

# Authors
Antonios Pappas
Davide Lionetti
