<?php
session_start();

header("Access-Control-Allow-Origin: http://localhost");
header("Access-Control-Allow-Credentials: true");
header("Content-Type: application/json");

require_once "../config/db.php";

$pdo = DB::get();
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

if (!isset($_SESSION["student_id"])) {
    echo json_encode([
        "success" => false,
        "message" => "Not logged in"
    ]);
    exit;
}

$student_id = $_SESSION["student_id"];

$data = json_decode(file_get_contents("php://input"), true);

$room_id = $data["room_id"] ?? null;
$bed_id  = $data["bed_id"] ?? null;

if (!$room_id || !$bed_id) {
    echo json_encode([
        "success" => false,
        "message" => "Missing room or bed"
    ]);
    exit;
}

try {

    // 🔒 1. prevent multiple reservations
    $check = $pdo->prepare("
        SELECT id FROM allocations
        WHERE student_id = ?
        AND status IN ('pending', 'active')
        LIMIT 1
    ");
    $check->execute([$student_id]);

    if ($check->fetch()) {
        echo json_encode([
            "success" => false,
            "message" => "You already have a reservation"
        ]);
        exit;
    }

    // 🔒 2. check bed
    $bedCheck = $pdo->prepare("SELECT * FROM bedspaces WHERE id = ?");
    $bedCheck->execute([$bed_id]);
    $bed = $bedCheck->fetch(PDO::FETCH_ASSOC);

    if (!$bed) {
        echo json_encode([
            "success" => false,
            "message" => "Bed not found"
        ]);
        exit;
    }

    if ((int)$bed["is_occupied"] === 1) {
        echo json_encode([
            "success" => false,
            "message" => "Bed already taken"
        ]);
        exit;
    }

    // 🔥 transaction
    $pdo->beginTransaction();

    // mark bed occupied
    $pdo->prepare("
        UPDATE bedspaces 
        SET is_occupied = 1 
        WHERE id = ?
    ")->execute([$bed_id]);

    // insert allocation
    $pdo->prepare("
        INSERT INTO allocations 
        (student_id, room_id, bed_id, status, created_at)
        VALUES (?, ?, ?, 'pending', NOW())
    ")->execute([$student_id, $room_id, $bed_id]);

    $allocation_id = $pdo->lastInsertId();

    $pdo->commit();

    echo json_encode([
        "success" => true,
        "message" => "Reservation successful",
        "allocation_id" => $allocation_id
    ]);

} catch (Exception $e) {

    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}