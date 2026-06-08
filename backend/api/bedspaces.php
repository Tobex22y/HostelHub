<?php
// api/bedspaces.php  –  List available bedspaces for a specific room
// GET: ?room_id=123

declare(strict_types=1);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    jsonResponse(false, 'Method not allowed.', [], 405);
}

$roomId = isset($_GET['room_id']) ? (int) $_GET['room_id'] : 0;
if ($roomId <= 0) {
    jsonResponse(false, 'room_id is required.', [], 422);
}

$pdo = DB::get();
$stmt = $pdo->prepare(
    'SELECT b.bedspace_id, b.bed_number, b.is_occupied, r.room_id, r.room_number,
            h.hostel_id, h.name AS hostel_name
     FROM bedspaces b
     JOIN rooms   r ON r.room_id = b.room_id
     JOIN hostels h ON h.hostel_id = r.hostel_id
     WHERE b.room_id = :rid
       AND b.is_occupied = 0
     ORDER BY b.bed_number'
);
$stmt->execute([':rid' => $roomId]);
$bedspaces = $stmt->fetchAll();

jsonResponse(true, 'Available bedspaces retrieved.', [
    'room_id'     => $roomId,
    'room_number' => $bedspaces[0]['room_number'] ?? null,
    'hostel_id'   => $bedspaces[0]['hostel_id'] ?? null,
    'hostel_name' => $bedspaces[0]['hostel_name'] ?? null,
    'bedspaces'   => $bedspaces,
]);
