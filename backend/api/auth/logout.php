<?php
// api/logout.php  –  Destroy the student session
// POST (no fields required)

declare(strict_types=1);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

header('Content-Type: application/json; charset=utf-8');

session_start();
$studentId = $_SESSION['student_id'] ?? null;

$pdo = DB::get();
if ($studentId) {
    auditLog($pdo, (int) $studentId, 'LOGOUT', 'auth', (int) $studentId);
}

session_unset();
session_destroy();

jsonResponse(true, 'Logged out successfully.');