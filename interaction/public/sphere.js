export default class Sphere {
    constructor(canvasWidth, canvasHeight, div) {

        this.myP5 = new p5(function (p5) {
            p5.paramMaxWidth = 0;
            p5.paramMaxHeight = 0;
            p5.parameter = [0, 0];

            p5.setup = function () {
                p5.createCanvas(canvasWidth, canvasHeight, p5.WEBGL);

            };

            p5.draw = function () {
                p5.background(55);

                p5.noFill()
                p5.stroke(255)

                p5.rotateX(p5.frameCount / 50)
                for (var i = 0; i < 220; i++) {
                    p5.push()

                    var r = p5.map(p5.sin(i + p5.frameCount), -1, 1, 200, 50)
                    var g = p5.map(p5.sin(i + p5.frameCount / 3), -1, 1, 50, 200)
                    var b = p5.map(p5.cos(i + p5.frameCount / 7), -1, 1, 50, 200)

                    p5.stroke(r, g, b)

                    p5.rotateY(i / 4)
                    p5.rotateX(i / 4)

                    
                    p5.ellipse(0, 0, -i / 2 + p5.map(p5.paramMaxWidth - p5.parameter[0], 0, p5.paramMaxWidth, 0, 500))
                    p5.triangle(5, 0, i / 6 - 10 * p5.map(p5.paramMaxHeight - p5.parameter[1], 0, p5.paramMaxHeight, -30, 30), i / 80, i / 80, i / 80)

                    p5.pop()
                }
            }

            p5.resetWindowSize = function (w, h) {
                p5.resizeCanvas(w, h, true)
            }

        }, div);
    }

}