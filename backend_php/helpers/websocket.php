<?php

/**
 * Broadcasts an event to the internal WebSocket server on port 8081.
 * This is non-blocking because we just open the socket, write the JSON, and close it.
 *
 * @param string $event The name of the event (e.g. 'new_message', 'word_added')
 * @param array $data The payload for the event
 * @param int|null $targetUserId (Optional) If set, only this user receives it
 * @param int|null $excludeUserId (Optional) If set, this user will not receive it (e.g. the sender)
 */
function ws_broadcast(string $event, array $data, ?int $targetUserId = null, ?int $excludeUserId = null): void
{
    // Fail silently if socket server is not running
    $fp = @fsockopen("127.0.0.1", 8081, $errno, $errstr, 0.5);
    if (!$fp) {
        return; 
    }
    
    $payload = json_encode([
        'event' => $event,
        'data' => $data,
        'target_user_id' => $targetUserId,
        'exclude_user_id' => $excludeUserId,
    ]);

    fwrite($fp, $payload);
    fclose($fp);
}
