<?php
// api/login.php  –  Student login (validates against signup data)
// POST: email OR matric_number, password

declare(strict_types=1);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    session_start();
    if (empty($_SESSION['student_id'])) {
        jsonResponse(false, 'Not authenticated.', [], 401);
    }

    $pdo = DB::get();
    $stmt = $pdo->prepare(
        'SELECT student_id, full_name, email, matric_number, faculty, department, academic_level, gender, profile_picture
         FROM students
         WHERE student_id = :id
         LIMIT 1'
    );
    $stmt->execute([':id' => $_SESSION['student_id']]);
    $student = $stmt->fetch();

    if (!$student) {
        jsonResponse(false, 'User session invalid.', [], 401);
    }

    jsonResponse(true, 'Authenticated.', [
        'student_id'    => $student['student_id'],
        'full_name'     => $student['full_name'],
        'email'         => $student['email'],
        'matric'        => $student['matric_number'],
        'matric_number' => $student['matric_number'],
        'faculty'       => $student['faculty'],
        'department'    => $student['department'],
        'academic_level'=> $student['academic_level'],
        'gender'        => $student['gender'],
        'profile_picture'=> $student['profile_picture'],
    ]);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Method not allowed.', [], 405);
}

// ── 1. Accept either email or matric number + password ───────────────────
$identifier = trim($_POST['identifier'] ?? '');   // email OR matric_number
$password   = $_POST['password'] ?? '';

if ($identifier === '' || $password === '') {
    jsonResponse(false, 'Identifier (email / matric) and password are required.', [], 422);
}

// ── 2. Locate the student ────────────────────────────────────────────────
$pdo  = DB::get();
$stmt = $pdo->prepare(
    'SELECT student_id, full_name, email, matric_number, faculty, department, academic_level, gender, profile_picture, password_hash, is_active
     FROM   students
     WHERE  email = :id OR matric_number = :id2
     LIMIT  1'
);
$stmt->execute([':id' => strtolower($identifier), ':id2' => strtoupper($identifier)]);
$student = $stmt->fetch();

// ── 3. Verify password ───────────────────────────────────────────────────
if (!$student || !password_verify($password, $student['password_hash'])) {
    // Audit failed attempt (student_id may be unknown)
    auditLog($pdo, $student['student_id'] ?? null, 'LOGIN_FAIL', 'auth', null, [
        'identifier' => $identifier,
    ]);
    jsonResponse(false, 'Invalid credentials.', [], 401);
}

if (!$student['is_active']) {
    jsonResponse(false, 'Account is disabled. Contact admin.', [], 403);
}

// ── 4. Start session ─────────────────────────────────────────────────────
session_start();
$_SESSION['student_id']   = $student['student_id'];
$_SESSION['full_name']    = $student['full_name'];
$_SESSION['email']        = $student['email'];
$_SESSION['matric']       = $student['matric_number'];
$_SESSION['logged_in_at'] = date('Y-m-d H:i:s');

// Rehash if cost changed (future-proofing)
if (password_needs_rehash($student['password_hash'], PASSWORD_BCRYPT, ['cost' => 12])) {
    $new = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
    $pdo->prepare('UPDATE students SET password_hash = ? WHERE student_id = ?')
        ->execute([$new, $student['student_id']]);
}

auditLog($pdo, (int) $student['student_id'], 'LOGIN_SUCCESS', 'auth', (int) $student['student_id'], [
    'email' => $student['email'],
]);

jsonResponse(true, 'Login successful.', [
    'student_id'    => $student['student_id'],
    'full_name'     => $student['full_name'],
    'email'         => $student['email'],
    'matric'        => $student['matric_number'],
    'matric_number' => $student['matric_number'],
    'faculty'       => $student['faculty'],
    'department'    => $student['department'],
    'academic_level'=> $student['academic_level'],
    'gender'        => $student['gender'],
    'profile_picture'=> $student['profile_picture'],
]);