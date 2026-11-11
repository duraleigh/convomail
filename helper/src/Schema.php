<?php
declare(strict_types=1);

namespace Precis;

/**
 * The helper's tables, made and upgraded in numbered steps.
 *
 * What is kept: how each email is sorted and the few header facts sorting
 * needs, the user's own choices (moves, tags, rules, done, later,
 * reminders), the list of devices, and the sealed Google sign-in. The
 * mailbox itself is not kept: no email bodies, no attachments.
 *
 * From version 2 the assistant's reading of an email is kept too: its one
 * sentence, whether it needs the owner, what is asked and by when, and why.
 * The email's words are fetched, read and let go; they are never stored.
 */
final class Schema
{
    public const VERSION = 4;

    public static function migrate(Db $db): void
    {
        $pk = $db->driver === 'mysql' ? 'BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY' : 'INTEGER PRIMARY KEY AUTOINCREMENT';
        $tail = $db->driver === 'mysql' ? ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin' : '';
        $db->exec("CREATE TABLE IF NOT EXISTS {meta} (k VARCHAR(64) NOT NULL PRIMARY KEY, v TEXT NOT NULL)$tail");
        $have = (int) ($db->val('SELECT v FROM {meta} WHERE k = ?', ['schema']) ?? 0);
        if ($have >= self::VERSION) {
            return;
        }
        if ($have < 1) {
            foreach (self::v1($pk) as $sql) {
                $db->exec($sql . $tail);
            }
            foreach (self::v1Indexes() as $sql) {
                $db->exec($sql);
            }
            $db->run('INSERT INTO {counters} (name, n) VALUES (?, 0)', ['seq']);
        }
        if ($have < 2) {
            foreach (self::v2() as $sql) {
                $db->exec(str_contains($sql, 'CREATE TABLE') ? $sql . $tail : $sql);
            }
        }
        if ($have < 3) {
            // The owner's own sent mail is read too, to tell whether it asked
            // for something: whether it did is kept with its reading, and
            // sent mail already passed over is looked at again.
            $db->exec('ALTER TABLE {readings} ADD COLUMN asks INT NOT NULL DEFAULT 0');
            $db->run('UPDATE {emails} SET read_state = 0 WHERE is_from_me = 1');
        }
        if ($have < 4) {
            // Phones: where to send a phone its alerts, whether it may ring,
            // and when a PC last had Précis open in front of the owner.
            $db->exec('ALTER TABLE {devices} ADD COLUMN push_token VARCHAR(400) NULL');
            $db->exec('ALTER TABLE {devices} ADD COLUMN ring INT NOT NULL DEFAULT 1');
            $db->exec('ALTER TABLE {devices} ADD COLUMN front_at BIGINT NOT NULL DEFAULT 0');
            // What has already been alerted, so nothing rings twice.
            $db->exec('CREATE TABLE {alerts} (k VARCHAR(420) NOT NULL PRIMARY KEY, at BIGINT NOT NULL, cleared INT NOT NULL DEFAULT 0)' . $tail);
            // The addresses the owner sends from, each kept locked, for every device.
            $db->exec('CREATE TABLE {vault} (k VARCHAR(320) NOT NULL PRIMARY KEY, v ' . ($db->driver === 'mysql' ? 'MEDIUMTEXT' : 'TEXT') . ' NOT NULL, at BIGINT NOT NULL)' . $tail);
        }
        $db->upsert('meta', ['k' => 'schema'], ['v' => (string) self::VERSION]);
    }

