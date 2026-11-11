<?php
declare(strict_types=1);

namespace Precis;

use PDO;
use PDOStatement;

/**
 * A thin layer over PDO. Works on MySQL (the live helper) and SQLite (the
 * checks run on a PC), so every statement here is written to suit both.
 */
final class Db
{
    public readonly string $driver;

    public function __construct(private readonly PDO $pdo, public readonly string $prefix = 'px_')
    {
        $this->driver = (string) $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        if ($this->driver === 'mysql') {
            $pdo->exec("SET NAMES utf8mb4");
            $pdo->exec("SET time_zone = '+00:00'");
        } else {
            $pdo->exec('PRAGMA foreign_keys = ON');
        }
    }

    public static function connect(array $config): self
    {
        $pdo = new PDO((string) $config['dsn'], $config['user'] ?? null, $config['pass'] ?? null, [PDO::ATTR_EMULATE_PREPARES => false]);
        return new self($pdo, (string) ($config['prefix'] ?? 'px_'));
    }

    public static function memory(): self
    {
        return new self(new PDO('sqlite::memory:'));
    }

    /** Table name with the prefix. */
    public function t(string $name): string
    {
        return $this->prefix . $name;
    }

    /** Runs a statement. `{name}` in the SQL becomes the prefixed table. */
    public function run(string $sql, array $params = []): PDOStatement
    {
        $sql = preg_replace_callback('/\{(\w+)\}/', fn (array $m): string => $this->t($m[1]), $sql);
        $st = $this->pdo->prepare($sql);
        foreach (array_values($params) as $i => $v) {
            $type = match (true) {
                is_int($v) => PDO::PARAM_INT,
                is_bool($v) => PDO::PARAM_INT,
                $v === null => PDO::PARAM_NULL,
                default => PDO::PARAM_STR,
            };
            $st->bindValue($i + 1, is_bool($v) ? (int) $v : $v, $type);
        }
        $st->execute();
        return $st;
    }

    /** @return list<array<string, mixed>> */
    public function all(string $sql, array $params = []): array
    {
        return $this->run($sql, $params)->fetchAll();
    }

    /** @return array<string, mixed>|null */
    public function one(string $sql, array $params = []): ?array
    {
        $row = $this->run($sql, $params)->fetch();
        return $row === false ? null : $row;
    }

    public function val(string $sql, array $params = []): mixed
    {
        $row = $this->run($sql, $params)->fetch(PDO::FETCH_NUM);
        return $row === false ? null : $row[0];
    }

    /** Inserts a row and returns its id. */
    public function insert(string $table, array $data): int
    {
        $cols = array_keys($data);
        $this->run(
            'INSERT INTO {' . $table . '} (' . implode(', ', $cols) . ') VALUES (' . implode(', ', array_fill(0, count($cols), '?')) . ')',
            array_values($data),
        );
        return (int) $this->pdo->lastInsertId();
    }

    /**
     * Inserts, or updates the row that has the same [$keys].
     *
     * Done as update-then-insert so it reads the same on both databases.
     */
    public function upsert(string $table, array $keys, array $data): void
    {
        $where = implode(' AND ', array_map(static fn (string $k): string => "$k = ?", array_keys($keys)));
        if ($data !== []) {
            $set = implode(', ', array_map(static fn (string $k): string => "$k = ?", array_keys($data)));
            $n = $this->run("UPDATE {{$table}} SET $set WHERE $where", [...array_values($data), ...array_values($keys)])->rowCount();
            if ($n > 0) {
                return;
            }
        }
        // rowCount is 0 on MySQL when nothing changed, so look before inserting.
        if ($this->val("SELECT 1 FROM {{$table}} WHERE $where", array_values($keys)) !== null) {
            return;
        }
        $this->insert($table, [...$keys, ...$data]);
    }

    public function transaction(callable $work): mixed
    {
        if ($this->pdo->inTransaction()) {
            return $work();
        }
        $this->pdo->beginTransaction();
        try {
            $out = $work();
            $this->pdo->commit();
            return $out;
        } catch (\Throwable $e) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $e;
        }
    }

    public function exec(string $sql): void
    {
        $this->pdo->exec(preg_replace_callback('/\{(\w+)\}/', fn (array $m): string => $this->t($m[1]), $sql));
    }

    /** `?, ?, ?` for an IN list. */
    public static function marks(int $n): string
    {
        return implode(', ', array_fill(0, max(1, $n), '?'));
    }
}
