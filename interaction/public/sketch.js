export default class Sketch
{
    constructor(canvasWidth, canvasHeight, ballColor, div)
    {
        let x ;
        let y;

        this.myP5 = new p5(function(p5)
        {
            p5.setup = function() {
                p5.createCanvas(canvasWidth, canvasHeight);
                x = canvasWidth/2;
                y = canvasHeight/2;
                p5.background(ballColor);

            };

            p5.draw = function() {
                p5.fill(25, 255, ballColor, 25);
                p5.noStroke();
                p5.ellipse(x, y, 48, 48);

                x += p5.random(-10, 10);
                y += p5.random(-10, 10);

            }

            p5.resetWindowSize = function (w, h) {
                p5.resizeCanvas(w,h, true)
                p5.background(1);
                x = p5.width/2;
                y = p5.height/2;
            }

        }, div);   
    }

}