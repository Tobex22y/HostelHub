<?php

declare(strict_types=1);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';
require_once __DIR__ . '/../services/PaystackGateway.php';

// CORS headers
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: http://localhost');
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, 'Method not allowed.', [], 405);
}

// Session guard
session_start();
if (empty($_SESSION['student_id'])) {
    jsonResponse(false, 'Authentication required. Please log in.', [], 401);
}

// Validate input 
$missing = requireFields([
    'student_id', 'bed_id', 'academic_year',
    'start_date', 'end_date', 'payment_method', 'callback_url',
]);
if ($missing) {
    jsonResponse(false, 'Missing required fields: ' . implode(', ', $missing), [], 422);
}

$studentId    = (int)  $_POST['student_id'];
$bedId        = (int)  $_POST['bed_id'];
$academicYear = trim(  $_POST['academic_year']);
$startDate    = trim(  $_POST['start_date']);
$endDate      = trim(  $_POST['end_date']);
$payMethod    = trim(  $_POST['payment_method']);
$callbackUrl  = trim(  $_POST['callback_url']);

// Session must match the student making the request
if ((int) $_SESSION['student_id'] !== $studentId) {
    jsonResponse(false, 'Session mismatch. Please log in again.', [], 403);
}

// Map frontend method names to Paystack channel names
$channelMap = [
    'card'           => ['card'],
    'bank'           => ['bank'],
    'ussd'           => ['ussd'],
    'bank_transfer'  => ['bank_transfer'],
    'mobile_money'   => ['mobile_money'],
];
$channels = $channelMap[$payMethod] ?? ['card', 'bank', 'ussd'];

//Open DB transaction
$pdo = DB::get();
$pdo->beginTransaction();

