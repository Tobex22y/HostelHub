<?php

session_start();
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

require_once "../config/db.php";

$room_id = $_GET["room_id"] ?? null;

if (!$room_id) {
    echo json_encode([
        "success" => false,
        "message" => "room_id is required"
    ]);
    exit;
}

try {
    $pdo = DB::get();

    // get room info
    $roomStmt = $pdo->prepare("SELECT * FROM rooms WHERE id = ?");
    $roomStmt->execute([$room_id]);
    $room = $roomStmt->fetch();

    if (!$room) {
        echo json_encode([
            "success" => false,
            "message" => "Room not found"
        ]);
        exit;
    }

    // get all beds in room
    $stmt = $pdo->prepare("
        SELECT id, bed_number, is_occupied
        FROM bedspaces
        WHERE room_id = ?
        ORDER BY bed_number ASC
    ");

    $stmt->execute([$room_id]);
    $beds = $stmt->fetchAll();

    echo json_encode([
        "success" => true,
        "room" => $room,
        "beds" => $beds
    ]);

} catch (Exception $e) {
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}