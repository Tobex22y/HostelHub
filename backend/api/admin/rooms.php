<?php

header("Content-Type: application/json");

require_once "../config/db.php";

$data = json_decode(file_get_contents("php://input"), true);

$room_number = $data["room_number"] ?? "";
$room_type = $data["room_type"] ?? "";
$capacity = $data["capacity"] ?? 0;
$price = $data["price"] ?? 0;

if (!$room_number || !$capacity) {
    echo json_encode([
        "success" => false,
        "message" => "Missing fields"
    ]);
    exit;
}

try {
    $pdo = DB::get();

    // 1. insert room
    $stmt = $pdo->prepare("
        INSERT INTO rooms (room_number, room_type, capacity, occupied, status)
        VALUES (?, ?, ?, 0, 'available')
    ");
    $stmt->execute([$room_number, $room_type, $capacity]);

    // 2. get room id
    $room_id = $pdo->lastInsertId();

    // 3. CREATE BEDSPACES AUTOMATICALLY (THIS WAS MISSING)
    $bedStmt = $pdo->prepare("
        INSERT INTO bedspaces (room_id, bed_number, is_occupied)
        VALUES (?, ?, 0)
    ");

    for ($i = 1; $i <= $capacity; $i++) {
        $bedStmt->execute([$room_id, $i]);
    }

    echo json_encode([
        "success" => true,
        "message" => "Room and bedspaces created successfully",
        "room_id" => $room_id
    ]);

} catch (Exception $e) {
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}