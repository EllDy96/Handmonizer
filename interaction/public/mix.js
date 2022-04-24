export default class Mix {
  constructor(canvasWidth, canvasHeight, div) {

    this.myP5 = new p5(function (p5) {
      p5.paramMaxWidth = 0;
      p5.paramMaxHeight = 0;
      p5.paramter;

      p5.setup = function () {
        p5.createCanvas(canvasWidth, canvasHeight, p5.WEBGL) // dimensione del canvas
        p5.angleMode(p5.DEGREES)

      };

      p5.draw = function () {
        p5.background(30)


        p5.noFill() // considera circonferenze e non cerchi
        p5.stroke(300) // aumenta intensità del colore delle circonferenze

        for (var i = 0; i < 40; i++) {

          var r = p5.map(p5.cos(p5.parameter), -1, 1, 100, 200)
          var g = p5.map(i, 0, 20, 100, 200)
          var b = p5.map(p5.sin(p5.parameter), -1, 1, 200, 100)

          p5.stroke(r, g, b)

          p5.rotate(p5.frameCount / 10)

          p5.beginShape()
          for (var j = 0; j < 360; j += 90) {
            var rad = (i) * (1 + p5.parameter / 150) // aumenta raggio dei cerchi
            var x = rad * p5.cos(j)
            var y = rad * p5.sin(j)
            var z = p5.sin(p5.frameCount) + p5.parameter / 2 //*A modifico ampiezza dell'oscillazione

            p5.vertex(x, y, z)
          }
          p5.endShape(p5.CLOSE)
        }
      }

      p5.resetWindowSize = function (w, h) {
        p5.resizeCanvas(w, h, true)
      }

    }, div);
  }

}