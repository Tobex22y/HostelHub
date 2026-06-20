<?php

class DB {
    private static ?PDO $instance = null;

    private const HOST = '127.0.0.1';
    private const DBNAME = 'hostel_management';
    private const USER = 'root';
    private const PASS = '';

    public static function get(): PDO {
        if (self::$instance === null) {
            $dsn = "mysql:host=" . self::HOST . ";dbname=" . self::DBNAME . ";charset=utf8mb4";

            self::$instance = new PDO($dsn, self::USER, self::PASS, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
            ]);
        }

        return self::$instance;
    }
}