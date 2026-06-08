CREATE DATABASE IF NOT EXISTS hostel_management
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE hostel_management;

CREATE TABLE IF NOT EXISTS students (
    student_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(120)        NOT NULL,
    email           VARCHAR(180)        NOT NULL UNIQUE,
    phone           VARCHAR(20)         NOT NULL,
    matric_number   VARCHAR(30)         NOT NULL UNIQUE,
    gender          ENUM('male','female','other') NOT NULL,
    faculty         VARCHAR(100)        NOT NULL,
    department      VARCHAR(100)        NOT NULL,
    academic_level  VARCHAR(20)         NOT NULL,
    profile_picture VARCHAR(255)        NULL,
    password_hash   VARCHAR(255)        NOT NULL,          -- bcrypt hash
    is_active       TINYINT(1)          NOT NULL DEFAULT 1,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS hostels (
    hostel_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100)        NOT NULL,
    gender_type     ENUM('male','female','mixed') NOT NULL,
    address         VARCHAR(255)        NOT NULL,
    total_rooms     INT UNSIGNED        NOT NULL DEFAULT 0,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS rooms (
    room_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    hostel_id       INT UNSIGNED        NOT NULL,
    room_number     VARCHAR(20)         NOT NULL,
    capacity        TINYINT UNSIGNED    NOT NULL DEFAULT 4,
    occupied_beds   TINYINT UNSIGNED    NOT NULL DEFAULT 0,
    price_per_bed   DECIMAL(10,2)       NOT NULL,
    room_type       ENUM('single','double','quad','dormitory') NOT NULL DEFAULT 'quad',
    is_available    TINYINT(1)          NOT NULL DEFAULT 1,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_room_hostel
        FOREIGN KEY (hostel_id) REFERENCES hostels(hostel_id) ON DELETE CASCADE,
    CONSTRAINT uq_room_in_hostel
        UNIQUE (hostel_id, room_number)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS bedspaces (
    bedspace_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    room_id         INT UNSIGNED        NOT NULL,
    bed_number      VARCHAR(20)         NOT NULL,
    is_occupied     TINYINT(1)          NOT NULL DEFAULT 0,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bedspace_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    CONSTRAINT uq_bed_in_room
        UNIQUE (room_id, bed_number)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS allocations (
    allocation_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    bedspace_id     INT UNSIGNED        NOT NULL,
    academic_year   VARCHAR(10)         NOT NULL,          -- e.g. 2024/2025
    start_date      DATE                NOT NULL,
    end_date        DATE                NOT NULL,
    status          ENUM('pending','confirmed','cancelled') NOT NULL DEFAULT 'pending',
    allocated_at    DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_alloc_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_alloc_bedspace
        FOREIGN KEY (bedspace_id) REFERENCES bedspaces(bedspace_id) ON DELETE CASCADE,

    -- A student may only have ONE active (pending/confirmed) allocation per year
    CONSTRAINT uq_student_year
        UNIQUE (student_id, academic_year)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS payments (
    payment_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    allocation_id   INT UNSIGNED        NOT NULL,
    student_id      INT UNSIGNED        NOT NULL,
    amount          DECIMAL(10,2)       NOT NULL,
    payment_method  ENUM('card','bank_transfer','cash','online') NOT NULL DEFAULT 'online',
    reference       VARCHAR(60)         NOT NULL UNIQUE,   -- external txn reference
    status          ENUM('pending','success','failed','refunded') NOT NULL DEFAULT 'pending',
    paid_at         DATETIME            NULL,              -- NULL until successful
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,
    notes           TEXT                NULL,

    CONSTRAINT fk_pay_allocation
        FOREIGN KEY (allocation_id) REFERENCES allocations(allocation_id) ON DELETE CASCADE,
    CONSTRAINT fk_pay_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS audit_log (
    log_id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NULL,
    action          VARCHAR(60)         NOT NULL,  -- e.g. ALLOCATE_SUCCESS, PAYMENT_FAIL
    entity          VARCHAR(40)         NOT NULL,  -- allocation | payment | auth
    entity_id       INT UNSIGNED        NULL,
    details         JSON                NULL,
    ip_address      VARCHAR(45)         NULL,
    logged_at       DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_student (student_id),
    INDEX idx_action  (action),
    INDEX idx_logged  (logged_at)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS admin (
    admin_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username        VARCHAR(100)        NOT NULL UNIQUE,
    email           VARCHAR(180)        NOT NULL UNIQUE,
    phone           VARCHAR(20)         NULL,
    password_hash   VARCHAR(255)        NOT NULL,          -- bcrypt hash
    first_name      VARCHAR(100)        NOT NULL,
    last_name       VARCHAR(100)        NOT NULL,
    role            ENUM('super_admin','admin','manager','staff') NOT NULL DEFAULT 'admin',
    is_active       TINYINT(1)          NOT NULL DEFAULT 1,
    last_login      DATETIME            NULL,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_username (username),
    INDEX idx_email (email)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS staff (
    staff_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    hostel_id       INT UNSIGNED        NOT NULL,
    first_name      VARCHAR(100)        NOT NULL,
    last_name       VARCHAR(100)        NOT NULL,
    email           VARCHAR(180)        NULL,
    phone           VARCHAR(20)         NOT NULL,
    position        VARCHAR(60)         NOT NULL,  -- e.g. Caretaker, Warden, Maintenance
    salary          DECIMAL(10,2)       NULL,
    is_active       TINYINT(1)          NOT NULL DEFAULT 1,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_staff_hostel
        FOREIGN KEY (hostel_id) REFERENCES hostels(hostel_id) ON DELETE CASCADE,
    INDEX idx_position (position)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS room_inspections (
    inspection_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    room_id         INT UNSIGNED        NOT NULL,
    staff_id        INT UNSIGNED        NULL,
    condition_status ENUM('excellent','good','fair','poor','damaged') NOT NULL DEFAULT 'good',
    notes           TEXT                NULL,
    issues          JSON                NULL,  -- Array of identified issues
    inspected_at    DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_insp_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    CONSTRAINT fk_insp_staff
        FOREIGN KEY (staff_id) REFERENCES staff(staff_id) ON DELETE SET NULL,
    INDEX idx_room (room_id),
    INDEX idx_inspected (inspected_at)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS maintenance_orders (
    order_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    room_id         INT UNSIGNED        NOT NULL,
    staff_id        INT UNSIGNED        NULL,
    issue_description VARCHAR(255)      NOT NULL,
    priority        ENUM('low','medium','high','urgent') NOT NULL DEFAULT 'medium',
    status          ENUM('open','in_progress','completed','cancelled') NOT NULL DEFAULT 'open',
    cost            DECIMAL(10,2)       NULL,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at    DATETIME            NULL,

    CONSTRAINT fk_maint_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    CONSTRAINT fk_maint_staff
        FOREIGN KEY (staff_id) REFERENCES staff(staff_id) ON DELETE SET NULL,
    INDEX idx_room (room_id),
    INDEX idx_status (status),
    INDEX idx_priority (priority)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS complaints (
    complaint_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    hostel_id       INT UNSIGNED        NOT NULL,
    room_id         INT UNSIGNED        NULL,
    category        VARCHAR(60)         NOT NULL,  -- e.g. Noise, Cleanliness, Maintenance, Other
    title           VARCHAR(255)        NOT NULL,
    description     TEXT                NOT NULL,
    status          ENUM('open','in_progress','resolved','closed') NOT NULL DEFAULT 'open',
    priority        ENUM('low','medium','high','urgent') NOT NULL DEFAULT 'medium',
    assigned_to     INT UNSIGNED        NULL,  -- staff_id
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at     DATETIME            NULL,

    CONSTRAINT fk_comp_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_comp_hostel
        FOREIGN KEY (hostel_id) REFERENCES hostels(hostel_id) ON DELETE CASCADE,
    CONSTRAINT fk_comp_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE SET NULL,
    CONSTRAINT fk_comp_staff
        FOREIGN KEY (assigned_to) REFERENCES staff(staff_id) ON DELETE SET NULL,
    INDEX idx_student (student_id),
    INDEX idx_status (status),
    INDEX idx_created (created_at)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS deposits (
    deposit_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    allocation_id   INT UNSIGNED        NULL,
    amount          DECIMAL(10,2)       NOT NULL,
    deposit_type    ENUM('security','damage','key','other') NOT NULL DEFAULT 'security',
    status          ENUM('active','refunded','forfeited') NOT NULL DEFAULT 'active',
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    refunded_at     DATETIME            NULL,
    notes           TEXT                NULL,

    CONSTRAINT fk_dep_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_dep_allocation
        FOREIGN KEY (allocation_id) REFERENCES allocations(allocation_id) ON DELETE SET NULL,
    INDEX idx_student (student_id),
    INDEX idx_status (status)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS charges (
    charge_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    allocation_id   INT UNSIGNED        NULL,
    amount          DECIMAL(10,2)       NOT NULL,
    charge_type     VARCHAR(60)         NOT NULL,  -- e.g. Late Fee, Penalty, Utility, Damage
    description     VARCHAR(255)        NULL,
    status          ENUM('pending','paid','waived','cancelled') NOT NULL DEFAULT 'pending',
    due_date        DATE                NULL,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at         DATETIME            NULL,

    CONSTRAINT fk_chg_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_chg_allocation
        FOREIGN KEY (allocation_id) REFERENCES allocations(allocation_id) ON DELETE SET NULL,
    INDEX idx_student (student_id),
    INDEX idx_status (status),
    INDEX idx_due (due_date)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS room_transfers (
    transfer_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    from_room_id    INT UNSIGNED        NOT NULL,
    to_room_id      INT UNSIGNED        NOT NULL,
    reason          VARCHAR(255)        NULL,
    approved_by     INT UNSIGNED        NULL,  -- admin_id
    status          ENUM('requested','approved','rejected','completed') NOT NULL DEFAULT 'requested',
    transferred_at  DATETIME            NULL,
    requested_at    DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_trf_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_trf_from_room
        FOREIGN KEY (from_room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    CONSTRAINT fk_trf_to_room
        FOREIGN KEY (to_room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    CONSTRAINT fk_trf_admin
        FOREIGN KEY (approved_by) REFERENCES admin(admin_id) ON DELETE SET NULL,
    INDEX idx_student (student_id),
    INDEX idx_status (status)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS checkout_exit (
    checkout_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    allocation_id   INT UNSIGNED        NOT NULL,
    room_id         INT UNSIGNED        NOT NULL,
    exit_date       DATE                NOT NULL,
    reason          VARCHAR(255)        NULL,  -- e.g. Graduation, Transfer, Withdrawal
    condition_notes TEXT                NULL,
    damages_recorded JSON                NULL,
    charges_due     DECIMAL(10,2)       NULL,
    status          ENUM('pending','cleared','pending_charges','completed') NOT NULL DEFAULT 'pending',
    cleared_by      INT UNSIGNED        NULL,  -- staff_id
    cleared_at      DATETIME            NULL,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_chk_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,CONSTRAINT fk_chk_allocation
        FOREIGN KEY (allocation_id) REFERENCES allocations(allocation_id) ON DELETE CASCADE, CONSTRAINT fk_chk_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    CONSTRAINT fk_chk_staff
        FOREIGN KEY (cleared_by) REFERENCES staff(staff_id) ON DELETE SET NULL,
    INDEX idx_student (student_id),
    INDEX idx_exit_date (exit_date),
    INDEX idx_status (status)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS announcements (
    announcement_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title           VARCHAR(255)        NOT NULL,
    content         TEXT                NOT NULL,
    hostel_id       INT UNSIGNED        NULL,  -- NULL = system-wide
    category        VARCHAR(60)         NOT NULL,  -- e.g. Maintenance, Rules, Emergency, General
    priority        ENUM('low','medium','high','urgent') NOT NULL DEFAULT 'medium',
    created_by      INT UNSIGNED        NOT NULL,  -- admin_id
    published_at    DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at      DATETIME            NULL,

    CONSTRAINT fk_ann_hostel
        FOREIGN KEY (hostel_id) REFERENCES hostels(hostel_id) ON DELETE CASCADE,
    CONSTRAINT fk_ann_admin
        FOREIGN KEY (created_by) REFERENCES admin(admin_id) ON DELETE CASCADE,
    INDEX idx_hostel (hostel_id),
    INDEX idx_published (published_at)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS penalties (
    penalty_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    allocation_id   INT UNSIGNED        NULL,
    violation_type  VARCHAR(100)        NOT NULL,  -- e.g. Late Payment, Policy Violation, Damage
    amount          DECIMAL(10,2)       NOT NULL,
    reason          TEXT                NOT NULL,
    status          ENUM('active','paid','waived','cancelled') NOT NULL DEFAULT 'active',
    imposed_by      INT UNSIGNED        NOT NULL,  -- admin_id
    imposed_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at         DATETIME            NULL,

    CONSTRAINT fk_pen_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_pen_allocation
        FOREIGN KEY (allocation_id) REFERENCES allocations(allocation_id) ON DELETE SET NULL,
    CONSTRAINT fk_pen_admin
        FOREIGN KEY (imposed_by) REFERENCES admin(admin_id) ON DELETE CASCADE,
    INDEX idx_student (student_id),
    INDEX idx_status (status),
    INDEX idx_imposed (imposed_at)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS admin_audit_log (
    log_id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    admin_id        INT UNSIGNED        NOT NULL,
    action          VARCHAR(100)        NOT NULL,  -- e.g. CREATE_STUDENT, MODIFY_ALLOCATION, DELETE_COMPLAINT
    entity_type     VARCHAR(60)         NOT NULL,  -- e.g. student, allocation, complaint
    entity_id       INT UNSIGNED        NULL,
    old_values      JSON                NULL,
    new_values      JSON                NULL,
    ip_address      VARCHAR(45)         NULL,
    user_agent      VARCHAR(255)        NULL,
    logged_at       DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_adm_log_admin
        FOREIGN KEY (admin_id) REFERENCES admin(admin_id) ON DELETE CASCADE,
    INDEX idx_admin (admin_id),
    INDEX idx_action (action),
    INDEX idx_logged (logged_at)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS access_control (
    access_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    room_id         INT UNSIGNED        NOT NULL,
    card_number     VARCHAR(50)         NULL,
    access_type     ENUM('key','card','biometric','manual') NOT NULL DEFAULT 'card',
    is_active       TINYINT(1)          NOT NULL DEFAULT 1,
    issued_at       DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at      DATETIME            NULL,
    last_access     DATETIME            NULL,
    access_log      JSON                NULL,  -- Array of access events

    CONSTRAINT fk_acc_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_acc_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    INDEX idx_student (student_id),
    INDEX idx_card (card_number)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS academic_years (
    year_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    year            VARCHAR(10)         NOT NULL UNIQUE,  -- e.g. 2024/2025
    start_date      DATE                NOT NULL,
    end_date        DATE                NOT NULL,
    is_active       TINYINT(1)          NOT NULL DEFAULT 0,
    admission_deadline DATE              NULL,
    payment_deadline DATE               NULL,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS room_allocation_rules (
    rule_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    hostel_id       INT UNSIGNED        NULL,  -- NULL = system-wide
    rule_name       VARCHAR(100)        NOT NULL,
    rule_type       VARCHAR(60)         NOT NULL,  -- e.g. gender_match, year_preference, automatic
    rule_value      VARCHAR(255)        NOT NULL,
    priority        INT                 NOT NULL DEFAULT 0,
    is_active       TINYINT(1)          NOT NULL DEFAULT 1,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rar_hostel
        FOREIGN KEY (hostel_id) REFERENCES hostels(hostel_id) ON DELETE CASCADE
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS system_settings (
    setting_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    setting_key     VARCHAR(100)        NOT NULL UNIQUE,
    setting_value   TEXT                NOT NULL,
    setting_type    ENUM('string','number','boolean','json') NOT NULL DEFAULT 'string',
    description     TEXT                NULL,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS refunds (
    refund_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    payment_id      INT UNSIGNED        NOT NULL,
    student_id      INT UNSIGNED        NOT NULL,
    amount          DECIMAL(10,2)       NOT NULL,
    reason          VARCHAR(255)        NOT NULL,  -- e.g. Checkout, Scholarship, Overpayment
    status          ENUM('pending','approved','processed','cancelled') NOT NULL DEFAULT 'pending',
    processed_at    DATETIME            NULL,
    approved_by     INT UNSIGNED        NULL,  -- admin_id
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ref_payment
        FOREIGN KEY (payment_id) REFERENCES payments(payment_id) ON DELETE CASCADE,
    CONSTRAINT fk_ref_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_ref_admin
        FOREIGN KEY (approved_by) REFERENCES admin(admin_id) ON DELETE SET NULL,
    INDEX idx_student (student_id),
    INDEX idx_status (status)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS payment_plans (
    plan_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    allocation_id   INT UNSIGNED        NOT NULL,
    total_amount    DECIMAL(10,2)       NOT NULL,
    num_installments INT UNSIGNED       NOT NULL,
    installment_amount DECIMAL(10,2)    NOT NULL,
    frequency       ENUM('weekly','biweekly','monthly','quarterly') NOT NULL DEFAULT 'monthly',
    first_due_date  DATE                NOT NULL,
    status          ENUM('active','completed','defaulted','cancelled') NOT NULL DEFAULT 'active',
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pp_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_pp_allocation
        FOREIGN KEY (allocation_id) REFERENCES allocations(allocation_id) ON DELETE CASCADE,
    INDEX idx_student (student_id),
    INDEX idx_status (status)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS emergency_contacts (
    contact_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    contact_name    VARCHAR(150)        NOT NULL,
    relation        VARCHAR(60)         NOT NULL,  -- e.g. Parent, Guardian, Sibling
    phone           VARCHAR(20)         NOT NULL,
    email           VARCHAR(180)        NULL,
    address         TEXT                NULL,
    is_primary      TINYINT(1)          NOT NULL DEFAULT 0,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ec_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    INDEX idx_student (student_id)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS room_assets (
    asset_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    room_id         INT UNSIGNED        NOT NULL,
    asset_name      VARCHAR(100)        NOT NULL,  -- e.g. Bed, Desk, Wardrobe, Chair
    asset_code      VARCHAR(50)         NULL,  -- Serial/barcode number
    `condition`     ENUM('new','good','fair','poor','damaged') NOT NULL DEFAULT 'good',
    purchase_date   DATE                NULL,
    warranty_expires DATE               NULL,
    assigned_at     DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ra_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    INDEX idx_room (room_id)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS asset_maintenance (
    maintenance_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    asset_id        INT UNSIGNED        NOT NULL,
    staff_id        INT UNSIGNED        NULL,
    issue_description VARCHAR(255)      NOT NULL,
    status          ENUM('open','in_progress','completed','cancelled') NOT NULL DEFAULT 'open',
    estimated_cost  DECIMAL(10,2)       NULL,
    actual_cost     DECIMAL(10,2)       NULL,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at    DATETIME            NULL,

    CONSTRAINT fk_am_asset
        FOREIGN KEY (asset_id) REFERENCES room_assets(asset_id) ON DELETE CASCADE,
    CONSTRAINT fk_am_staff
        FOREIGN KEY (staff_id) REFERENCES staff(staff_id) ON DELETE SET NULL,
    INDEX idx_asset (asset_id),
    INDEX idx_status (status)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS health_records (
    record_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    blood_group     VARCHAR(5)          NULL,
    allergies       TEXT                NULL,
    medical_conditions TEXT             NULL,
    vaccination_status VARCHAR(100)    NULL,
    medical_clearance TINYINT(1)       NOT NULL DEFAULT 0,
    clearance_date  DATE                NULL,
    clearance_valid_until DATE          NULL,
    notes           TEXT                NULL,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_hr_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    UNIQUE (student_id)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS room_preferences (
    preference_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    academic_year   VARCHAR(10)         NOT NULL,
    preferred_hostel_id INT UNSIGNED   NULL,
    preferred_floor INT UNSIGNED        NULL,
    roommate_preferences JSON           NULL,  -- List of student IDs
    disability_requirements TEXT        NULL,
    special_requests TEXT               NULL,
    submitted_at    DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_rp_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_rp_hostel
        FOREIGN KEY (preferred_hostel_id) REFERENCES hostels(hostel_id) ON DELETE SET NULL,
    INDEX idx_student (student_id),
    INDEX idx_year (academic_year)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS billing_cycles (
    cycle_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    academic_year   VARCHAR(10)         NOT NULL,
    cycle_number    INT UNSIGNED        NOT NULL,  -- 1, 2, 3, etc.
    start_date      DATE                NOT NULL,
    end_date        DATE                NOT NULL,
    invoice_date    DATE                NOT NULL,
    due_date        DATE                NOT NULL,
    status          ENUM('open','invoiced','closed') NOT NULL DEFAULT 'open',
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_year (academic_year)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS documents (
    document_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    document_type   VARCHAR(60)         NOT NULL,  -- e.g. ID_Card, Enrollment_Letter, Medical_Clearance
    file_name       VARCHAR(255)        NOT NULL,
    file_path       VARCHAR(255)        NOT NULL,
    file_size       INT UNSIGNED        NULL,
    mime_type       VARCHAR(60)         NULL,
    expiry_date     DATE                NULL,
    is_verified     TINYINT(1)          NOT NULL DEFAULT 0,
    verified_by     INT UNSIGNED        NULL,  -- admin_id
    uploaded_at     DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_doc_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_doc_admin
        FOREIGN KEY (verified_by) REFERENCES admin(admin_id) ON DELETE SET NULL,
    INDEX idx_student (student_id),
    INDEX idx_type (document_type)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS feedback_ratings (
    rating_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    room_id         INT UNSIGNED        NULL,
    hostel_id       INT UNSIGNED        NOT NULL,
    category        VARCHAR(60)         NOT NULL,  -- e.g. Cleanliness, Maintenance, Staff, Facilities
    rating          INT UNSIGNED        NOT NULL,  -- 1-5 stars
    comment         TEXT                NULL,
    is_anonymous    TINYINT(1)          NOT NULL DEFAULT 0,
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_fb_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_fb_room
        FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE SET NULL,
    CONSTRAINT fk_fb_hostel
        FOREIGN KEY (hostel_id) REFERENCES hostels(hostel_id) ON DELETE CASCADE,
    INDEX idx_hostel (hostel_id),
    INDEX idx_category (category)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS visitor_policies (
    policy_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    hostel_id       INT UNSIGNED        NULL,  -- NULL = system-wide default
    visiting_hours_start TIME           NOT NULL,
    visiting_hours_end TIME             NOT NULL,
    max_visitors_per_day INT UNSIGNED   NOT NULL DEFAULT 2,
    max_stay_duration INT UNSIGNED      NULL,  -- minutes
    allowed_days    VARCHAR(60)         NULL,  -- e.g. 'Mon,Tue,Wed,Thu,Fri,Sat,Sun' or 'Weekends'
    visitor_id_required TINYINT(1)      NOT NULL DEFAULT 1,
    overnight_allowed TINYINT(1)        NOT NULL DEFAULT 0,
    guest_registration_required TINYINT(1) NOT NULL DEFAULT 1,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_vp_hostel
        FOREIGN KEY (hostel_id) REFERENCES hostels(hostel_id) ON DELETE CASCADE
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS communication_log (
    message_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED        NOT NULL,
    communication_type ENUM('sms','email','push_notification','in_app') NOT NULL,
    recipient       VARCHAR(255)        NOT NULL,  -- phone/email
    subject         VARCHAR(255)        NULL,
    message_content TEXT                NOT NULL,
    message_type    VARCHAR(60)         NOT NULL,  -- e.g. Reminder, Notice, Alert, Receipt
    status          ENUM('pending','sent','failed','read') NOT NULL DEFAULT 'pending',
    sent_at         DATETIME            NULL,
    read_at         DATETIME            NULL,
    sent_by         INT UNSIGNED        NULL,  -- admin_id or system
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_comm_student
        FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_comm_admin
        FOREIGN KEY (sent_by) REFERENCES admin(admin_id) ON DELETE SET NULL,
    INDEX idx_student (student_id),
    INDEX idx_status (status),
    INDEX idx_created (created_at)
) ENGINE=InnoDB;


INSERT INTO hostels (name, gender_type, address, total_rooms) VALUES
  ('Hall A – Female',   'female', '1 Campus Drive, East Wing',   66),
  ('Hall B – Female',   'female', '2 Campus Drive, South Wing',  66),
  ('Hall E – Female',   'female', '3 Campus Drive, West Wing',  120),
  ('Hall C1 – Male',    'male',   '4 Campus Drive, North Wing',  44),
  ('Hall C2 – Male',    'male',   '5 Campus Drive, North Wing',  22),
  ('Hall D – Male',     'male',   '6 Campus Drive, Central Wing', 76);

-- Hall A rooms (female, 66 rooms, 6 beds each)
INSERT INTO rooms (hostel_id, room_number, capacity, price_per_bed, room_type) VALUES
  (1, 'A001', 6, 35000.00, 'dormitory'),
  (1, 'A002', 6, 35000.00, 'dormitory'),
  (1, 'A003', 6, 35000.00, 'dormitory'),
  (1, 'A004', 6, 35000.00, 'dormitory'),
  (1, 'A005', 6, 35000.00, 'dormitory'),
  (1, 'A006', 6, 35000.00, 'dormitory'),
  (1, 'A007', 6, 35000.00, 'dormitory'),
  (1, 'A008', 6, 35000.00, 'dormitory'),
  (1, 'A009', 6, 35000.00, 'dormitory'),
  (1, 'A010', 6, 35000.00, 'dormitory'),
  (1, 'A011', 6, 35000.00, 'dormitory'),
  (1, 'A012', 6, 35000.00, 'dormitory'),
  (1, 'A013', 6, 35000.00, 'dormitory'),
  (1, 'A014', 6, 35000.00, 'dormitory'),
  (1, 'A015', 6, 35000.00, 'dormitory'),
  (1, 'A016', 6, 35000.00, 'dormitory'),
  (1, 'A017', 6, 35000.00, 'dormitory'),
  (1, 'A018', 6, 35000.00, 'dormitory'),
  (1, 'A019', 6, 35000.00, 'dormitory'),
  (1, 'A020', 6, 35000.00, 'dormitory'),
  (1, 'A021', 6, 35000.00, 'dormitory'),
  (1, 'A022', 6, 35000.00, 'dormitory'),
  (1, 'A023', 6, 35000.00, 'dormitory'),
  (1, 'A024', 6, 35000.00, 'dormitory'),
  (1, 'A025', 6, 35000.00, 'dormitory'),
  (1, 'A026', 6, 35000.00, 'dormitory'),
  (1, 'A027', 6, 35000.00, 'dormitory'),
  (1, 'A028', 6, 35000.00, 'dormitory'),
  (1, 'A029', 6, 35000.00, 'dormitory'),
  (1, 'A030', 6, 35000.00, 'dormitory'),
  (1, 'A031', 6, 35000.00, 'dormitory'),
  (1, 'A032', 6, 35000.00, 'dormitory'),
  (1, 'A033', 6, 35000.00, 'dormitory'),
  (1, 'A034', 6, 35000.00, 'dormitory'),
  (1, 'A035', 6, 35000.00, 'dormitory'),
  (1, 'A036', 6, 35000.00, 'dormitory'),
  (1, 'A037', 6, 35000.00, 'dormitory'),
  (1, 'A038', 6, 35000.00, 'dormitory'),
  (1, 'A039', 6, 35000.00, 'dormitory'),
  (1, 'A040', 6, 35000.00, 'dormitory'),
  (1, 'A041', 6, 35000.00, 'dormitory'),
  (1, 'A042', 6, 35000.00, 'dormitory'),
  (1, 'A043', 6, 35000.00, 'dormitory'),
  (1, 'A044', 6, 35000.00, 'dormitory'),
  (1, 'A045', 6, 35000.00, 'dormitory'),
  (1, 'A046', 6, 35000.00, 'dormitory'),
  (1, 'A047', 6, 35000.00, 'dormitory'),
  (1, 'A048', 6, 35000.00, 'dormitory'),
  (1, 'A049', 6, 35000.00, 'dormitory'),
  (1, 'A050', 6, 35000.00, 'dormitory'),
  (1, 'A051', 6, 35000.00, 'dormitory'),
  (1, 'A052', 6, 35000.00, 'dormitory'),
  (1, 'A053', 6, 35000.00, 'dormitory'),
  (1, 'A054', 6, 35000.00, 'dormitory'),
  (1, 'A055', 6, 35000.00, 'dormitory'),
  (1, 'A056', 6, 35000.00, 'dormitory'),
  (1, 'A057', 6, 35000.00, 'dormitory'),
  (1, 'A058', 6, 35000.00, 'dormitory'),
  (1, 'A059', 6, 35000.00, 'dormitory'),
  (1, 'A060', 6, 35000.00, 'dormitory'),
  (1, 'A061', 6, 35000.00, 'dormitory'),
  (1, 'A062', 6, 35000.00, 'dormitory'),
  (1, 'A063', 6, 35000.00, 'dormitory'),
  (1, 'A064', 6, 35000.00, 'dormitory'),
  (1, 'A065', 6, 35000.00, 'dormitory'),
  (1, 'A066', 6, 35000.00, 'dormitory');

-- Hall B rooms (female, 66 rooms, 6 beds each)
INSERT INTO rooms (hostel_id, room_number, capacity, price_per_bed, room_type) VALUES
  (2, 'B001', 6, 35000.00, 'dormitory'),
  (2, 'B002', 6, 35000.00, 'dormitory'),
  (2, 'B003', 6, 35000.00, 'dormitory'),
  (2, 'B004', 6, 35000.00, 'dormitory'),
  (2, 'B005', 6, 35000.00, 'dormitory'),
  (2, 'B006', 6, 35000.00, 'dormitory'),
  (2, 'B007', 6, 35000.00, 'dormitory'),
  (2, 'B008', 6, 35000.00, 'dormitory'),
  (2, 'B009', 6, 35000.00, 'dormitory'),
  (2, 'B010', 6, 35000.00, 'dormitory'),
  (2, 'B011', 6, 35000.00, 'dormitory'),
  (2, 'B012', 6, 35000.00, 'dormitory'),
  (2, 'B013', 6, 35000.00, 'dormitory'),
  (2, 'B014', 6, 35000.00, 'dormitory'),
  (2, 'B015', 6, 35000.00, 'dormitory'),
  (2, 'B016', 6, 35000.00, 'dormitory'),
  (2, 'B017', 6, 35000.00, 'dormitory'),
  (2, 'B018', 6, 35000.00, 'dormitory'),
  (2, 'B019', 6, 35000.00, 'dormitory'),
  (2, 'B020', 6, 35000.00, 'dormitory'),
  (2, 'B021', 6, 35000.00, 'dormitory'),
  (2, 'B022', 6, 35000.00, 'dormitory'),
  (2, 'B023', 6, 35000.00, 'dormitory'),
  (2, 'B024', 6, 35000.00, 'dormitory'),
  (2, 'B025', 6, 35000.00, 'dormitory'),
  (2, 'B026', 6, 35000.00, 'dormitory'),
  (2, 'B027', 6, 35000.00, 'dormitory'),
  (2, 'B028', 6, 35000.00, 'dormitory'),
  (2, 'B029', 6, 35000.00, 'dormitory'),
  (2, 'B030', 6, 35000.00, 'dormitory'),
  (2, 'B031', 6, 35000.00, 'dormitory'),
  (2, 'B032', 6, 35000.00, 'dormitory'),
  (2, 'B033', 6, 35000.00, 'dormitory'),
  (2, 'B034', 6, 35000.00, 'dormitory'),
  (2, 'B035', 6, 35000.00, 'dormitory'),
  (2, 'B036', 6, 35000.00, 'dormitory'),
  (2, 'B037', 6, 35000.00, 'dormitory'),
  (2, 'B038', 6, 35000.00, 'dormitory'),
  (2, 'B039', 6, 35000.00, 'dormitory'),
  (2, 'B040', 6, 35000.00, 'dormitory'),
  (2, 'B041', 6, 35000.00, 'dormitory'),
  (2, 'B042', 6, 35000.00, 'dormitory'),
  (2, 'B043', 6, 35000.00, 'dormitory'),
  (2, 'B044', 6, 35000.00, 'dormitory'),
  (2, 'B045', 6, 35000.00, 'dormitory'),
  (2, 'B046', 6, 35000.00, 'dormitory'),
  (2, 'B047', 6, 35000.00, 'dormitory'),
  (2, 'B048', 6, 35000.00, 'dormitory'),
  (2, 'B049', 6, 35000.00, 'dormitory'),
  (2, 'B050', 6, 35000.00, 'dormitory'),
  (2, 'B051', 6, 35000.00, 'dormitory'),
  (2, 'B052', 6, 35000.00, 'dormitory'),
  (2, 'B053', 6, 35000.00, 'dormitory'),
  (2, 'B054', 6, 35000.00, 'dormitory'),
  (2, 'B055', 6, 35000.00, 'dormitory'),
  (2, 'B056', 6, 35000.00, 'dormitory'),
  (2, 'B057', 6, 35000.00, 'dormitory'),
  (2, 'B058', 6, 35000.00, 'dormitory'),
  (2, 'B059', 6, 35000.00, 'dormitory'),
  (2, 'B060', 6, 35000.00, 'dormitory'),
  (2, 'B061', 6, 35000.00, 'dormitory'),
  (2, 'B062', 6, 35000.00, 'dormitory'),
  (2, 'B063', 6, 35000.00, 'dormitory'),
  (2, 'B064', 6, 35000.00, 'dormitory'),
  (2, 'B065', 6, 35000.00, 'dormitory'),
  (2, 'B066', 6, 35000.00, 'dormitory');

-- Hall E rooms (female, 120 rooms, 4 beds each)
INSERT INTO rooms (hostel_id, room_number, capacity, price_per_bed, room_type) VALUES
  (3, 'E001', 4, 45000.00, 'quad'),
  (3, 'E002', 4, 45000.00, 'quad'),
  (3, 'E003', 4, 45000.00, 'quad'),
  (3, 'E004', 4, 45000.00, 'quad'),
  (3, 'E005', 4, 45000.00, 'quad'),
  (3, 'E006', 4, 45000.00, 'quad'),
  (3, 'E007', 4, 45000.00, 'quad'),
  (3, 'E008', 4, 45000.00, 'quad'),
  (3, 'E009', 4, 45000.00, 'quad'),
  (3, 'E010', 4, 45000.00, 'quad'),
  (3, 'E011', 4, 45000.00, 'quad'),
  (3, 'E012', 4, 45000.00, 'quad'),
  (3, 'E013', 4, 45000.00, 'quad'),
  (3, 'E014', 4, 45000.00, 'quad'),
  (3, 'E015', 4, 45000.00, 'quad'),
  (3, 'E016', 4, 45000.00, 'quad'),
  (3, 'E017', 4, 45000.00, 'quad'),
  (3, 'E018', 4, 45000.00, 'quad'),
  (3, 'E019', 4, 45000.00, 'quad'),
  (3, 'E020', 4, 45000.00, 'quad'),
  (3, 'E021', 4, 45000.00, 'quad'),
  (3, 'E022', 4, 45000.00, 'quad'),
  (3, 'E023', 4, 45000.00, 'quad'),
  (3, 'E024', 4, 45000.00, 'quad'),
  (3, 'E025', 4, 45000.00, 'quad'),
  (3, 'E026', 4, 45000.00, 'quad'),
  (3, 'E027', 4, 45000.00, 'quad'),
  (3, 'E028', 4, 45000.00, 'quad'),
  (3, 'E029', 4, 45000.00, 'quad'),
  (3, 'E030', 4, 45000.00, 'quad'),
  (3, 'E031', 4, 45000.00, 'quad'),
  (3, 'E032', 4, 45000.00, 'quad'),
  (3, 'E033', 4, 45000.00, 'quad'),
  (3, 'E034', 4, 45000.00, 'quad'),
  (3, 'E035', 4, 45000.00, 'quad'),
  (3, 'E036', 4, 45000.00, 'quad'),
  (3, 'E037', 4, 45000.00, 'quad'),
  (3, 'E038', 4, 45000.00, 'quad'),
  (3, 'E039', 4, 45000.00, 'quad'),
  (3, 'E040', 4, 45000.00, 'quad'),
  (3, 'E041', 4, 45000.00, 'quad'),
  (3, 'E042', 4, 45000.00, 'quad'),
  (3, 'E043', 4, 45000.00, 'quad'),
  (3, 'E044', 4, 45000.00, 'quad'),
  (3, 'E045', 4, 45000.00, 'quad'),
  (3, 'E046', 4, 45000.00, 'quad'),
  (3, 'E047', 4, 45000.00, 'quad'),
  (3, 'E048', 4, 45000.00, 'quad'),
  (3, 'E049', 4, 45000.00, 'quad'),
  (3, 'E050', 4, 45000.00, 'quad'),
  (3, 'E051', 4, 45000.00, 'quad'),
  (3, 'E052', 4, 45000.00, 'quad'),
  (3, 'E053', 4, 45000.00, 'quad'),
  (3, 'E054', 4, 45000.00, 'quad'),
  (3, 'E055', 4, 45000.00, 'quad'),
  (3, 'E056', 4, 45000.00, 'quad'),
  (3, 'E057', 4, 45000.00, 'quad'),
  (3, 'E058', 4, 45000.00, 'quad'),
  (3, 'E059', 4, 45000.00, 'quad'),
  (3, 'E060', 4, 45000.00, 'quad'),
  (3, 'E061', 4, 45000.00, 'quad'),
  (3, 'E062', 4, 45000.00, 'quad'),
  (3, 'E063', 4, 45000.00, 'quad'),
  (3, 'E064', 4, 45000.00, 'quad'),
  (3, 'E065', 4, 45000.00, 'quad'),
  (3, 'E066', 4, 45000.00, 'quad'),
  (3, 'E067', 4, 45000.00, 'quad'),
  (3, 'E068', 4, 45000.00, 'quad'),
  (3, 'E069', 4, 45000.00, 'quad'),
  (3, 'E070', 4, 45000.00, 'quad'),
  (3, 'E071', 4, 45000.00, 'quad'),
  (3, 'E072', 4, 45000.00, 'quad'),
  (3, 'E073', 4, 45000.00, 'quad'),
  (3, 'E074', 4, 45000.00, 'quad'),
  (3, 'E075', 4, 45000.00, 'quad'),
  (3, 'E076', 4, 45000.00, 'quad'),
  (3, 'E077', 4, 45000.00, 'quad'),
  (3, 'E078', 4, 45000.00, 'quad'),
  (3, 'E079', 4, 45000.00, 'quad'),
  (3, 'E080', 4, 45000.00, 'quad'),
  (3, 'E081', 4, 45000.00, 'quad'),
  (3, 'E082', 4, 45000.00, 'quad'),
  (3, 'E083', 4, 45000.00, 'quad'),
  (3, 'E084', 4, 45000.00, 'quad'),
  (3, 'E085', 4, 45000.00, 'quad'),
  (3, 'E086', 4, 45000.00, 'quad'),
  (3, 'E087', 4, 45000.00, 'quad'),
  (3, 'E088', 4, 45000.00, 'quad'),
  (3, 'E089', 4, 45000.00, 'quad'),
  (3, 'E090', 4, 45000.00, 'quad'),
  (3, 'E091', 4, 45000.00, 'quad'),
  (3, 'E092', 4, 45000.00, 'quad'),
  (3, 'E093', 4, 45000.00, 'quad'),
  (3, 'E094', 4, 45000.00, 'quad'),
  (3, 'E095', 4, 45000.00, 'quad'),
  (3, 'E096', 4, 45000.00, 'quad'),
  (3, 'E097', 4, 45000.00, 'quad'),
  (3, 'E098', 4, 45000.00, 'quad'),
  (3, 'E099', 4, 45000.00, 'quad'),
  (3, 'E100', 4, 45000.00, 'quad'),
  (3, 'E101', 4, 45000.00, 'quad'),
  (3, 'E102', 4, 45000.00, 'quad'),
  (3, 'E103', 4, 45000.00, 'quad'),
  (3, 'E104', 4, 45000.00, 'quad'),
  (3, 'E105', 4, 45000.00, 'quad'),
  (3, 'E106', 4, 45000.00, 'quad'),
  (3, 'E107', 4, 45000.00, 'quad'),
  (3, 'E108', 4, 45000.00, 'quad'),
  (3, 'E109', 4, 45000.00, 'quad'),
  (3, 'E110', 4, 45000.00, 'quad'),
  (3, 'E111', 4, 45000.00, 'quad'),
  (3, 'E112', 4, 45000.00, 'quad'),
  (3, 'E113', 4, 45000.00, 'quad'),
  (3, 'E114', 4, 45000.00, 'quad'),
  (3, 'E115', 4, 45000.00, 'quad'),
  (3, 'E116', 4, 45000.00, 'quad'),
  (3, 'E117', 4, 45000.00, 'quad'),
  (3, 'E118', 4, 45000.00, 'quad'),
  (3, 'E119', 4, 45000.00, 'quad'),
  (3, 'E120', 4, 45000.00, 'quad');

-- Hall C1 rooms (male, 44 rooms, 6 beds each)
INSERT INTO rooms (hostel_id, room_number, capacity, price_per_bed, room_type) VALUES
  (4, 'C1001', 6, 35000.00, 'dormitory'),
  (4, 'C1002', 6, 35000.00, 'dormitory'),
  (4, 'C1003', 6, 35000.00, 'dormitory'),
  (4, 'C1004', 6, 35000.00, 'dormitory'),
  (4, 'C1005', 6, 35000.00, 'dormitory'),
  (4, 'C1006', 6, 35000.00, 'dormitory'),
  (4, 'C1007', 6, 35000.00, 'dormitory'),
  (4, 'C1008', 6, 35000.00, 'dormitory'),
  (4, 'C1009', 6, 35000.00, 'dormitory'),
  (4, 'C1010', 6, 35000.00, 'dormitory'),
  (4, 'C1011', 6, 35000.00, 'dormitory'),
  (4, 'C1012', 6, 35000.00, 'dormitory'),
  (4, 'C1013', 6, 35000.00, 'dormitory'),
  (4, 'C1014', 6, 35000.00, 'dormitory'),
  (4, 'C1015', 6, 35000.00, 'dormitory'),
  (4, 'C1016', 6, 35000.00, 'dormitory'),
  (4, 'C1017', 6, 35000.00, 'dormitory'),
  (4, 'C1018', 6, 35000.00, 'dormitory'),
  (4, 'C1019', 6, 35000.00, 'dormitory'),
  (4, 'C1020', 6, 35000.00, 'dormitory'),
  (4, 'C1021', 6, 35000.00, 'dormitory'),
  (4, 'C1022', 6, 35000.00, 'dormitory'),
  (4, 'C1023', 6, 35000.00, 'dormitory'),
  (4, 'C1024', 6, 35000.00, 'dormitory'),
  (4, 'C1025', 6, 35000.00, 'dormitory'),
  (4, 'C1026', 6, 35000.00, 'dormitory'),
  (4, 'C1027', 6, 35000.00, 'dormitory'),
  (4, 'C1028', 6, 35000.00, 'dormitory'),
  (4, 'C1029', 6, 35000.00, 'dormitory'),
  (4, 'C1030', 6, 35000.00, 'dormitory'),
  (4, 'C1031', 6, 35000.00, 'dormitory'),
  (4, 'C1032', 6, 35000.00, 'dormitory'),
  (4, 'C1033', 6, 35000.00, 'dormitory'),
  (4, 'C1034', 6, 35000.00, 'dormitory'),
  (4, 'C1035', 6, 35000.00, 'dormitory'),
  (4, 'C1036', 6, 35000.00, 'dormitory'),
  (4, 'C1037', 6, 35000.00, 'dormitory'),
  (4, 'C1038', 6, 35000.00, 'dormitory'),
  (4, 'C1039', 6, 35000.00, 'dormitory'),
  (4, 'C1040', 6, 35000.00, 'dormitory'),
  (4, 'C1041', 6, 35000.00, 'dormitory'),
  (4, 'C1042', 6, 35000.00, 'dormitory'),
  (4, 'C1043', 6, 35000.00, 'dormitory'),
  (4, 'C1044', 6, 35000.00, 'dormitory');

-- Hall C2 rooms (male, 22 rooms, 6 beds each)
INSERT INTO rooms (hostel_id, room_number, capacity, price_per_bed, room_type) VALUES
  (5, 'C2001', 6, 35000.00, 'dormitory'),
  (5, 'C2002', 6, 35000.00, 'dormitory'),
  (5, 'C2003', 6, 35000.00, 'dormitory'),
  (5, 'C2004', 6, 35000.00, 'dormitory'),
  (5, 'C2005', 6, 35000.00, 'dormitory'),
  (5, 'C2006', 6, 35000.00, 'dormitory'),
  (5, 'C2007', 6, 35000.00, 'dormitory'),
  (5, 'C2008', 6, 35000.00, 'dormitory'),
  (5, 'C2009', 6, 35000.00, 'dormitory'),
  (5, 'C2010', 6, 35000.00, 'dormitory'),
  (5, 'C2011', 6, 35000.00, 'dormitory'),
  (5, 'C2012', 6, 35000.00, 'dormitory'),
  (5, 'C2013', 6, 35000.00, 'dormitory'),
  (5, 'C2014', 6, 35000.00, 'dormitory'),
  (5, 'C2015', 6, 35000.00, 'dormitory'),
  (5, 'C2016', 6, 35000.00, 'dormitory'),
  (5, 'C2017', 6, 35000.00, 'dormitory'),
  (5, 'C2018', 6, 35000.00, 'dormitory'),
  (5, 'C2019', 6, 35000.00, 'dormitory'),
  (5, 'C2020', 6, 35000.00, 'dormitory'),
  (5, 'C2021', 6, 35000.00, 'dormitory'),
  (5, 'C2022', 6, 35000.00, 'dormitory');

-- Hall D rooms (male, 76 rooms, 4 beds each)
INSERT INTO rooms (hostel_id, room_number, capacity, price_per_bed, room_type) VALUES
  (6, 'D001', 4, 45000.00, 'quad'),
  (6, 'D002', 4, 45000.00, 'quad'),
  (6, 'D003', 4, 45000.00, 'quad'),
  (6, 'D004', 4, 45000.00, 'quad'),
  (6, 'D005', 4, 45000.00, 'quad'),
  (6, 'D006', 4, 45000.00, 'quad'),
  (6, 'D007', 4, 45000.00, 'quad'),
  (6, 'D008', 4, 45000.00, 'quad'),
  (6, 'D009', 4, 45000.00, 'quad'),
  (6, 'D010', 4, 45000.00, 'quad'),
  (6, 'D011', 4, 45000.00, 'quad'),
  (6, 'D012', 4, 45000.00, 'quad'),
  (6, 'D013', 4, 45000.00, 'quad'),
  (6, 'D014', 4, 45000.00, 'quad'),
  (6, 'D015', 4, 45000.00, 'quad'),
  (6, 'D016', 4, 45000.00, 'quad'),
  (6, 'D017', 4, 45000.00, 'quad'),
  (6, 'D018', 4, 45000.00, 'quad'),
  (6, 'D019', 4, 45000.00, 'quad'),
  (6, 'D020', 4, 45000.00, 'quad'),
  (6, 'D021', 4, 45000.00, 'quad'),
  (6, 'D022', 4, 45000.00, 'quad'),
  (6, 'D023', 4, 45000.00, 'quad'),
  (6, 'D024', 4, 45000.00, 'quad'),
  (6, 'D025', 4, 45000.00, 'quad'),
  (6, 'D026', 4, 45000.00, 'quad'),
  (6, 'D027', 4, 45000.00, 'quad'),
  (6, 'D028', 4, 45000.00, 'quad'),
  (6, 'D029', 4, 45000.00, 'quad'),
  (6, 'D030', 4, 45000.00, 'quad'),
  (6, 'D031', 4, 45000.00, 'quad'),
  (6, 'D032', 4, 45000.00, 'quad'),
  (6, 'D033', 4, 45000.00, 'quad'),
  (6, 'D034', 4, 45000.00, 'quad'),
  (6, 'D035', 4, 45000.00, 'quad'),
  (6, 'D036', 4, 45000.00, 'quad'),
  (6, 'D037', 4, 45000.00, 'quad'),
  (6, 'D038', 4, 45000.00, 'quad'),
  (6, 'D039', 4, 45000.00, 'quad'),
  (6, 'D040', 4, 45000.00, 'quad'),
  (6, 'D041', 4, 45000.00, 'quad'),
  (6, 'D042', 4, 45000.00, 'quad'),
  (6, 'D043', 4, 45000.00, 'quad'),
  (6, 'D044', 4, 45000.00, 'quad'),
  (6, 'D045', 4, 45000.00, 'quad'),
  (6, 'D046', 4, 45000.00, 'quad'),
  (6, 'D047', 4, 45000.00, 'quad'),
  (6, 'D048', 4, 45000.00, 'quad'),
  (6, 'D049', 4, 45000.00, 'quad'),
  (6, 'D050', 4, 45000.00, 'quad'),
  (6, 'D051', 4, 45000.00, 'quad'),
  (6, 'D052', 4, 45000.00, 'quad'),
  (6, 'D053', 4, 45000.00, 'quad'),
  (6, 'D054', 4, 45000.00, 'quad'),
  (6, 'D055', 4, 45000.00, 'quad'),
  (6, 'D056', 4, 45000.00, 'quad'),
  (6, 'D057', 4, 45000.00, 'quad'),
  (6, 'D058', 4, 45000.00, 'quad'),
  (6, 'D059', 4, 45000.00, 'quad'),
  (6, 'D060', 4, 45000.00, 'quad'),
  (6, 'D061', 4, 45000.00, 'quad'),
  (6, 'D062', 4, 45000.00, 'quad'),
  (6, 'D063', 4, 45000.00, 'quad'),
  (6, 'D064', 4, 45000.00, 'quad'),
  (6, 'D065', 4, 45000.00, 'quad'),
  (6, 'D066', 4, 45000.00, 'quad'),
  (6, 'D067', 4, 45000.00, 'quad'),
  (6, 'D068', 4, 45000.00, 'quad'),
  (6, 'D069', 4, 45000.00, 'quad'),
  (6, 'D070', 4, 45000.00, 'quad'),
  (6, 'D071', 4, 45000.00, 'quad'),
  (6, 'D072', 4, 45000.00, 'quad'),
  (6, 'D073', 4, 45000.00, 'quad'),
  (6, 'D074', 4, 45000.00, 'quad'),
  (6, 'D075', 4, 45000.00, 'quad'),
  (6, 'D076', 4, 45000.00, 'quad');

-- Insert bedspaces for Hall A (rooms 1-66, 6 beds each)
INSERT INTO bedspaces (room_id, bed_number) VALUES
  (1,'1'),(1,'2'),(1,'3'),(1,'4'),(1,'5'),(1,'6'),
  (2,'1'),(2,'2'),(2,'3'),(2,'4'),(2,'5'),(2,'6'),
  (3,'1'),(3,'2'),(3,'3'),(3,'4'),(3,'5'),(3,'6'),
  (4,'1'),(4,'2'),(4,'3'),(4,'4'),(4,'5'),(4,'6'),
  (5,'1'),(5,'2'),(5,'3'),(5,'4'),(5,'5'),(5,'6'),
  (6,'1'),(6,'2'),(6,'3'),(6,'4'),(6,'5'),(6,'6'),
  (7,'1'),(7,'2'),(7,'3'),(7,'4'),(7,'5'),(7,'6'),
  (8,'1'),(8,'2'),(8,'3'),(8,'4'),(8,'5'),(8,'6'),
  (9,'1'),(9,'2'),(9,'3'),(9,'4'),(9,'5'),(9,'6'),
  (10,'1'),(10,'2'),(10,'3'),(10,'4'),(10,'5'),(10,'6'),
  (11,'1'),(11,'2'),(11,'3'),(11,'4'),(11,'5'),(11,'6'),
  (12,'1'),(12,'2'),(12,'3'),(12,'4'),(12,'5'),(12,'6'),
  (13,'1'),(13,'2'),(13,'3'),(13,'4'),(13,'5'),(13,'6'),
  (14,'1'),(14,'2'),(14,'3'),(14,'4'),(14,'5'),(14,'6'),
  (15,'1'),(15,'2'),(15,'3'),(15,'4'),(15,'5'),(15,'6'),
  (16,'1'),(16,'2'),(16,'3'),(16,'4'),(16,'5'),(16,'6'),
  (17,'1'),(17,'2'),(17,'3'),(17,'4'),(17,'5'),(17,'6'),
  (18,'1'),(18,'2'),(18,'3'),(18,'4'),(18,'5'),(18,'6'),
  (19,'1'),(19,'2'),(19,'3'),(19,'4'),(19,'5'),(19,'6'),
  (20,'1'),(20,'2'),(20,'3'),(20,'4'),(20,'5'),(20,'6'),
  (21,'1'),(21,'2'),(21,'3'),(21,'4'),(21,'5'),(21,'6'),
  (22,'1'),(22,'2'),(22,'3'),(22,'4'),(22,'5'),(22,'6'),
  (23,'1'),(23,'2'),(23,'3'),(23,'4'),(23,'5'),(23,'6'),
  (24,'1'),(24,'2'),(24,'3'),(24,'4'),(24,'5'),(24,'6'),
  (25,'1'),(25,'2'),(25,'3'),(25,'4'),(25,'5'),(25,'6'),
  (26,'1'),(26,'2'),(26,'3'),(26,'4'),(26,'5'),(26,'6'),
  (27,'1'),(27,'2'),(27,'3'),(27,'4'),(27,'5'),(27,'6'),
  (28,'1'),(28,'2'),(28,'3'),(28,'4'),(28,'5'),(28,'6'),
  (29,'1'),(29,'2'),(29,'3'),(29,'4'),(29,'5'),(29,'6'),
  (30,'1'),(30,'2'),(30,'3'),(30,'4'),(30,'5'),(30,'6'),
  (31,'1'),(31,'2'),(31,'3'),(31,'4'),(31,'5'),(31,'6'),
  (32,'1'),(32,'2'),(32,'3'),(32,'4'),(32,'5'),(32,'6'),
  (33,'1'),(33,'2'),(33,'3'),(33,'4'),(33,'5'),(33,'6'),
  (34,'1'),(34,'2'),(34,'3'),(34,'4'),(34,'5'),(34,'6'),
  (35,'1'),(35,'2'),(35,'3'),(35,'4'),(35,'5'),(35,'6'),
  (36,'1'),(36,'2'),(36,'3'),(36,'4'),(36,'5'),(36,'6'),
  (37,'1'),(37,'2'),(37,'3'),(37,'4'),(37,'5'),(37,'6'),
  (38,'1'),(38,'2'),(38,'3'),(38,'4'),(38,'5'),(38,'6'),
  (39,'1'),(39,'2'),(39,'3'),(39,'4'),(39,'5'),(39,'6'),
  (40,'1'),(40,'2'),(40,'3'),(40,'4'),(40,'5'),(40,'6'),
  (41,'1'),(41,'2'),(41,'3'),(41,'4'),(41,'5'),(41,'6'),
  (42,'1'),(42,'2'),(42,'3'),(42,'4'),(42,'5'),(42,'6'),
  (43,'1'),(43,'2'),(43,'3'),(43,'4'),(43,'5'),(43,'6'),
  (44,'1'),(44,'2'),(44,'3'),(44,'4'),(44,'5'),(44,'6'),
  (45,'1'),(45,'2'),(45,'3'),(45,'4'),(45,'5'),(45,'6'),
  (46,'1'),(46,'2'),(46,'3'),(46,'4'),(46,'5'),(46,'6'),
  (47,'1'),(47,'2'),(47,'3'),(47,'4'),(47,'5'),(47,'6'),
  (48,'1'),(48,'2'),(48,'3'),(48,'4'),(48,'5'),(48,'6'),
  (49,'1'),(49,'2'),(49,'3'),(49,'4'),(49,'5'),(49,'6'),
  (50,'1'),(50,'2'),(50,'3'),(50,'4'),(50,'5'),(50,'6'),
  (51,'1'),(51,'2'),(51,'3'),(51,'4'),(51,'5'),(51,'6'),
  (52,'1'),(52,'2'),(52,'3'),(52,'4'),(52,'5'),(52,'6'),
  (53,'1'),(53,'2'),(53,'3'),(53,'4'),(53,'5'),(53,'6'),
  (54,'1'),(54,'2'),(54,'3'),(54,'4'),(54,'5'),(54,'6'),
  (55,'1'),(55,'2'),(55,'3'),(55,'4'),(55,'5'),(55,'6'),
  (56,'1'),(56,'2'),(56,'3'),(56,'4'),(56,'5'),(56,'6'),
  (57,'1'),(57,'2'),(57,'3'),(57,'4'),(57,'5'),(57,'6'),
  (58,'1'),(58,'2'),(58,'3'),(58,'4'),(58,'5'),(58,'6'),
  (59,'1'),(59,'2'),(59,'3'),(59,'4'),(59,'5'),(59,'6'),
  (60,'1'),(60,'2'),(60,'3'),(60,'4'),(60,'5'),(60,'6'),
  (61,'1'),(61,'2'),(61,'3'),(61,'4'),(61,'5'),(61,'6'),
  (62,'1'),(62,'2'),(62,'3'),(62,'4'),(62,'5'),(62,'6'),
  (63,'1'),(63,'2'),(63,'3'),(63,'4'),(63,'5'),(63,'6'),
  (64,'1'),(64,'2'),(64,'3'),(64,'4'),(64,'5'),(64,'6'),
  (65,'1'),(65,'2'),(65,'3'),(65,'4'),(65,'5'),(65,'6'),
  (66,'1'),(66,'2'),(66,'3'),(66,'4'),(66,'5'),(66,'6');

-- Insert bedspaces for Hall B (rooms 67-132, 6 beds each)
INSERT INTO bedspaces (room_id, bed_number) VALUES
  (67,'1'),(67,'2'),(67,'3'),(67,'4'),(67,'5'),(67,'6'),
  (68,'1'),(68,'2'),(68,'3'),(68,'4'),(68,'5'),(68,'6'),
  (69,'1'),(69,'2'),(69,'3'),(69,'4'),(69,'5'),(69,'6'),
  (70,'1'),(70,'2'),(70,'3'),(70,'4'),(70,'5'),(70,'6'),
  (71,'1'),(71,'2'),(71,'3'),(71,'4'),(71,'5'),(71,'6'),
  (72,'1'),(72,'2'),(72,'3'),(72,'4'),(72,'5'),(72,'6'),
  (73,'1'),(73,'2'),(73,'3'),(73,'4'),(73,'5'),(73,'6'),
  (74,'1'),(74,'2'),(74,'3'),(74,'4'),(74,'5'),(74,'6'),
  (75,'1'),(75,'2'),(75,'3'),(75,'4'),(75,'5'),(75,'6'),
  (76,'1'),(76,'2'),(76,'3'),(76,'4'),(76,'5'),(76,'6'),
  (77,'1'),(77,'2'),(77,'3'),(77,'4'),(77,'5'),(77,'6'),
  (78,'1'),(78,'2'),(78,'3'),(78,'4'),(78,'5'),(78,'6'),
  (79,'1'),(79,'2'),(79,'3'),(79,'4'),(79,'5'),(79,'6'),
  (80,'1'),(80,'2'),(80,'3'),(80,'4'),(80,'5'),(80,'6'),
  (81,'1'),(81,'2'),(81,'3'),(81,'4'),(81,'5'),(81,'6'),
  (82,'1'),(82,'2'),(82,'3'),(82,'4'),(82,'5'),(82,'6'),
  (83,'1'),(83,'2'),(83,'3'),(83,'4'),(83,'5'),(83,'6'),
  (84,'1'),(84,'2'),(84,'3'),(84,'4'),(84,'5'),(84,'6'),
  (85,'1'),(85,'2'),(85,'3'),(85,'4'),(85,'5'),(85,'6'),
  (86,'1'),(86,'2'),(86,'3'),(86,'4'),(86,'5'),(86,'6'),
  (87,'1'),(87,'2'),(87,'3'),(87,'4'),(87,'5'),(87,'6'),
  (88,'1'),(88,'2'),(88,'3'),(88,'4'),(88,'5'),(88,'6'),
  (89,'1'),(89,'2'),(89,'3'),(89,'4'),(89,'5'),(89,'6'),
  (90,'1'),(90,'2'),(90,'3'),(90,'4'),(90,'5'),(90,'6'),
  (91,'1'),(91,'2'),(91,'3'),(91,'4'),(91,'5'),(91,'6'),
  (92,'1'),(92,'2'),(92,'3'),(92,'4'),(92,'5'),(92,'6'),
  (93,'1'),(93,'2'),(93,'3'),(93,'4'),(93,'5'),(93,'6'),
  (94,'1'),(94,'2'),(94,'3'),(94,'4'),(94,'5'),(94,'6'),
  (95,'1'),(95,'2'),(95,'3'),(95,'4'),(95,'5'),(95,'6'),
  (96,'1'),(96,'2'),(96,'3'),(96,'4'),(96,'5'),(96,'6'),
  (97,'1'),(97,'2'),(97,'3'),(97,'4'),(97,'5'),(97,'6'),
  (98,'1'),(98,'2'),(98,'3'),(98,'4'),(98,'5'),(98,'6'),
  (99,'1'),(99,'2'),(99,'3'),(99,'4'),(99,'5'),(99,'6'),
  (100,'1'),(100,'2'),(100,'3'),(100,'4'),(100,'5'),(100,'6'),
  (101,'1'),(101,'2'),(101,'3'),(101,'4'),(101,'5'),(101,'6'),
  (102,'1'),(102,'2'),(102,'3'),(102,'4'),(102,'5'),(102,'6'),
  (103,'1'),(103,'2'),(103,'3'),(103,'4'),(103,'5'),(103,'6'),
  (104,'1'),(104,'2'),(104,'3'),(104,'4'),(104,'5'),(104,'6'),
  (105,'1'),(105,'2'),(105,'3'),(105,'4'),(105,'5'),(105,'6'),
  (106,'1'),(106,'2'),(106,'3'),(106,'4'),(106,'5'),(106,'6'),
  (107,'1'),(107,'2'),(107,'3'),(107,'4'),(107,'5'),(107,'6'),
  (108,'1'),(108,'2'),(108,'3'),(108,'4'),(108,'5'),(108,'6'),
  (109,'1'),(109,'2'),(109,'3'),(109,'4'),(109,'5'),(109,'6'),
  (110,'1'),(110,'2'),(110,'3'),(110,'4'),(110,'5'),(110,'6'),
  (111,'1'),(111,'2'),(111,'3'),(111,'4'),(111,'5'),(111,'6'),
  (112,'1'),(112,'2'),(112,'3'),(112,'4'),(112,'5'),(112,'6'),
  (113,'1'),(113,'2'),(113,'3'),(113,'4'),(113,'5'),(113,'6'),
  (114,'1'),(114,'2'),(114,'3'),(114,'4'),(114,'5'),(114,'6'),
  (115,'1'),(115,'2'),(115,'3'),(115,'4'),(115,'5'),(115,'6'),
  (116,'1'),(116,'2'),(116,'3'),(116,'4'),(116,'5'),(116,'6'),
  (117,'1'),(117,'2'),(117,'3'),(117,'4'),(117,'5'),(117,'6'),
  (118,'1'),(118,'2'),(118,'3'),(118,'4'),(118,'5'),(118,'6'),
  (119,'1'),(119,'2'),(119,'3'),(119,'4'),(119,'5'),(119,'6'),
  (120,'1'),(120,'2'),(120,'3'),(120,'4'),(120,'5'),(120,'6'),
  (121,'1'),(121,'2'),(121,'3'),(121,'4'),(121,'5'),(121,'6'),
  (122,'1'),(122,'2'),(122,'3'),(122,'4'),(122,'5'),(122,'6'),
  (123,'1'),(123,'2'),(123,'3'),(123,'4'),(123,'5'),(123,'6'),
  (124,'1'),(124,'2'),(124,'3'),(124,'4'),(124,'5'),(124,'6'),
  (125,'1'),(125,'2'),(125,'3'),(125,'4'),(125,'5'),(125,'6'),
  (126,'1'),(126,'2'),(126,'3'),(126,'4'),(126,'5'),(126,'6'),
  (127,'1'),(127,'2'),(127,'3'),(127,'4'),(127,'5'),(127,'6'),
  (128,'1'),(128,'2'),(128,'3'),(128,'4'),(128,'5'),(128,'6'),
  (129,'1'),(129,'2'),(129,'3'),(129,'4'),(129,'5'),(129,'6'),
  (130,'1'),(130,'2'),(130,'3'),(130,'4'),(130,'5'),(130,'6'),
  (131,'1'),(131,'2'),(131,'3'),(131,'4'),(131,'5'),(131,'6'),
  (132,'1'),(132,'2'),(132,'3'),(132,'4'),(132,'5'),(132,'6');

-- Insert bedspaces for Hall E (rooms 133-252, 4 beds each)
INSERT INTO bedspaces (room_id, bed_number) VALUES
  (133,'1'),(133,'2'),(133,'3'),(133,'4'),
  (134,'1'),(134,'2'),(134,'3'),(134,'4'),
  (135,'1'),(135,'2'),(135,'3'),(135,'4'),
  (136,'1'),(136,'2'),(136,'3'),(136,'4'),
  (137,'1'),(137,'2'),(137,'3'),(137,'4'),
  (138,'1'),(138,'2'),(138,'3'),(138,'4'),
  (139,'1'),(139,'2'),(139,'3'),(139,'4'),
  (140,'1'),(140,'2'),(140,'3'),(140,'4'),
  (141,'1'),(141,'2'),(141,'3'),(141,'4'),
  (142,'1'),(142,'2'),(142,'3'),(142,'4'),
  (143,'1'),(143,'2'),(143,'3'),(143,'4'),
  (144,'1'),(144,'2'),(144,'3'),(144,'4'),
  (145,'1'),(145,'2'),(145,'3'),(145,'4'),
  (146,'1'),(146,'2'),(146,'3'),(146,'4'),
  (147,'1'),(147,'2'),(147,'3'),(147,'4'),
  (148,'1'),(148,'2'),(148,'3'),(148,'4'),
  (149,'1'),(149,'2'),(149,'3'),(149,'4'),
  (150,'1'),(150,'2'),(150,'3'),(150,'4'),
  (151,'1'),(151,'2'),(151,'3'),(151,'4'),
  (152,'1'),(152,'2'),(152,'3'),(152,'4'),
  (153,'1'),(153,'2'),(153,'3'),(153,'4'),
  (154,'1'),(154,'2'),(154,'3'),(154,'4'),
  (155,'1'),(155,'2'),(155,'3'),(155,'4'),
  (156,'1'),(156,'2'),(156,'3'),(156,'4'),
  (157,'1'),(157,'2'),(157,'3'),(157,'4'),
  (158,'1'),(158,'2'),(158,'3'),(158,'4'),
  (159,'1'),(159,'2'),(159,'3'),(159,'4'),
  (160,'1'),(160,'2'),(160,'3'),(160,'4'),
  (161,'1'),(161,'2'),(161,'3'),(161,'4'),
  (162,'1'),(162,'2'),(162,'3'),(162,'4'),
  (163,'1'),(163,'2'),(163,'3'),(163,'4'),
  (164,'1'),(164,'2'),(164,'3'),(164,'4'),
  (165,'1'),(165,'2'),(165,'3'),(165,'4'),
  (166,'1'),(166,'2'),(166,'3'),(166,'4'),
  (167,'1'),(167,'2'),(167,'3'),(167,'4'),
  (168,'1'),(168,'2'),(168,'3'),(168,'4'),
  (169,'1'),(169,'2'),(169,'3'),(169,'4'),
  (170,'1'),(170,'2'),(170,'3'),(170,'4'),
  (171,'1'),(171,'2'),(171,'3'),(171,'4'),
  (172,'1'),(172,'2'),(172,'3'),(172,'4'),
  (173,'1'),(173,'2'),(173,'3'),(173,'4'),
  (174,'1'),(174,'2'),(174,'3'),(174,'4'),
  (175,'1'),(175,'2'),(175,'3'),(175,'4'),
  (176,'1'),(176,'2'),(176,'3'),(176,'4'),
  (177,'1'),(177,'2'),(177,'3'),(177,'4'),
  (178,'1'),(178,'2'),(178,'3'),(178,'4'),
  (179,'1'),(179,'2'),(179,'3'),(179,'4'),
  (180,'1'),(180,'2'),(180,'3'),(180,'4'),
  (181,'1'),(181,'2'),(181,'3'),(181,'4'),
  (182,'1'),(182,'2'),(182,'3'),(182,'4'),
  (183,'1'),(183,'2'),(183,'3'),(183,'4'),
  (184,'1'),(184,'2'),(184,'3'),(184,'4'),
  (185,'1'),(185,'2'),(185,'3'),(185,'4'),
  (186,'1'),(186,'2'),(186,'3'),(186,'4'),
  (187,'1'),(187,'2'),(187,'3'),(187,'4'),
  (188,'1'),(188,'2'),(188,'3'),(188,'4'),
  (189,'1'),(189,'2'),(189,'3'),(189,'4'),
  (190,'1'),(190,'2'),(190,'3'),(190,'4'),
  (191,'1'),(191,'2'),(191,'3'),(191,'4'),
  (192,'1'),(192,'2'),(192,'3'),(192,'4'),
  (193,'1'),(193,'2'),(193,'3'),(193,'4'),
  (194,'1'),(194,'2'),(194,'3'),(194,'4'),
  (195,'1'),(195,'2'),(195,'3'),(195,'4'),
  (196,'1'),(196,'2'),(196,'3'),(196,'4'),
  (197,'1'),(197,'2'),(197,'3'),(197,'4'),
  (198,'1'),(198,'2'),(198,'3'),(198,'4'),
  (199,'1'),(199,'2'),(199,'3'),(199,'4'),
  (200,'1'),(200,'2'),(200,'3'),(200,'4'),
  (201,'1'),(201,'2'),(201,'3'),(201,'4'),
  (202,'1'),(202,'2'),(202,'3'),(202,'4'),
  (203,'1'),(203,'2'),(203,'3'),(203,'4'),
  (204,'1'),(204,'2'),(204,'3'),(204,'4'),
  (205,'1'),(205,'2'),(205,'3'),(205,'4'),
  (206,'1'),(206,'2'),(206,'3'),(206,'4'),
  (207,'1'),(207,'2'),(207,'3'),(207,'4'),
  (208,'1'),(208,'2'),(208,'3'),(208,'4'),
  (209,'1'),(209,'2'),(209,'3'),(209,'4'),
  (210,'1'),(210,'2'),(210,'3'),(210,'4'),
  (211,'1'),(211,'2'),(211,'3'),(211,'4'),
  (212,'1'),(212,'2'),(212,'3'),(212,'4'),
  (213,'1'),(213,'2'),(213,'3'),(213,'4'),
  (214,'1'),(214,'2'),(214,'3'),(214,'4'),
  (215,'1'),(215,'2'),(215,'3'),(215,'4'),
  (216,'1'),(216,'2'),(216,'3'),(216,'4'),
  (217,'1'),(217,'2'),(217,'3'),(217,'4'),
  (218,'1'),(218,'2'),(218,'3'),(218,'4'),
  (219,'1'),(219,'2'),(219,'3'),(219,'4'),
  (220,'1'),(220,'2'),(220,'3'),(220,'4'),
  (221,'1'),(221,'2'),(221,'3'),(221,'4'),
  (222,'1'),(222,'2'),(222,'3'),(222,'4'),
  (223,'1'),(223,'2'),(223,'3'),(223,'4'),
  (224,'1'),(224,'2'),(224,'3'),(224,'4'),
  (225,'1'),(225,'2'),(225,'3'),(225,'4'),
  (226,'1'),(226,'2'),(226,'3'),(226,'4'),
  (227,'1'),(227,'2'),(227,'3'),(227,'4'),
  (228,'1'),(228,'2'),(228,'3'),(228,'4'),
  (229,'1'),(229,'2'),(229,'3'),(229,'4'),
  (230,'1'),(230,'2'),(230,'3'),(230,'4'),
  (231,'1'),(231,'2'),(231,'3'),(231,'4'),
  (232,'1'),(232,'2'),(232,'3'),(232,'4'),
  (233,'1'),(233,'2'),(233,'3'),(233,'4'),
  (234,'1'),(234,'2'),(234,'3'),(234,'4'),
  (235,'1'),(235,'2'),(235,'3'),(235,'4'),
  (236,'1'),(236,'2'),(236,'3'),(236,'4'),
  (237,'1'),(237,'2'),(237,'3'),(237,'4'),
  (238,'1'),(238,'2'),(238,'3'),(238,'4'),
  (239,'1'),(239,'2'),(239,'3'),(239,'4'),
  (240,'1'),(240,'2'),(240,'3'),(240,'4'),
  (241,'1'),(241,'2'),(241,'3'),(241,'4'),
  (242,'1'),(242,'2'),(242,'3'),(242,'4'),
  (243,'1'),(243,'2'),(243,'3'),(243,'4'),
  (244,'1'),(244,'2'),(244,'3'),(244,'4'),
  (245,'1'),(245,'2'),(245,'3'),(245,'4'),
  (246,'1'),(246,'2'),(246,'3'),(246,'4'),
  (247,'1'),(247,'2'),(247,'3'),(247,'4'),
  (248,'1'),(248,'2'),(248,'3'),(248,'4'),
  (249,'1'),(249,'2'),(249,'3'),(249,'4'),
  (250,'1'),(250,'2'),(250,'3'),(250,'4'),
  (251,'1'),(251,'2'),(251,'3'),(251,'4'),
  (252,'1'),(252,'2'),(252,'3'),(252,'4');

-- Insert bedspaces for Hall C1 (rooms 253-296, 6 beds each)
INSERT INTO bedspaces (room_id, bed_number) VALUES
  (253,'1'),(253,'2'),(253,'3'),(253,'4'),(253,'5'),(253,'6'),
  (254,'1'),(254,'2'),(254,'3'),(254,'4'),(254,'5'),(254,'6'),
  (255,'1'),(255,'2'),(255,'3'),(255,'4'),(255,'5'),(255,'6'),
  (256,'1'),(256,'2'),(256,'3'),(256,'4'),(256,'5'),(256,'6'),
  (257,'1'),(257,'2'),(257,'3'),(257,'4'),(257,'5'),(257,'6'),
  (258,'1'),(258,'2'),(258,'3'),(258,'4'),(258,'5'),(258,'6'),
  (259,'1'),(259,'2'),(259,'3'),(259,'4'),(259,'5'),(259,'6'),
  (260,'1'),(260,'2'),(260,'3'),(260,'4'),(260,'5'),(260,'6'),
  (261,'1'),(261,'2'),(261,'3'),(261,'4'),(261,'5'),(261,'6'),
  (262,'1'),(262,'2'),(262,'3'),(262,'4'),(262,'5'),(262,'6'),
  (263,'1'),(263,'2'),(263,'3'),(263,'4'),(263,'5'),(263,'6'),
  (264,'1'),(264,'2'),(264,'3'),(264,'4'),(264,'5'),(264,'6'),
  (265,'1'),(265,'2'),(265,'3'),(265,'4'),(265,'5'),(265,'6'),
  (266,'1'),(266,'2'),(266,'3'),(266,'4'),(266,'5'),(266,'6'),
  (267,'1'),(267,'2'),(267,'3'),(267,'4'),(267,'5'),(267,'6'),
  (268,'1'),(268,'2'),(268,'3'),(268,'4'),(268,'5'),(268,'6'),
  (269,'1'),(269,'2'),(269,'3'),(269,'4'),(269,'5'),(269,'6'),
  (270,'1'),(270,'2'),(270,'3'),(270,'4'),(270,'5'),(270,'6'),
  (271,'1'),(271,'2'),(271,'3'),(271,'4'),(271,'5'),(271,'6'),
  (272,'1'),(272,'2'),(272,'3'),(272,'4'),(272,'5'),(272,'6'),
  (273,'1'),(273,'2'),(273,'3'),(273,'4'),(273,'5'),(273,'6'),
  (274,'1'),(274,'2'),(274,'3'),(274,'4'),(274,'5'),(274,'6'),
  (275,'1'),(275,'2'),(275,'3'),(275,'4'),(275,'5'),(275,'6'),
  (276,'1'),(276,'2'),(276,'3'),(276,'4'),(276,'5'),(276,'6'),
  (277,'1'),(277,'2'),(277,'3'),(277,'4'),(277,'5'),(277,'6'),
  (278,'1'),(278,'2'),(278,'3'),(278,'4'),(278,'5'),(278,'6'),
  (279,'1'),(279,'2'),(279,'3'),(279,'4'),(279,'5'),(279,'6'),
  (280,'1'),(280,'2'),(280,'3'),(280,'4'),(280,'5'),(280,'6'),
  (281,'1'),(281,'2'),(281,'3'),(281,'4'),(281,'5'),(281,'6'),
  (282,'1'),(282,'2'),(282,'3'),(282,'4'),(282,'5'),(282,'6'),
  (283,'1'),(283,'2'),(283,'3'),(283,'4'),(283,'5'),(283,'6'),
  (284,'1'),(284,'2'),(284,'3'),(284,'4'),(284,'5'),(284,'6'),
  (285,'1'),(285,'2'),(285,'3'),(285,'4'),(285,'5'),(285,'6'),
  (286,'1'),(286,'2'),(286,'3'),(286,'4'),(286,'5'),(286,'6'),
  (287,'1'),(287,'2'),(287,'3'),(287,'4'),(287,'5'),(287,'6'),
  (288,'1'),(288,'2'),(288,'3'),(288,'4'),(288,'5'),(288,'6'),
  (289,'1'),(289,'2'),(289,'3'),(289,'4'),(289,'5'),(289,'6'),
  (290,'1'),(290,'2'),(290,'3'),(290,'4'),(290,'5'),(290,'6'),
  (291,'1'),(291,'2'),(291,'3'),(291,'4'),(291,'5'),(291,'6'),
  (292,'1'),(292,'2'),(292,'3'),(292,'4'),(292,'5'),(292,'6'),
  (293,'1'),(293,'2'),(293,'3'),(293,'4'),(293,'5'),(293,'6'),
  (294,'1'),(294,'2'),(294,'3'),(294,'4'),(294,'5'),(294,'6'),
  (295,'1'),(295,'2'),(295,'3'),(295,'4'),(295,'5'),(295,'6'),
  (296,'1'),(296,'2'),(296,'3'),(296,'4'),(296,'5'),(296,'6');

-- Insert bedspaces for Hall C2 (rooms 297-318, 6 beds each)
INSERT INTO bedspaces (room_id, bed_number) VALUES
  (297,'1'),(297,'2'),(297,'3'),(297,'4'),(297,'5'),(297,'6'),
  (298,'1'),(298,'2'),(298,'3'),(298,'4'),(298,'5'),(298,'6'),
  (299,'1'),(299,'2'),(299,'3'),(299,'4'),(299,'5'),(299,'6'),
  (300,'1'),(300,'2'),(300,'3'),(300,'4'),(300,'5'),(300,'6'),
  (301,'1'),(301,'2'),(301,'3'),(301,'4'),(301,'5'),(301,'6'),
  (302,'1'),(302,'2'),(302,'3'),(302,'4'),(302,'5'),(302,'6'),
  (303,'1'),(303,'2'),(303,'3'),(303,'4'),(303,'5'),(303,'6'),
  (304,'1'),(304,'2'),(304,'3'),(304,'4'),(304,'5'),(304,'6'),
  (305,'1'),(305,'2'),(305,'3'),(305,'4'),(305,'5'),(305,'6'),
  (306,'1'),(306,'2'),(306,'3'),(306,'4'),(306,'5'),(306,'6'),
  (307,'1'),(307,'2'),(307,'3'),(307,'4'),(307,'5'),(307,'6'),
  (308,'1'),(308,'2'),(308,'3'),(308,'4'),(308,'5'),(308,'6'),
  (309,'1'),(309,'2'),(309,'3'),(309,'4'),(309,'5'),(309,'6'),
  (310,'1'),(310,'2'),(310,'3'),(310,'4'),(310,'5'),(310,'6'),
  (311,'1'),(311,'2'),(311,'3'),(311,'4'),(311,'5'),(311,'6'),
  (312,'1'),(312,'2'),(312,'3'),(312,'4'),(312,'5'),(312,'6'),
  (313,'1'),(313,'2'),(313,'3'),(313,'4'),(313,'5'),(313,'6'),
  (314,'1'),(314,'2'),(314,'3'),(314,'4'),(314,'5'),(314,'6'),
  (315,'1'),(315,'2'),(315,'3'),(315,'4'),(315,'5'),(315,'6'),
  (316,'1'),(316,'2'),(316,'3'),(316,'4'),(316,'5'),(316,'6'),
  (317,'1'),(317,'2'),(317,'3'),(317,'4'),(317,'5'),(317,'6'),
  (318,'1'),(318,'2'),(318,'3'),(318,'4'),(318,'5'),(318,'6');

-- Insert bedspaces for Hall D (rooms 319-394, 4 beds each)
INSERT INTO bedspaces (room_id, bed_number) VALUES
  (319,'1'),(319,'2'),(319,'3'),(319,'4'),
  (320,'1'),(320,'2'),(320,'3'),(320,'4'),
  (321,'1'),(321,'2'),(321,'3'),(321,'4'),
  (322,'1'),(322,'2'),(322,'3'),(322,'4'),
  (323,'1'),(323,'2'),(323,'3'),(323,'4'),
  (324,'1'),(324,'2'),(324,'3'),(324,'4'),
  (325,'1'),(325,'2'),(325,'3'),(325,'4'),
  (326,'1'),(326,'2'),(326,'3'),(326,'4'),
  (327,'1'),(327,'2'),(327,'3'),(327,'4'),
  (328,'1'),(328,'2'),(328,'3'),(328,'4'),
  (329,'1'),(329,'2'),(329,'3'),(329,'4'),
  (330,'1'),(330,'2'),(330,'3'),(330,'4'),
  (331,'1'),(331,'2'),(331,'3'),(331,'4'),
  (332,'1'),(332,'2'),(332,'3'),(332,'4'),
  (333,'1'),(333,'2'),(333,'3'),(333,'4'),
  (334,'1'),(334,'2'),(334,'3'),(334,'4'),
  (335,'1'),(335,'2'),(335,'3'),(335,'4'),
  (336,'1'),(336,'2'),(336,'3'),(336,'4'),
  (337,'1'),(337,'2'),(337,'3'),(337,'4'),
  (338,'1'),(338,'2'),(338,'3'),(338,'4'),
  (339,'1'),(339,'2'),(339,'3'),(339,'4'),
  (340,'1'),(340,'2'),(340,'3'),(340,'4'),
  (341,'1'),(341,'2'),(341,'3'),(341,'4'),
  (342,'1'),(342,'2'),(342,'3'),(342,'4'),
  (343,'1'),(343,'2'),(343,'3'),(343,'4'),
  (344,'1'),(344,'2'),(344,'3'),(344,'4'),
  (345,'1'),(345,'2'),(345,'3'),(345,'4'),
  (346,'1'),(346,'2'),(346,'3'),(346,'4'),
  (347,'1'),(347,'2'),(347,'3'),(347,'4'),
  (348,'1'),(348,'2'),(348,'3'),(348,'4'),
  (349,'1'),(349,'2'),(349,'3'),(349,'4'),
  (350,'1'),(350,'2'),(350,'3'),(350,'4'),
  (351,'1'),(351,'2'),(351,'3'),(351,'4'),
  (352,'1'),(352,'2'),(352,'3'),(352,'4'),
  (353,'1'),(353,'2'),(353,'3'),(353,'4'),
  (354,'1'),(354,'2'),(354,'3'),(354,'4'),
  (355,'1'),(355,'2'),(355,'3'),(355,'4'),
  (356,'1'),(356,'2'),(356,'3'),(356,'4'),
  (357,'1'),(357,'2'),(357,'3'),(357,'4'),
  (358,'1'),(358,'2'),(358,'3'),(358,'4'),
  (359,'1'),(359,'2'),(359,'3'),(359,'4'),
  (360,'1'),(360,'2'),(360,'3'),(360,'4'),
  (361,'1'),(361,'2'),(361,'3'),(361,'4'),
  (362,'1'),(362,'2'),(362,'3'),(362,'4'),
  (363,'1'),(363,'2'),(363,'3'),(363,'4'),
  (364,'1'),(364,'2'),(364,'3'),(364,'4'),
  (365,'1'),(365,'2'),(365,'3'),(365,'4'),
  (366,'1'),(366,'2'),(366,'3'),(366,'4'),
  (367,'1'),(367,'2'),(367,'3'),(367,'4'),
  (368,'1'),(368,'2'),(368,'3'),(368,'4'),
  (369,'1'),(369,'2'),(369,'3'),(369,'4'),
  (370,'1'),(370,'2'),(370,'3'),(370,'4'),
  (371,'1'),(371,'2'),(371,'3'),(371,'4'),
  (372,'1'),(372,'2'),(372,'3'),(372,'4'),
  (373,'1'),(373,'2'),(373,'3'),(373,'4'),
  (374,'1'),(374,'2'),(374,'3'),(374,'4'),
  (375,'1'),(375,'2'),(375,'3'),(375,'4'),
  (376,'1'),(376,'2'),(376,'3'),(376,'4'),
  (377,'1'),(377,'2'),(377,'3'),(377,'4'),
  (378,'1'),(378,'2'),(378,'3'),(378,'4'),
  (379,'1'),(379,'2'),(379,'3'),(379,'4'),
  (380,'1'),(380,'2'),(380,'3'),(380,'4'),
  (381,'1'),(381,'2'),(381,'3'),(381,'4'),
  (382,'1'),(382,'2'),(382,'3'),(382,'4'),
  (383,'1'),(383,'2'),(383,'3'),(383,'4'),
  (384,'1'),(384,'2'),(384,'3'),(384,'4'),
  (385,'1'),(385,'2'),(385,'3'),(385,'4'),
  (386,'1'),(386,'2'),(386,'3'),(386,'4'),
  (387,'1'),(387,'2'),(387,'3'),(387,'4'),
  (388,'1'),(388,'2'),(388,'3'),(388,'4'),
  (389,'1'),(389,'2'),(389,'3'),(389,'4'),
  (390,'1'),(390,'2'),(390,'3'),(390,'4'),
  (391,'1'),(391,'2'),(391,'3'),(391,'4'),
  (392,'1'),(392,'2'),(392,'3'),(392,'4'),
  (393,'1'),(393,'2'),(393,'3'),(393,'4'),
  (394,'1'),(394,'2'),(394,'3'),(394,'4');

-- Demo Students
INSERT INTO students (full_name, email, phone, matric_number, gender, password_hash) VALUES
  ('John Doe', 'john.doe@student.uni.edu', '+1234567890', 'MAT/2020/001', 'male', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'),
  ('Jane Smith', 'jane.smith@student.uni.edu', '+1234567891', 'MAT/2020/002', 'female', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'),
  ('Alice Johnson', 'alice.johnson@student.uni.edu', '+1234567892', 'MAT/2021/003', 'female', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'),
  ('Bob Wilson', 'bob.wilson@student.uni.edu', '+1234567893', 'MAT/2021/004', 'male', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'),
  ('Emma Davis', 'emma.davis@student.uni.edu', '+1234567894', 'MAT/2022/005', 'female', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');

-- Demo Admin
INSERT INTO admin (username, email, phone, password_hash, first_name, last_name, role) VALUES
  ('admin', 'admin@uni.edu', '+1234567899', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'System', 'Administrator', 'super_admin');

COMMIT;