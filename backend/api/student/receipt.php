<?php

session_start();
require_once "../config/db.php";
require_once __DIR__ . "/../libs/TCPDF-6.7.8/tcpdf.php";

$pdo = DB::get();

$reference = $_GET['reference'] ?? null;
$student_id = $_SESSION['student_id'] ?? null;

if (!$reference || !$student_id) {
    die("Invalid request");
}

/* ---------------- FETCH DATA ---------------- */
$stmt = $pdo->prepare("
    SELECT 
        s.fullname,
        s.matric_number,
        p.reference,
        p.amount,
        p.status,
        a.room_id,
        a.bed_id,
        a.created_at
    FROM payments p
    JOIN allocations a ON p.allocation_id = a.id
    JOIN students s ON a.student_id = s.id
    WHERE p.reference = ? AND a.student_id = ?
");

$stmt->execute([$reference, $student_id]);
$data = $stmt->fetch(PDO::FETCH_ASSOC);



if (!$data) {
    die("Receipt not found");
}

/* ---------------- VARIABLES ---------------- */
$fullname = $data['fullname'];
$matric_number = $data['matric_number'];
$amount = $data['amount'];
$status = strtoupper($data['status']);
$date = date("d M Y, h:i A", strtotime($data['created_at']));

$room = $data['room_id'];
$bed = $data['bed_id'];

/* ---------------- PDF INIT ---------------- */
$pdf = new TCPDF();

$pdf->SetCreator("HMS");
$pdf->SetAuthor("Hostel Management System");
$pdf->SetTitle("Payment Receipt");

$pdf->SetMargins(15, 15, 15);
$pdf->AddPage();

/* ---------------- HTML DESIGN ---------------- */
$html = "
<h2 style='text-align:center;'>HOSTEL MANAGEMENT SYSTEM</h2>
<h4 style='text-align:center;'>PAYMENT RECEIPT</h4>

<hr>

<table border='1' cellpadding='6'>

<tr>
<td><b>Full Name</b></td>
<td>$fullname</td>
</tr>

<tr>
<td><b>Matric Number</b></td>
<td>$matric_number</td>
</tr>

<tr>
<td><b>Reference</b></td>
<td>$reference</td>
</tr>

<tr>
<td><b>Amount</b></td>
<td>₦$amount</td>
</tr>

<tr>
<td><b>Room</b></td>
<td>$room</td>
</tr>

<tr>
<td><b>Bed</b></td>
<td>$bed</td>
</tr>

<tr>
<td><b>Status</b></td>
<td>$status</td>
</tr>

<tr>
<td><b>Date</b></td>
<td>$date</td>
</tr>

</table>

<br><br>

<center>
This receipt was generated automatically and is valid without signature.
</center>
";
/* ---------------- OUTPUT ---------------- */
$pdf->writeHTML($html, true, false, true, false, '');
$pdf->Output("receipt_$reference.pdf", "I");