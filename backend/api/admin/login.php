<?php

session_start();
header("Content-Type: application/json");

require_once "../config/db.php";

$data = json_decode(file_get_contents("php://input"), true);

$email = $data["email"] ?? "";
$password = $data["password"] ?? "";

if (!$email || !$password) {
    echo json_encode([
        "success" => false,
        "message" => "Email and password required"
    ]);
    exit;
}

try {
    $pdo = DB::get();

    $stmt = $pdo->prepare("SELECT * FROM admins WHERE email = ?");
    $stmt->execute([$email]);

    $admin = $stmt->fetch();

    if (!$admin) {
        echo json_encode([
            "success" => false,
            "message" => "Admin not found"
        ]);
        exit;
    }

    if (!password_verify($password, $admin["password"])) {
        echo json_encode([
            "success" => false,
            "message" => "Incorrect password"
        ]);
        exit;
    }

    $_SESSION["admin_id"] = $admin["id"];
    $_SESSION["admin_name"] = $admin["fullname"];

    echo json_encode([
        "success" => true,
        "message" => "Login successful",
        "admin" => [
            "id" => $admin["id"],
            "fullname" => $admin["fullname"],
            "email" => $admin["email"]
        ]
    ]);

} catch (Exception $e) {
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}