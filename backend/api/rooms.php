<?php
// api/rooms.php  –  List available rooms (optionally filter by gender / hostel)
// GET: ?gender=male|female|mixed  &hostel_id=X

declare(strict_types=1);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/helpers.php';

header('Content-Type: application/json; charset=utf-8');

$pdo = DB::get();

$conditions = ['r.is_available = 1', '(SELECT COUNT(*) FROM bedspaces b WHERE b.room_id = r.room_id AND b.is_occupied = 0) > 0'];
$params     = [];

if (!empty($_GET['gender'])) {
    $conditions[] = 'h.gender_type IN (:g, "mixed")';
    $params[':g'] = strtolower(trim($_GET['gender']));
}
if (!empty($_GET['hostel_id'])) {
    $conditions[] = 'h.hostel_id = :hid';
    $params[':hid'] = (int) $_GET['hostel_id'];
}

$where = implode(' AND ', $conditions);

$stmt = $pdo->prepare(
    "SELECT
         r.room_id,
         r.room_number,
         r.room_type,
         r.capacity,
         r.occupied_beds,
         COALESCE((SELECT COUNT(*) FROM bedspaces b WHERE b.room_id = r.room_id AND b.is_occupied = 0), 0) AS available_bedspaces,
         r.price_per_bed,
         h.hostel_id,
         h.name   AS hostel_name,
         h.gender_type,
         h.address
     FROM  rooms   r
     JOIN  hostels h ON h.hostel_id = r.hostel_id
     WHERE {$where}
     ORDER BY h.name, r.room_number"
);
$stmt->execute($params);
$rooms = $stmt->fetchAll();

jsonResponse(true, 'Available rooms retrieved.', [
    'count' => count($rooms),
    'rooms' => $rooms,
]);