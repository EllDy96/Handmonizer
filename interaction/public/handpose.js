import onChangeData from "./main.js"

export default class HandposeSketch {
  constructor(canvasWidth, canvasHeight, videoWidth, videoHeight, div) {
    //Hanpose model
    let handpose;
    let video;
    let predictions = [];

    //Control parameters
    let centroid = [];
    let palmMiddleFinger;
    let palmMiddleSlope;
    let palmBaseCoord = [];
    let middleFingerCoord = [];

    //Server
    let socket;
    let data;

    this.myP5 = new p5(function (p5) {
      //Webcam max supported resolution
      p5.paramMaxWidth = 0;
      p5.paramMaxHeight = 0;

      p5.setup = function () {
        //Server connection
        socket = io.connect('http://localhost:55123')

        //Canvas creation and webcam stream capture
        p5.createCanvas(videoWidth, videoHeight);
        video = p5.createCapture(p5.VIDEO);
        video.size(videoWidth, videoHeight);

        //Model init
        handpose = ml5.handpose(video, p5.modelReady);


        // This sets up an event that fills the global variable "predictions"
        // with an array every time new hand poses are detected
        handpose.on("predict", results => {
          predictions = results;
          p5.computeCentroidAndInertia();
        });

        // Hide the video element, and just show the canvas
        video.hide();

        //Centroid init
        centroid = [0, 0];

      }

      p5.draw = function () {
        //Drawing the webcam feed
        p5.translate(canvasWidth, 0);
        p5.scale(-canvasWidth / videoWidth, canvasHeight / videoHeight);
        p5.image(video, 0, 0, p5.width, p5.height);


        // Drawing all keypoints and the skeletons
        p5.drawKeypoints();
      }

      p5.resetWindowSize = function (w, h) {
        //Reset the canvas size
        canvasWidth = w;
        canvasHeight = h;
        console.log(canvasWidth, canvasHeight)
        //p5.resizeCanvas(w, h, true)
        //video.size(p5.width, p5.height);
      }

      // Draw hand skeleton and control parameters
      p5.drawKeypoints = function () {

        for (let i = 0; i < predictions.length; i += 1) {
          const prediction = predictions[i];

          let k = 0;
          for (let j = 0; j < prediction.landmarks.length; j += 1) {
            let keypoint = prediction.landmarks[j];
            p5.fill(179 + k, 255 + k, 240 + k);
            p5.noStroke();
            p5.ellipse(keypoint[0], keypoint[1], 10, 10);
            k -= 10;

            //Centroid draw
            p5.fill(0, 255, 0);
            p5.noStroke();
            p5.ellipse(centroid[0], centroid[1], 10, 10);

            //palmMiddleFinger draw
            p5.stroke(255);
            p5.line(palmBaseCoord[0], palmBaseCoord[1], middleFingerCoord[0], middleFingerCoord[1]);
          }
        }
      }

      p5.modelReady = function () {
        console.log("Model ready!");
      }

      //Computation of all the parameters
      p5.computeCentroidAndInertia = function () {
        centroid = [0, 0];
        palmMiddleFinger = 0;

        for (let i = 0; i < predictions.length; i += 1) {
          const prediction = predictions[i];

          for (let j = 0; j < prediction.landmarks.length; j += 1) {
            const keypoint = prediction.landmarks[j];

            //Centroid x computation
            centroid[0] += keypoint[0] / prediction.landmarks.length;

            //Centroid y computation
            centroid[1] += keypoint[1] / prediction.landmarks.length;


            //Palm-middleFinger distance
            palmBaseCoord = [prediction.annotations.palmBase[0][0], prediction.annotations.palmBase[0][1]];
            middleFingerCoord = [prediction.annotations.middleFinger[3][0], prediction.annotations.middleFinger[3][1]];

            palmMiddleFinger = Math.sqrt(Math.pow(palmBaseCoord[0] - middleFingerCoord[0], 2) +
              Math.pow(palmBaseCoord[1] - middleFingerCoord[1], 2));

            //Slope 
            palmMiddleSlope = Math.abs(Math.atan((middleFingerCoord[1] - palmBaseCoord[1]) / (middleFingerCoord[0] - palmBaseCoord[0])) * 180 / 3.14159);
          }

          //Tell main that data is changed
          onChangeData(centroid, palmMiddleFinger, palmMiddleSlope);

          //Normalizing the data [0,1]
          let centroidSend = [0, 0]
          centroidSend[0] = 1 - centroid[0] / p5.paramMaxWidth;
          centroidSend[1] = 1 - centroid[1] / p5.paramMaxHeight;
          let palmMiddleFingerSend = palmMiddleFinger / p5.paramMaxHeight;
          let palmMiddleSlopeSend = palmMiddleSlope / 90;

          console.log(centroidSend[0], centroidSend[1], palmMiddleFingerSend, palmMiddleSlopeSend)


          //Sending the data to the server
          data = {
            centroid: centroidSend,
            palmMiddleFinger: palmMiddleFingerSend,
            palmMiddleSlope: palmMiddleSlopeSend
          }

          //console.log("Sending data!", data.centroid[1])
          socket.emit('centroidAndPalmMiddleFinger', data);

        }
      }
    }, div);

  }
}