try {
    $bedStmt = $pdo->prepare(
        'SELECT b.bed_id,
                b.bed_number,
                b.bed_label,
                b.price,
                b.status       AS bed_status,
                b.room_id,
                b.hostel_id,
                r.room_number,
                h.name         AS hostel_name,
                h.gender_type
         FROM   beds    b
         JOIN   rooms   r ON r.room_id   = b.room_id
         JOIN   hostels h ON h.hostel_id = b.hostel_id
         WHERE  b.bed_id = :bid
         FOR UPDATE'               
    );
    $bedStmt->execute([':bid' => $bedId]);
    $bed = $bedStmt->fetch();

    if (!$bed) {
        throw new RuntimeException('Bed not found.', 404);
    }

    // NO BED SPACE = NO PAYMENT
    if ($bed['bed_status'] !== 'available') {
        $reason = match ($bed['bed_status']) {
            'occupied'    => 'This bed is already occupied by another student.',
            'reserved'    => 'This bed is temporarily reserved. Please try a different bed.',
            'maintenance' => 'This bed is currently under maintenance.',
            default       => 'This bed is not available for allocation.',
        };
        // ROLLBACK is automatic via the exception handler
        throw new RuntimeException($reason, 409);
    }

  
    $stuStmt = $pdo->prepare(
        'SELECT student_id, full_name, email, phone, gender
         FROM   students
         WHERE  student_id = :sid AND is_active = 1
         FOR UPDATE'
    );
    $stuStmt->execute([':sid' => $studentId]);
    $student = $stuStmt->fetch();

    if (!$student) {
        throw new RuntimeException('Student account not found or has been deactivated.', 404);
    }

    //  GATE 3: NO DUPLICATE ALLOCATION FOR THE SAME YEAR
    
    $dupStmt = $pdo->prepare(
        'SELECT allocation_id
         FROM   allocations
         WHERE  student_id    = :sid
           AND  academic_year = :year
           AND  status        IN ("pending", "confirmed")
         LIMIT  1'
    );
    $dupStmt->execute([':sid' => $studentId, ':year' => $academicYear]);
    if ($dupStmt->fetch()) {
        throw new RuntimeException(
            "You already have an active allocation for the {$academicYear} academic year.", 409
        );
    }

    $pdo->prepare(
        'UPDATE beds SET status = "reserved" WHERE bed_id = :bid'
    )->execute([':bid' => $bedId]);

    $pdo->prepare(
        'INSERT INTO allocations
             (student_id, room_id, bed_id, academic_year, start_date, end_date, status)
         VALUES
             (:sid, :rid, :bid, :year, :start, :end, "pending")'
    )->execute([
        ':sid'   => $studentId,
        ':rid'   => $bed['room_id'],
        ':bid'   => $bedId,
        ':year'  => $academicYear,
        ':start' => $startDate,
        ':end'   => $endDate,
    ]);
    $allocationId = (int) $pdo->lastInsertId();

   
    $amount    = (float) $bed['price'];
    $reference = generateReference('HMS');

    $pdo->prepare(
        'INSERT INTO payments
             (allocation_id, student_id, bed_id, amount, payment_method,
              reference, status, notes)
         VALUES
             (:aid, :sid, :bid, :amt, :mth,
              :ref, "pending", "Awaiting Paystack confirmation")'
    )->execute([
        ':aid' => $allocationId,
        ':sid' => $studentId,
        ':bid' => $bedId,
        ':amt' => $amount,
        ':mth' => $payMethod,
        ':ref' => $reference,
    ]);
    $paymentId = (int) $pdo->lastInsertId();

    
    $gateway    = new PaystackGateway();
    $paystackResult = $gateway->initialize([
        'email'        => $student['email'],
        'amount'       => $amount,
        'reference'    => $reference,
        'callback_url' => $callbackUrl,
        'channels'     => $channels,
        'student_id'   => $studentId,
        'allocation_id'=> $allocationId,
        'bed_id'       => $bedId,
        'bed_label'    => $bed['bed_label'],
        'cancel_url'   => str_replace('payment-callback', 'dashboard', $callbackUrl),
        'metadata'     => [
            'custom_fields' => [
                ['display_name' => 'Student Name', 'variable_name' => 'student_name',  'value' => $student['full_name']],
                ['display_name' => 'Bed Space',    'variable_name' => 'bed_label',     'value' => $bed['bed_label']],
                ['display_name' => 'Academic Year','variable_name' => 'academic_year', 'value' => $academicYear],
            ],
        ],
    ]);

    // ATOMIC RULE 2: PAYSTACK REJECTED → ROLLBACK
    if (!$paystackResult['success']) {
        auditLog($pdo, $studentId, 'ALLOCATE_PAYSTACK_INIT_FAIL', 'allocation', $allocationId, [
            'bed_id'    => $bedId,
            'bed_label' => $bed['bed_label'],
            'reason'    => $paystackResult['message'],
        ]);
        $pdo->rollBack();   // ← bed goes back to available, allocation row gone
        jsonResponse(false,
            'Could not create payment session: ' . $paystackResult['message'],
            ['reference' => $reference], 502
        );
    }

   
    auditLog($pdo, $studentId, 'ALLOCATE_INITIATED', 'allocation', $allocationId, [
        'bed_id'            => $bedId,
        'bed_label'         => $bed['bed_label'],
        'payment_id'        => $paymentId,
        'reference'         => $reference,
        'authorization_url' => $paystackResult['authorization_url'],
    ]);

    $pdo->commit();

    //Return authorization_url to frontend
    jsonResponse(true, 'Allocation initiated. Redirect student to complete payment.', [
        'allocation_id'     => $allocationId,
        'payment_id'        => $paymentId,
        'reference'         => $reference,
        'amount'            => $amount,
        'authorization_url' => $paystackResult['authorization_url'], // ← send student here
        'access_code'       => $paystackResult['access_code'],
        'bed'               => [
            'bed_id'     => $bedId,
            'bed_label'  => $bed['bed_label'],
            'bed_number' => $bed['bed_number'],
            'room'       => $bed['room_number'],
            'hostel'     => $bed['hostel_name'],
        ],
        'note' => 'Bed is reserved for 15 minutes. Allocation is confirmed only after successful payment.',
    ], 200);

} catch (RuntimeException $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();   // ← bed released, allocation/payment rows wiped
    }
    $code = (int)($e->getCode() ?: 400);
    jsonResponse(false, $e->getMessage(), [], $code);

} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('[HMS allocate.php] ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    jsonResponse(false, 'An internal server error occurred. Please try again.', [], 500);
}
