<?php

session_set_cookie_params([
    "lifetime" => 0,
    "path" => "/",
    "domain" => "localhost",
    "httponly" => true,
    "samesite" => "Lax"
]);

session_start();

header("Access-Control-Allow-Origin: http://localhost");
header("Access-Control-Allow-Credentials: true");
header("Content-Type: application/json");

require_once "../config/db.php";

// check login
if (!isset($_SESSION["student_id"])) {
    echo json_encode([
        "success" => false,
        "message" => "Not logged in"
    ]);
    exit;
}

$student_id = $_SESSION["student_id"];

try {
    $pdo = DB::get();

    // student info
    $stmt = $pdo->prepare("
        SELECT id, fullname, email, matric_number, profile_image 
        FROM students 
        WHERE id = ?
    ");
    $stmt->execute([$student_id]);
    $student = $stmt->fetch();

    // allocation
    $roomStmt = $pdo->prepare("
        SELECT * FROM allocations WHERE student_id = ?
    ");
    $roomStmt->execute([$student_id]);
    $allocation = $roomStmt->fetch();

    // payment (latest)
    $payStmt = $pdo->prepare("
        SELECT * FROM payments 
        WHERE student_id = ? 
        ORDER BY id DESC 
        LIMIT 1
    ");
    $payStmt->execute([$student_id]);
    $payment = $payStmt->fetch();

    echo json_encode([
        "success" => true,
        "student" => $student,
        "allocation" => $allocation,
        "payment" => $payment
    ]);

} catch (Exception $e) {
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}