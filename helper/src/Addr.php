<?php
declare(strict_types=1);

namespace Precis;

/** Reading names and addresses out of From, To and Cc header lines. */
final class Addr
{
    /**
     * Every mailbox in a header value.
     *
     * @return list<array{name: string, address: string}>
     */
    public static function parseList(?string $value): array
    {
        if ($value === null || trim($value) === '') {
            return [];
        }
        $out = [];
        foreach (self::split(Classifier::clean($value)) as $piece) {
            $one = self::parseOne($piece);
            if ($one !== null) {
                $out[] = $one;
            }
        }
        return $out;
    }

    /** @return array{name: string, address: string}|null */
    public static function parseOne(string $piece): ?array
    {
        // "Group name: a@x, b@y;" keeps its members only: the name before the
        // colon and the closing semicolon are dropped.
        $piece = rtrim(trim($piece), "; 	");
        if (preg_match('~^[^<>"@:]*:(.*)$~us', $piece, $g) === 1) {
            $piece = trim($g[1]);
        }
        if ($piece === '') {
            return null;
        }
        if (preg_match('~^(.*)<([^<>]*)>[^<>]*$~us', $piece, $m) === 1) {
            $address = trim($m[2]);
            $name = trim($m[1]);
        } else {
            $address = $piece;
            $name = '';
        }
        // Comments in brackets are not part of the address.
        $address = trim((string) preg_replace('~\([^)]*\)~u', '', $address));
        if (!str_contains($address, '@') || preg_match('~\s~u', $address) === 1) {
            return null;
        }
        if (strlen($name) >= 2 && $name[0] === '"' && str_ends_with($name, '"')) {
            $name = stripcslashes(substr($name, 1, -1));
        }
        return ['name' => trim(self::decodeWords($name)), 'address' => Classifier::lower($address)];
    }

    /** Splits on commas that are not inside quotes or angle brackets. */
    private static function split(string $value): array
    {
        $out = [];
        $current = '';
        $quoted = false;
        $angle = false;
        $len = strlen($value);
        for ($i = 0; $i < $len; $i++) {
            $c = $value[$i];
            if ($quoted) {
                if ($c === '\\' && $i + 1 < $len) {
                    $current .= $c . $value[++$i];
                    continue;
                }
                if ($c === '"') {
                    $quoted = false;
                }
            } elseif ($c === '"') {
                $quoted = true;
            } elseif ($c === '<') {
                $angle = true;
            } elseif ($c === '>') {
                $angle = false;
            } elseif ($c === ',' && !$angle) {
                $out[] = $current;
                $current = '';
                continue;
            }
            $current .= $c;
        }
        $out[] = $current;
        return $out;
    }

    /** Turns `=?UTF-8?B?...?=` words into plain text. */
    public static function decodeWords(string $s): string
    {
        if (!str_contains($s, '=?')) {
            return $s;
        }
        $out = null;
        if (function_exists('iconv_mime_decode')) {
            $decoded = @iconv_mime_decode($s, ICONV_MIME_DECODE_CONTINUE_ON_ERROR, 'UTF-8');
            if ($decoded !== false) {
                $out = $decoded;
            }
        }
        $out ??= (string) mb_decode_mimeheader($s);
        return Classifier::clean($out);
    }
}
