<?php

declare(strict_types=1);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';
require_once __DIR__ . '/../services/PaystackGateway.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: http://localhost');
header('Access-Control-Allow-Credentials: true');

// Paystack sends "reference" or "trxref" (both are the same value)
$reference = trim($_GET['reference'] ?? $_GET['trxref'] ?? '');

if (empty($reference)) {
    jsonResponse(false, 'No payment reference found in the callback URL.', [], 400);
}

$pdo = DB::get();

//Load the payment row
$stmt = $pdo->prepare(
    'SELECT p.payment_id,
            p.allocation_id,
            p.student_id,
            p.bed_id,
            p.amount,
            p.status       AS pay_status,
            p.paid_at,
            p.reference,
            a.status       AS alloc_status,
            a.academic_year,
            a.start_date,
            a.end_date,
            b.bed_label,
            b.bed_number,
            r.room_number,
            h.name         AS hostel_name
     FROM   payments    p
     JOIN   allocations a ON a.allocation_id = p.allocation_id
     JOIN   beds        b ON b.bed_id        = p.bed_id
     JOIN   rooms       r ON r.room_id       = b.room_id
     JOIN   hostels     h ON h.hostel_id     = r.hostel_id
     WHERE  p.reference = :ref
     LIMIT  1'
);
$stmt->execute([':ref' => $reference]);
$row = $stmt->fetch();

if (!$row) {
    jsonResponse(false, 'Payment reference not found.', ['reference' => $reference], 404);
}

//If webhook already processed it, return current state 
if ($row['pay_status'] === 'success') {
    jsonResponse(true, 'Payment confirmed. Your room has been allocated.', [
        'reference'     => $reference,
        'allocation_id' => $row['allocation_id'],
        'hostel'        => $row['hostel_name'],
        'room'          => $row['room_number'],
        'bed'           => $row['bed_label'],
        'amount'        => $row['amount'],
        'paid_at'       => $row['paid_at'],
        'academic_year' => $row['academic_year'],
    ]);
}

if ($row['pay_status'] === 'failed') {
    jsonResponse(false, 'Your payment was not successful. The bed reservation has been released.', [
        'reference'     => $reference,
        'alloc_status'  => $row['alloc_status'],
    ], 402);
}

//Still pending — verify with Paystack now
$gateway  = new PaystackGateway();
$verified = $gateway->verify($reference);

$pdo->beginTransaction();
try {

    if ($verified['success']) {

        //Confirm allocation
        $pdo->prepare(
            'UPDATE allocations
             SET    status = "confirmed", updated_at = NOW()
             WHERE  allocation_id = :aid
               AND  status = "pending"'
        )->execute([':aid' => $row['allocation_id']]);

        //Confirm payment
        $pdo->prepare(
            'UPDATE payments
             SET    status         = "success",
                    paid_at        = NOW(),
                    gateway_ref    = :gref,
                    transaction_id = :tid,
                    notes          = :notes
             WHERE  payment_id = :pid
               AND  status     = "pending"'
        )->execute([
            ':gref'  => (string)($verified['gateway_ref'] ?? ''),
            ':tid'   => (string)($verified['gateway_ref'] ?? ''),
            ':notes' => 'Confirmed via callback. Channel: ' . ($verified['channel'] ?? 'unknown'),
            ':pid'   => $row['payment_id'],
        ]);

        //Mark bed occupied
        $pdo->prepare(
            'UPDATE beds
             SET    status        = "occupied",
                    student_id    = :sid,
                    allocated_at  = NOW(),
                    academic_year = :year
             WHERE  bed_id = :bid
               AND  status  IN ("reserved", "available")'
        )->execute([
            ':sid'  => $row['student_id'],
            ':year' => $row['academic_year'],
            ':bid'  => $row['bed_id'],
        ]);

        // Update room availability
        $pdo->prepare(
            'UPDATE rooms r
             SET    r.is_available = (
                 SELECT IF(COUNT(*) > 0, 1, 0)
                 FROM   beds b
                 WHERE  b.room_id = r.room_id AND b.status = "available"
             )
             WHERE  r.room_id = (SELECT room_id FROM beds WHERE bed_id = :bid)'
        )->execute([':bid' => $row['bed_id']]);

        auditLog($pdo, (int)$row['student_id'], 'CALLBACK_PAYMENT_SUCCESS', 'payment',
            (int)$row['payment_id'], [
                'reference'   => $reference,
                'gateway_ref' => $verified['gateway_ref'] ?? '',
            ]
        );

        $pdo->commit();

        jsonResponse(true, 'Payment verified and room allocation confirmed.', [
            'reference'     => $reference,
            'allocation_id' => $row['allocation_id'],
            'hostel'        => $row['hostel_name'],
            'room'          => $row['room_number'],
            'bed'           => $row['bed_label'],
            'amount'        => $verified['amount'],
            'paid_at'       => $verified['paid_at'],
            'academic_year' => $row['academic_year'],
        ]);

    } else {

        //Payment not successful → cancel and release
        $pdo->prepare(
            'UPDATE allocations SET status = "cancelled", updated_at = NOW()
             WHERE  allocation_id = :aid AND status = "pending"'
        )->execute([':aid' => $row['allocation_id']]);

        $pdo->prepare(
            'UPDATE payments SET status = "failed",
                    notes = :notes
             WHERE  payment_id = :pid AND status = "pending"'
        )->execute([
            ':notes' => 'Payment not successful on callback check. Status: ' . ($verified['status'] ?? 'unknown'),
            ':pid'   => $row['payment_id'],
        ]);

        $pdo->prepare(
            'UPDATE beds
             SET    status = "available", student_id = NULL, allocated_at = NULL
             WHERE  bed_id = :bid'
        )->execute([':bid' => $row['bed_id']]);

        $pdo->prepare(
            'UPDATE rooms SET is_available = 1
             WHERE  room_id = (SELECT room_id FROM beds WHERE bed_id = :bid)'
        )->execute([':bid' => $row['bed_id']]);

        auditLog($pdo, (int)$row['student_id'], 'CALLBACK_PAYMENT_FAILED', 'payment',
            (int)$row['payment_id'], [
                'reference' => $reference,
                'status'    => $verified['status'],
            ]
        );

        $pdo->commit();

        jsonResponse(false, 'Payment was not successful. The bed reservation has been released.', [
            'reference'    => $reference,
            'pay_status'   => $verified['status'],
            'alloc_status' => 'cancelled',
        ], 402);
    }

} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log('[HMS Callback] ' . $e->getMessage());
    jsonResponse(false, 'An internal error occurred. Please contact support.', [], 500);
}