    /** @return list<string> */
    private static function v1(string $pk): array
    {
        return [
            'CREATE TABLE {counters} (name VARCHAR(32) NOT NULL PRIMARY KEY, n BIGINT NOT NULL)',

            // One row per mailbox the helper reads. `tokens` is sealed.
            'CREATE TABLE {accounts} (
                id ' . $pk . ',
                email VARCHAR(191) NOT NULL,
                tokens TEXT NOT NULL,
                history_id VARCHAR(32) NULL,
                watch_expires BIGINT NOT NULL DEFAULT 0,
                backfill_page VARCHAR(255) NULL,
                backfill_done INT NOT NULL DEFAULT 0,
                backfill_read INT NOT NULL DEFAULT 0,
                last_checked BIGINT NOT NULL DEFAULT 0,
                last_notice BIGINT NOT NULL DEFAULT 0,
                last_error TEXT NULL,
                created BIGINT NOT NULL
            )',

            // Header facts of each email, and how it is sorted. No bodies.
            'CREATE TABLE {emails} (
                id ' . $pk . ',
                account_id BIGINT NOT NULL,
                gmail_id VARCHAR(32) NOT NULL,
                thread_id VARCHAR(32) NOT NULL DEFAULT \'\',
                message_id VARCHAR(400) NOT NULL DEFAULT \'\',
                in_reply_to VARCHAR(400) NOT NULL DEFAULT \'\',
                from_addr VARCHAR(191) NOT NULL DEFAULT \'\',
                from_key VARCHAR(191) NOT NULL DEFAULT \'\',
                from_name VARCHAR(255) NOT NULL DEFAULT \'\',
                rcpt TEXT NOT NULL,
                subject TEXT NOT NULL,
                snippet TEXT NOT NULL,
                at BIGINT NOT NULL DEFAULT 0,
                is_from_me INT NOT NULL DEFAULT 0,
                signals VARCHAR(255) NULL,
                provider_category VARCHAR(20) NULL,
                unread INT NOT NULL DEFAULT 0,
                gone INT NOT NULL DEFAULT 0,
                cls VARCHAR(8) NOT NULL DEFAULT \'\',
                cat VARCHAR(64) NULL
            )',

