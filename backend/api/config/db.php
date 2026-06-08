<?php


declare(strict_types=1);

class DB
{
    private static ?PDO $instance = null;


    private const HOST = '127.0.0.1';
    private const PORT = '3306';
    private const NAME = 'hostel_management';
    private const USER = 'root';
    private const PASS = '';        
    
    
    public static function get(): PDO
    {
        if (self::$instance === null) {
            $dsn = sprintf(
                'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
                self::HOST, self::PORT, self::NAME
            );
            self::$instance = new PDO($dsn, self::USER, self::PASS, [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]);
        }
        return self::$instance;
    }

    // Prevent instantiation
    private function __construct() {}
    private function __clone()     {}
}