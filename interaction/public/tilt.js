export default class Tilt {

    constructor(canvasWidth, canvasHeight, div) {


        this.myP5 = new p5(function (p5) {
            p5.parameter = 0;

            p5.setup = function () {
                p5.createCanvas(canvasWidth, canvasHeight);

                p5.noStroke();
                p5.rectMode(p5.CENTER);

            };

            p5.draw = function () {
                p5.background(75)


                let r1 = p5.map(p5.parameter, 0, 90, 0, p5.height);
                let r2 = p5.height - r1;


                p5.fill(190, 252, 255);


                p5.rect(p5.width / 2 + r1 / 2, p5.height / 2, r1, r1);

                p5.fill(255, 130, 183);
                p5.rect(p5.width / 2 - r2 / 2, p5.height / 2, r2, r2);
            }

            p5.resetWindowSize = function (w, h) {
                p5.resizeCanvas(w, h, true)
            }

        }, div);
    }

}