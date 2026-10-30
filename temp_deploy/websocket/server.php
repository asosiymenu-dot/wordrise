<?php

require dirname(__DIR__) . '/vendor/autoload.php';

use Ratchet\Server\IoServer;
use Ratchet\Http\HttpServer;
use Ratchet\WebSocket\WsServer;
use WordRise\WebSocket\RealTimeServer;
use React\EventLoop\Loop;
use React\Socket\SocketServer;

// Start ReactPHP event loop
$loop = Loop::get();

// The core logic handler
$realTimeServer = new RealTimeServer();

// 1. WebSocket Server (Port 8080) for external connections
$webSocketSocket = new SocketServer('0.0.0.0:8080', [], $loop);
$webSocketServer = new IoServer(
    new HttpServer(
        new WsServer(
            $realTimeServer
        )
    ),
    $webSocketSocket,
    $loop
);

// 2. Internal TCP Socket (Port 8081) for REST API to send broadcasts
$internalSocket = new SocketServer('127.0.0.1:8081', [], $loop);
$internalSocket->on('connection', function (\React\Socket\ConnectionInterface $conn) use ($realTimeServer) {
    $conn->on('data', function ($data) use ($realTimeServer) {
        $realTimeServer->handleInternalBroadcast($data);
    });
});

echo "WebSocket server started on port 8080...\n";
echo "Internal Broadcast listener started on 127.0.0.1:8081...\n";

$loop->run();
