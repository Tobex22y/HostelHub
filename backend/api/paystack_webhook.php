<?php

declare(strict_types=1);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';
require_once __DIR__ . '/../services/PaystackGateway.php';

// Only POST allowed
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit('Method Not Allowed');
}

// ── 1. Read raw body and Paystack signature header
$rawBody   = (string) file_get_contents('php://input');
$signature = $_SERVER['HTTP_X_PAYSTACK_SIGNATURE'] ?? '';

//Verify HMAC-SHA512 signature
$gateway = new PaystackGateway();

if (!$gateway->verifyWebhookSignature($rawBody, $signature)) {
    http_response_code(401);
    error_log('[HMS Webhook] Invalid Paystack signature from IP: ' . clientIp());
    exit('Unauthorized');
}

//Parse event
$event = json_decode($rawBody, true);

if (!is_array($event) || empty($event['event']) || empty($event['data'])) {
    http_response_code(400);
    exit('Bad payload');
}

$eventType = $event['event'];          // e.g. charge.success
$data      = $event['data'];
$reference = $data['reference'] ?? '';

// We only handle charge events
if (!in_array($eventType, ['charge.success', 'charge.failed', 'transfer.failed'], true)) {
    http_response_code(200);
    exit('Event not handled');
}

if (empty($reference)) {
    http_response_code(200);
    exit('No reference');
}

// ── 4. Always verify server-side — never trust webhook data alone
$verified = $gateway->verify($reference);

// Look up the payment row
$pdo = DB::get();

$payStmt = $pdo->prepare(
    'SELECT payment_id, allocation_id, student_id, bed_id, amount, status
     FROM   payments
     WHERE  reference = :ref
     LIMIT  1'
);
$payStmt->execute([':ref' => $reference]);
$payment = $payStmt->fetch();

if (!$payment) {
    error_log("[HMS Webhook] Unknown reference: {$reference}");
    http_response_code(200);
    exit('Reference not found');
}

// IDEMPOTENCY: already processed → do nothing 
if (in_array($payment['status'], ['success', 'failed', 'refunded'], true)) {
    http_response_code(200);
    exit('Already processed');
}

$allocationId = (int) $payment['allocation_id'];
$studentId    = (int) $payment['student_id'];
$paymentId    = (int) $payment['payment_id'];
$bedId        = (int) $payment['bed_id'];

//Finalise atomically
$pdo->beginTransaction();

try {

    if ($verified['success'] && $eventType === 'charge.success') {

        // 6a. Confirm the allocation
        $pdo->prepare(
            'UPDATE allocations
             SET    status     = "confirmed",
                    updated_at = NOW()
             WHERE  allocation_id = :aid'
        )->execute([':aid' => $allocationId]);

        // 6b. Mark payment as success
        $pdo->prepare(
            'UPDATE payments
             SET    status         = "success",
                    paid_at        = NOW(),
                    gateway_ref    = :gref,
                    transaction_id = :tid,
                    notes          = :notes
             WHERE  payment_id = :pid'
        )->execute([
            ':gref'  => (string) ($verified['gateway_ref'] ?? ''),
            ':tid'   => (string) ($verified['gateway_ref'] ?? ''),
            ':notes' => 'Verified via Paystack. Channel: ' . ($verified['channel'] ?? 'unknown'),
            ':pid'   => $paymentId,
        ]);

        // 6c. Mark the specific bed as OCCUPIED
        $pdo->prepare(
            'UPDATE beds
             SET    status        = "occupied",
                    student_id    = :sid,
                    allocated_at  = NOW(),
                    academic_year = (
                        SELECT academic_year
                        FROM   allocations
                        WHERE  allocation_id = :aid
                    )
             WHERE  bed_id = :bid'
        )->execute([
            ':sid' => $studentId,
            ':aid' => $allocationId,
            ':bid' => $bedId,
        ]);

        // 6d. Update room availability:
        //     is_available = 1 if at least one bed is still free, else 0
        $pdo->prepare(
            'UPDATE rooms r
             SET    r.is_available = (
                 SELECT IF(COUNT(*) > 0, 1, 0)
                 FROM   beds b
                 WHERE  b.room_id = r.room_id
                   AND  b.status  = "available"
             )
             WHERE  r.room_id = (
                 SELECT room_id FROM beds WHERE bed_id = :bid
             )'
        )->execute([':bid' => $bedId]);

        auditLog($pdo, $studentId, 'WEBHOOK_PAYMENT_SUCCESS', 'payment', $paymentId, [
            'bed_id'      => $bedId,
            'gateway_ref' => $verified['gateway_ref'] ?? '',
            'amount_ngn'  => $verified['amount'],
            'channel'     => $verified['channel'],
        ]);

    } else {

        
        //Cancel the allocation
        $pdo->prepare(
            'UPDATE allocations
             SET    status     = "cancelled",
                    updated_at = NOW()
             WHERE  allocation_id = :aid'
        )->execute([':aid' => $allocationId]);

        //Mark payment as failed
        $pdo->prepare(
            'UPDATE payments
             SET    status = "failed",
                    notes  = :notes
             WHERE  payment_id = :pid'
        )->execute([
            ':notes' => 'Payment failed/abandoned. Paystack status: ' . ($verified['status'] ?? 'unknown'),
            ':pid'   => $paymentId,
        ]);

        //Release the bed back to AVAILABLE
        $pdo->prepare(
            'UPDATE beds
             SET    status        = "available",
                    student_id    = NULL,
                    allocated_at  = NULL,
                    academic_year = NULL
             WHERE  bed_id = :bid'
        )->execute([':bid' => $bedId]);

        //Ensure the room is marked as available again
        $pdo->prepare(
            'UPDATE rooms SET is_available = 1
             WHERE  room_id = (SELECT room_id FROM beds WHERE bed_id = :bid)'
        )->execute([':bid' => $bedId]);

        auditLog($pdo, $studentId, 'WEBHOOK_PAYMENT_FAILED', 'payment', $paymentId, [
            'bed_id'  => $bedId,
            'event'   => $eventType,
            'status'  => $verified['status'] ?? 'unknown',
            'message' => $verified['message'],
        ]);
    }

    $pdo->commit();
    http_response_code(200);
    exit('OK');

} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('[HMS Webhook] DB error: ' . $e->getMessage());
    http_response_code(500);
    exit('Internal error');
}