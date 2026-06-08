<?php

declare(strict_types=1);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: http://localhost');
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

session_start();

if (empty($_SESSION['student_id'])) {
    jsonResponse(false, 'Authentication required.', [], 401);
}

$studentId = (int) ($_GET['student_id'] ?? $_SESSION['student_id']);

// Prevent viewing another student's history
if ($studentId !== (int) $_SESSION['student_id']) {
    jsonResponse(false, 'Access denied.', [], 403);
}

$pdo = DB::get();

// Full transaction history with room/hostel/bed details
$stmt = $pdo->prepare(
    'SELECT
         p.payment_id,
         p.allocation_id,
         p.amount,
         p.payment_method,
         p.reference,
         p.gateway_ref,
         p.transaction_id,
         p.status          AS payment_status,
         p.paid_at,
         p.created_at,
         p.notes,
         a.academic_year,
         a.start_date,
         a.end_date,
         a.status          AS allocation_status,
         b.bed_label,
         b.bed_number,
         r.room_number,
         h.name            AS hostel_name,
         h.gender_type
     FROM   payments    p
     JOIN   allocations a ON a.allocation_id = p.allocation_id
     JOIN   beds        b ON b.bed_id        = p.bed_id
     JOIN   rooms       r ON r.room_id       = b.room_id
     JOIN   hostels     h ON h.hostel_id     = r.hostel_id
     WHERE  p.student_id = :sid
     ORDER  BY p.created_at DESC'
);
$stmt->execute([':sid' => $studentId]);
$payments = $stmt->fetchAll();

// Summary stats
$totalPaid    = 0.0;
$totalPending = 0.0;
$confirmedAlloc = null;

foreach ($payments as $p) {
    if ($p['payment_status'] === 'success')  $totalPaid    += (float)$p['amount'];
    if ($p['payment_status'] === 'pending')  $totalPending += (float)$p['amount'];
    if ($p['allocation_status'] === 'confirmed' && !$confirmedAlloc) {
        $confirmedAlloc = [
            'hostel'        => $p['hostel_name'],
            'room'          => $p['room_number'],
            'bed'           => $p['bed_label'],
            'academic_year' => $p['academic_year'],
        ];
    }
}

jsonResponse(true, 'Payment history retrieved successfully.', [
    'student_id'        => $studentId,
    'count'             => count($payments),
    'total_paid'        => $totalPaid,
    'total_pending'     => $totalPending,
    'confirmed_allocation' => $confirmedAlloc,
    'payments'          => $payments,
]);
