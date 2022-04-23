const express = require('express');
const socket = require('socket.io');
const oscTransmitter = require('./oscTransmitter.js')

//Server app creation
let app = express();
let server = app.listen(55123) 

//Set web browser client files
app.use(express.static('public'));

//Socket creation
let io = socket(server);

io.sockets.on('connection', newConnection);

//On new connection fucntion
function newConnection(socket) {
    console.log("new connection: " + socket.id);

    socket.on('centroidAndPalmMiddleFinger', dataReceived)

    function dataReceived(data) {
        //console.log(data);
        oscTransmitter.sendData(data);
    }
}



