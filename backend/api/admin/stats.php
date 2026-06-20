<?php

header("Content-Type: application/json");

require_once "../config/db.php";

try {
    $pdo = DB::get();

    // TOTAL ROOMS
    $rooms = $pdo->query("SELECT COUNT(*) AS total FROM rooms")->fetch();

    // TOTAL BEDS
    $beds = $pdo->query("SELECT COUNT(*) AS total FROM bedspaces")->fetch();

    // OCCUPIED BEDS
    $occupied = $pdo->query("SELECT COUNT(*) AS total FROM bedspaces WHERE is_occupied = 1")->fetch();

    // AVAILABLE BEDS
    $available = $pdo->query("SELECT COUNT(*) AS total FROM bedspaces WHERE is_occupied = 0")->fetch();

    echo json_encode([
        "success" => true,
        "total_rooms" => $rooms["total"],
        "total_beds" => $beds["total"],
        "occupied_beds" => $occupied["total"],
        "available_beds" => $available["total"]
    ]);

} catch (Exception $e) {
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}