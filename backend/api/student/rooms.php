<?php

session_start();
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

require_once "../config/db.php";

try {
    $pdo = DB::get();

    // Get all rooms
    $stmt = $pdo->query("SELECT * FROM rooms");
    $rooms = $stmt->fetchAll();

    $result = [];

    foreach ($rooms as $room) {

        $room_id = $room["id"];

        // total beds in room
        $totalBedsStmt = $pdo->prepare("
            SELECT COUNT(*) AS total 
            FROM bedspaces 
            WHERE room_id = ?
        ");
        $totalBedsStmt->execute([$room_id]);
        $totalBeds = $totalBedsStmt->fetch()["total"];

        // occupied beds
        $occupiedStmt = $pdo->prepare("
            SELECT COUNT(*) AS total 
            FROM bedspaces 
            WHERE room_id = ? AND is_occupied = 1
        ");
        $occupiedStmt->execute([$room_id]);
        $occupied = $occupiedStmt->fetch()["total"];

        $available = $totalBeds - $occupied;

        $result[] = [
            "id" => $room["id"],
            "room_number" => $room["room_number"],
            "room_type" => $room["room_type"],
            "capacity" => $room["capacity"],
            "occupied" => $occupied,
            "available" => $available,
            "status" => $room["status"]
        ];
    }

    echo json_encode([
        "success" => true,
        "rooms" => $result
    ]);

} catch (Exception $e) {
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}