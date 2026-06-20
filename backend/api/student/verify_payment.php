<?php
session_start();
header("Content-Type: application/json");
require_once "../config/db.php";

$pdo = DB::get();

$data = json_decode(file_get_contents("php://input"), true);

$reference = $data["reference"] ?? null;
$allocation_id = $data["allocation_id"] ?? null;

if (!$reference || !$allocation_id) {
    echo json_encode([
        "success" => false,
        "message" => "Missing reference or allocation_id"
    ]);
    exit;
}

// Paystack verify
$secretKey = "sk_test_2c821a32f556645dbfcdb1727bcaf3ffcad4e683";

$url = "https://api.paystack.co/transaction/verify/" . $reference;

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    "Authorization: Bearer $secretKey"
]);

$response = curl_exec($ch);
curl_close($ch);

$result = json_decode($response, true);

if (!$result || !$result["status"]) {
    echo json_encode([
        "success" => false,
        "message" => "Payment verification failed"
    ]);
    exit;
}

$payment = $result["data"];

if ($payment["status"] !== "success") {
    echo json_encode([
        "success" => false,
        "message" => "Payment not successful"
    ]);
    exit;
}

try {
    // 1. Update allocation
    $stmt = $pdo->prepare("
        UPDATE allocations 
        SET status = 'paid'
        WHERE id = ?
    ");
    $stmt->execute([$allocation_id]);

    // 2. INSERT payment record (🔥 THIS FIXES YOUR ISSUE)
    $stmt = $pdo->prepare("
        INSERT INTO payments (allocation_id, reference, amount, status, created_at)
        VALUES (?, ?, ?, 'success', NOW())
    ");

    $stmt->execute([
        $allocation_id,
        $reference,
        $payment["amount"] / 100
    ]);

    echo json_encode([
        "success" => true,
        "message" => "Payment verified"
    ]);

} catch (Exception $e) {
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}