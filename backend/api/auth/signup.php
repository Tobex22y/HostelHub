<?php
// api/signup.php  –  Student registration
// POST: full_name, email, phone, matric_number, gender, password, confirm_password

declare(strict_types=1);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Method not allowed.', [], 405);
}

// ── 1. Validate required fields ──────────────────────────────────────────
$missing = requireFields(['full_name','email','phone','matric_number','faculty','department','academic_level','gender','password','confirm_password']);
if ($missing) {
    jsonResponse(false, 'Missing required fields: ' . implode(', ', $missing), [], 422);
}

$fullName    = trim($_POST['full_name']);
$email       = strtolower(trim($_POST['email']));
$phone       = trim($_POST['phone']);
$matric      = strtoupper(trim($_POST['matric_number']));
$faculty     = trim($_POST['faculty']);
$department  = trim($_POST['department']);
$academicLevel = trim($_POST['academic_level']);
$gender      = strtolower(trim($_POST['gender']));
$password    = $_POST['password'];
$confirm     = $_POST['confirm_password'];

// Handle profile picture upload
$profilePicturePath = null;
$maxPictureSize = 2 * 1024 * 1024; // 2 MB

if (!isset($_FILES['profile_picture'])) {
    jsonResponse(false, 'Profile picture is required.', [], 422);
}

$fileError = $_FILES['profile_picture']['error'];
if ($fileError !== UPLOAD_ERR_OK) {
    switch ($fileError) {
        case UPLOAD_ERR_INI_SIZE:
        case UPLOAD_ERR_FORM_SIZE:
            jsonResponse(false, 'Profile picture is too large. Maximum size is 2MB.', [], 422);
        case UPLOAD_ERR_PARTIAL:
            jsonResponse(false, 'Profile picture upload was interrupted. Please try again.', [], 422);
        case UPLOAD_ERR_NO_FILE:
            jsonResponse(false, 'Profile picture is required.', [], 422);
        default:
            jsonResponse(false, 'Profile picture upload failed with error code ' . $fileError . '.', [], 422);
    }
}

if ($_FILES['profile_picture']['size'] > $maxPictureSize) {
    jsonResponse(false, 'Profile picture is too large. Maximum size is 2MB.', [], 422);
}

$uploadDir = __DIR__ . '/../uploads/profiles/';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

$fileName = uniqid() . '_' . basename($_FILES['profile_picture']['name']);
$targetPath = $uploadDir . $fileName;

// Validate file type
$allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
if (!in_array($_FILES['profile_picture']['type'], $allowedTypes, true)) {
    jsonResponse(false, 'Invalid file type. Only JPG, PNG, and GIF are allowed.', [], 422);
}

if (move_uploaded_file($_FILES['profile_picture']['tmp_name'], $targetPath)) {
    $profilePicturePath = 'uploads/profiles/' . $fileName;
} else {
    jsonResponse(false, 'Failed to upload profile picture.', [], 500);
}

// ── 2. Field-level validation ────────────────────────────────────────────
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    jsonResponse(false, 'Invalid email address.', [], 422);
}
if (!in_array($gender, ['male','female','other'], true)) {
    jsonResponse(false, 'Gender must be male, female, or other.', [], 422);
}
if (strlen($password) < 8) {
    jsonResponse(false, 'Password must be at least 8 characters.', [], 422);
}
if ($password !== $confirm) {
    jsonResponse(false, 'Passwords do not match.', [], 422);
}

// ── 3. Check uniqueness ──────────────────────────────────────────────────
$pdo = DB::get();

$dup = $pdo->prepare(
    'SELECT student_id FROM students WHERE email = :email OR matric_number = :matric LIMIT 1'
);
$dup->execute([':email' => $email, ':matric' => $matric]);

if ($dup->fetch()) {
    jsonResponse(false, 'Email or matric number already registered.', [], 409);
}

// ── 4. Insert student ────────────────────────────────────────────────────
$hash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);

$ins = $pdo->prepare(
    'INSERT INTO students (full_name, email, phone, matric_number, faculty, department, academic_level, gender, profile_picture, password_hash)
     VALUES (:name, :email, :phone, :matric, :faculty, :department, :level, :gender, :picture, :hash)'
);
$ins->execute([
    ':name'      => $fullName,
    ':email'     => $email,
    ':phone'     => $phone,
    ':matric'    => $matric,
    ':faculty'   => $faculty,
    ':department' => $department,
    ':level'     => $academicLevel,
    ':gender'    => $gender,
    ':picture'   => $profilePicturePath,
    ':hash'      => $hash,
]);

$newId = (int) $pdo->lastInsertId();

auditLog($pdo, $newId, 'SIGNUP', 'auth', $newId, [
    'email'  => $email,
    'matric' => $matric,
]);

jsonResponse(true, 'Registration successful. You can now log in.', [
    'student_id'    => $newId,
    'full_name'     => $fullName,
    'email'         => $email,
    'matric'        => $matric,
    'matric_number' => $matric,
    'faculty'       => $faculty,
    'department'    => $department,
    'academic_level'=> $academicLevel,
    'gender'        => $gender,
    'profile_picture'=> $profilePicturePath,
], 201);