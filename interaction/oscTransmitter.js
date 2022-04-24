const osc = require("osc");

let OSCmsg;


let udpPort = new osc.UDPPort({
    // This is where sclang is listening for OSC messages.
    remoteAddress: "127.0.0.1",
    remotePort: 57120,
    metadata: true
});

// Open the socket.
udpPort.open();

exports.sendData = function sendData(data) {
    OSCmsg = {
        address: "/params",
        args: [
            {
                type: "f",
                value: data.centroid[0]
            },
            {
                type: "f",
                value: data.centroid[1]
            },
            {
                type: "f",
                value: data.palmMiddleFinger
            },
            {
                type: "f",
                value: data.palmMiddleSlope
            }
        ]
    };

    udpPort.send(OSCmsg);
    console.log("Sending: centroid(" + data.centroid + ")" + "\n" + 
                "palm-middleFinger (" + data.palmMiddleFinger + ")")

}