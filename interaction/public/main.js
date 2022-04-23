import HandposeSketch from "./handpose.js";
import Sketch from "./sketch.js"
import Mix from "./mix.js"
import Tilt from "./tilt.js"
import Sphere from "./sphere.js"

//Init layout
let w = window.innerWidth;
let h = window.innerHeight;
let handposeCanvasDiv = document.getElementById("handposeDiv")
let modCanvasDiv = document.getElementById("modDiv")
let mixCanvasDiv = document.getElementById("fxDiv")
let tiltCanvasDiv = document.getElementById("tiltDiv")
let firstColumn = document.getElementsByClassName("first_col")
let secondColumn = document.getElementsByClassName("second_col")

//Check webcam resolution
let constraints = {
    audio: true,
    video: {
        width: { ideal: 1920 },
        height: { ideal: 1080 }
    }
};

let stream = await navigator.mediaDevices.getUserMedia(constraints);

let stream_settings = stream.getVideoTracks()[0].getSettings();

// Actual width & height of the camera video
let stream_width = stream_settings.width;
let stream_height = stream_settings.height;

//Handpose canvas and tilt canvas sizes
let aspectRatio = stream_width / stream_height;
let firstTwo = 3 / 5 * w;
let handposeCanvasWidth = firstTwo;
let tiltCanvasWidth = firstTwo;
let handposeCanvasHeight = (1 / aspectRatio) * handposeCanvasWidth;
let tiltCanvasHeight = h - handposeCanvasHeight;



//Mod canvas and mix canvas sizes
let secondTwo = w - firstTwo;
let modCanvasWidth = secondTwo;
let mixCanvasWidth = secondTwo;
let modCanvasHeight = h / 2;
let mixCanvasHeight = h - modCanvasHeight;

//Setting divs sizes
handposeCanvasDiv.style.width = handposeCanvasWidth;
handposeCanvasDiv.style.height = handposeCanvasHeight;

modCanvasDiv.style.width = modCanvasWidth;
modCanvasDiv.style.height = modCanvasHeight;

mixCanvasDiv.style.width = mixCanvasWidth
mixCanvasDiv.style.height = mixCanvasHeight

tiltCanvasDiv.style.width = tiltCanvasWidth
tiltCanvasDiv.style.height = tiltCanvasHeight

let firstColStyle = handposeCanvasHeight + "px " + tiltCanvasHeight + "px"
let secondColStyle = modCanvasHeight + "px " + mixCanvasHeight + "px"
firstColumn[0].style.gridTemplateRows = firstColStyle
secondColumn[0].style.gridTemplateRows = secondColStyle




//Creation of p5 sketches instances
let hadnposeSkecth = new HandposeSketch(handposeCanvasWidth, handposeCanvasHeight, stream_width, stream_height, document.getElementById("handposeDiv"));
let sphere = new Sphere(modCanvasWidth, modCanvasHeight, document.getElementById("modDiv"));
let mix = new Mix(mixCanvasWidth, mixCanvasHeight, document.getElementById("fxDiv"));
let tilt = new Tilt(tiltCanvasWidth, tiltCanvasHeight, document.getElementById("tiltDiv"));

let videoCanvas = document.getElementById("defaultCanvas0")
//videoCanvas.style.width = handposeCanvasWidth
//videoCanvas.style.height = handposeCanvasWidth / aspectRatio

sphere.myP5.paramMaxWidth = stream_width;
sphere.myP5.paramMaxHeight = stream_height;
hadnposeSkecth.myP5.paramMaxWidth = stream_width;
hadnposeSkecth.myP5.paramMaxHeight = stream_height;


//Window resize event listening
window.addEventListener('resize', resizeAll)

//Resize all the canvases when windows size changes
function resizeAll() {
    w = window.innerWidth;
    h = window.innerHeight;
    console.log(window.innerWidth, window.innerHeight)

    firstTwo = 3 / 5 * w;
    handposeCanvasWidth = firstTwo;
    tiltCanvasWidth = firstTwo;
    handposeCanvasHeight = (1 / aspectRatio) * handposeCanvasWidth;
    tiltCanvasHeight = h - handposeCanvasHeight;

    secondTwo = w - firstTwo;
    modCanvasWidth = secondTwo;
    mixCanvasWidth = secondTwo;
    modCanvasHeight = h / 2;
    mixCanvasHeight = h - modCanvasHeight;

    //Setting divs sizes
    handposeCanvasDiv.style.width = handposeCanvasWidth;
    handposeCanvasDiv.style.height = handposeCanvasHeight;

    //videoCanvas.style.width = handposeCanvasWidth
    //videoCanvas.style.height = handposeCanvasWidth / aspectRatio

    modCanvasDiv.style.width = modCanvasWidth;
    modCanvasDiv.style.height = modCanvasHeight;

    mixCanvasDiv.style.width = mixCanvasWidth
    mixCanvasDiv.style.height = mixCanvasHeight

    tiltCanvasDiv.style.width = tiltCanvasWidth
    tiltCanvasDiv.style.height = tiltCanvasHeight

    firstColStyle = handposeCanvasHeight + "px " + tiltCanvasHeight + "px"
    secondColStyle = modCanvasHeight + "px " + mixCanvasHeight + "px"
    firstColumn[0].style.gridTemplateRows = firstColStyle
    secondColumn[0].style.gridTemplateRows = secondColStyle

    hadnposeSkecth.myP5.resetWindowSize(handposeCanvasWidth, handposeCanvasHeight)
    sphere.myP5.resetWindowSize(modCanvasWidth, modCanvasHeight)
    mix.myP5.resetWindowSize(mixCanvasWidth, mixCanvasHeight)
    tilt.myP5.resetWindowSize(tiltCanvasWidth, tiltCanvasHeight)
}


//Pass the control parameters to the visualization  canvases
export default function onChangeData(centroidData, palmMiddleFingerData, palmMiddleSlopeData) {
    tilt.myP5.parameter = palmMiddleSlopeData;
    sphere.myP5.parameter = centroidData;
    mix.myP5.parameter = palmMiddleFingerData;
}