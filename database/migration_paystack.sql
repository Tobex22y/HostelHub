USE hostel_management;

-- Add gateway_ref column (Paystack's internal transaction ID)
ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS gateway_ref    VARCHAR(100) NULL AFTER reference,
    ADD COLUMN IF NOT EXISTS transaction_id VARCHAR(100) NULL AFTER gateway_ref;


DESCRIBE payments;

SELECT
    h.name                          AS hostel,
    r.room_number,
    b.bed_number,
    b.bed_label,
    b.status                        AS bed_status,
    b.price,
    s.full_name                     AS occupied_by,
    b.academic_year
FROM   beds    b
JOIN   rooms   r ON r.room_id   = b.room_id
JOIN   hostels h ON h.hostel_id = b.hostel_id
LEFT   JOIN students s ON s.student_id = b.student_id
ORDER  BY h.name, r.room_number, b.bed_number;


SELECT
    a.allocation_id,
    s.full_name,
    s.matric_number,
    h.name         AS hostel,
    r.room_number,
    b.bed_label,
    a.status       AS allocation_status,
    p.status       AS payment_status,
    p.reference,
    p.created_at
FROM   allocations a
JOIN   students    s ON s.student_id   = a.student_id
JOIN   beds        b ON b.bed_id       = a.bed_id
JOIN   rooms       r ON r.room_id      = b.room_id
JOIN   hostels     h ON h.hostel_id    = r.hostel_id
JOIN   payments    p ON p.allocation_id = a.allocation_id
WHERE  a.status = 'pending'
ORDER  BY a.allocated_at DESC;


SELECT
    a.allocation_id,
    a.status        AS alloc_status,
    p.status        AS pay_status,
    b.status        AS bed_status,
    'INTEGRITY VIOLATION' AS issue
FROM   allocations a
JOIN   payments    p ON p.allocation_id = a.allocation_id
JOIN   beds        b ON b.bed_id        = a.bed_id
WHERE  (a.status = 'confirmed' AND p.status != 'success')
    OR (a.status = 'confirmed' AND b.status != 'occupied')
    OR (a.status = 'cancelled' AND b.status = 'occupied' AND b.student_id = a.student_id);

SELECT
    h.name                                          AS hall,
    COUNT(b.bed_id)                                 AS total_beds,
    SUM(b.status = 'available')                     AS available,
    SUM(b.status = 'occupied')                      AS occupied,
    SUM(b.status = 'reserved')                      AS reserved,
    SUM(b.status = 'maintenance')                   AS maintenance,
    ROUND(SUM(b.status = 'occupied') / COUNT(b.bed_id) * 100, 1) AS occupancy_pct
FROM   beds    b
JOIN   rooms   r ON r.room_id   = b.room_id
JOIN   hostels h ON h.hostel_id = r.hostel_id
GROUP  BY h.hostel_id, h.name
ORDER  BY h.gender_type, h.name;