            // Who each of the user's own emails went to, so "you wrote to
            // this person" can be counted.
            'CREATE TABLE {rcpts} (
                email_id BIGINT NOT NULL,
                skey VARCHAR(191) NOT NULL,
                role VARCHAR(4) NOT NULL,
                name VARCHAR(255) NOT NULL DEFAULT \'\',
                PRIMARY KEY (email_id, skey, role)
            )',

            // Everything devices keep in step, as one stream. `seq` grows
            // with every write, so "what changed since N" is one question.
            'CREATE TABLE {items} (
                kind VARCHAR(12) NOT NULL,
                k VARCHAR(400) NOT NULL,
                data TEXT NOT NULL,
                deleted INT NOT NULL DEFAULT 0,
                seq BIGINT NOT NULL,
                origin BIGINT NULL,
                at BIGINT NOT NULL,
                PRIMARY KEY (kind, k)
            )',

            // What a device knew about a sender when it first sent its state
            // up: the counts older mail gave, which the helper never saw.
            'CREATE TABLE {sender_facts} (
                skey VARCHAR(191) NOT NULL PRIMARY KEY,
                seed TEXT NOT NULL,
                seed_at BIGINT NOT NULL
            )',

            // Message-IDs of mail the owner sent before the helper began
            // reading, so an answer to one is known to be an answer.
            'CREATE TABLE {my_ids} (message_id VARCHAR(400) NOT NULL PRIMARY KEY)',

            'CREATE TABLE {devices} (
                id ' . $pk . ',
                name VARCHAR(100) NOT NULL,
                kind VARCHAR(20) NOT NULL,
                token_hash VARCHAR(64) NOT NULL,
                created BIGINT NOT NULL,
                last_seen BIGINT NOT NULL DEFAULT 0,
                revoked INT NOT NULL DEFAULT 0
            )',

            'CREATE TABLE {pair_codes} (code_hash VARCHAR(64) NOT NULL PRIMARY KEY, expires BIGINT NOT NULL, used INT NOT NULL DEFAULT 0)',

            'CREATE TABLE {throttle} (k VARCHAR(80) NOT NULL PRIMARY KEY, n INT NOT NULL, until BIGINT NOT NULL)',

            'CREATE TABLE {log} (id ' . $pk . ', at BIGINT NOT NULL, level VARCHAR(8) NOT NULL, msg TEXT NOT NULL)',
        ];
    }

    /** @return list<string> */
    private static function v2(): array
    {
        return [
            // Whether the email is in the inbox, where it sits among Feed and
            // Noise, and where it is in the queue for the assistant:
            // 0 not looked at yet, 1 waiting to be read, 2 read, 3 not to be
            // read, 4 failed and will be tried again, 5 given up on.
            'ALTER TABLE {emails} ADD COLUMN inbox INT NOT NULL DEFAULT 0',
            "ALTER TABLE {emails} ADD COLUMN pile VARCHAR(8) NOT NULL DEFAULT ''",
            'ALTER TABLE {emails} ADD COLUMN read_state INT NOT NULL DEFAULT 0',
            'ALTER TABLE {emails} ADD COLUMN read_tries INT NOT NULL DEFAULT 0',
            'ALTER TABLE {emails} ADD COLUMN read_after BIGINT NOT NULL DEFAULT 0',
            'CREATE INDEX {emails}_read ON {emails} (read_state, at)',
            'CREATE INDEX {emails}_thread ON {emails} (thread_id)',

            // What the assistant said about an email. Never the email's words.
            'CREATE TABLE {readings} (
                email_id BIGINT NOT NULL PRIMARY KEY,
                model VARCHAR(40) NOT NULL,
                line TEXT NOT NULL,
                focus INT NOT NULL DEFAULT 0,
                ask TEXT NOT NULL,
                due BIGINT NULL,
                place VARCHAR(8) NOT NULL DEFAULT \'\',
                why TEXT NOT NULL,
                answered INT NOT NULL DEFAULT 0,
                at BIGINT NOT NULL
            )',

            // What the assistant has cost, by day, reader and purpose.
            // `micro` is millionths of a dollar.
            'CREATE TABLE {spend} (
                day VARCHAR(10) NOT NULL,
                model VARCHAR(40) NOT NULL,
                purpose VARCHAR(12) NOT NULL,
                calls INT NOT NULL DEFAULT 0,
                tin BIGINT NOT NULL DEFAULT 0,
                tout BIGINT NOT NULL DEFAULT 0,
                tcr BIGINT NOT NULL DEFAULT 0,
                tcw BIGINT NOT NULL DEFAULT 0,
                micro BIGINT NOT NULL DEFAULT 0,
                PRIMARY KEY (day, model, purpose)
            )',

            // The test week: the same emails read by more than one reader,
            // so their cost and their answers can be compared.
            'CREATE TABLE {trial} (
                email_id BIGINT NOT NULL,
                model VARCHAR(40) NOT NULL,
                result TEXT NOT NULL,
                tin INT NOT NULL DEFAULT 0,
                tout INT NOT NULL DEFAULT 0,
                tcr INT NOT NULL DEFAULT 0,
                tcw INT NOT NULL DEFAULT 0,
                micro BIGINT NOT NULL DEFAULT 0,
                ms INT NOT NULL DEFAULT 0,
                error TEXT NULL,
                PRIMARY KEY (email_id, model)
            )',
        ];
    }

    /** @return list<string> */
    private static function v1Indexes(): array
    {
        return [
            'CREATE UNIQUE INDEX {emails}_gmail ON {emails} (account_id, gmail_id)',
            'CREATE INDEX {emails}_mid ON {emails} (message_id)',
            'CREATE INDEX {emails}_from ON {emails} (from_key, at)',
            'CREATE INDEX {emails}_at ON {emails} (at)',
            'CREATE INDEX {items}_seq ON {items} (seq)',
            'CREATE INDEX {rcpts}_skey ON {rcpts} (skey)',
        ];
    }
}
