<?php
declare(strict_types=1);

namespace Precis;

/**
 * Turns an email as Gmail hands it over into the plain words the assistant
 * is shown: the readable text, without the copied history underneath a
 * reply, without pictures or attachments, and cut to a fixed length.
 *
 * Nothing here is stored. The words exist for the length of one reading.
 */
final class Body
{
    /** How much of an email from a person is shown to the assistant, at most. */
    public const PERSON_CHARS = 6000;

    /** "The first part" of an email that is not from a person. */
    public const FEED_CHARS = 1500;

    /**
     * The readable text of a Gmail message (format=full).
     *
     * @param array<string, mixed> $message
     */
    public static function text(array $message): string
    {
        $plain = '';
        $html = '';
        self::walk($message['payload'] ?? [], $plain, $html);
        $plain = self::tidy($plain);
        if (mb_strlen($plain) >= 40 || $html === '') {
            return $plain;
        }
        $fromHtml = self::tidy(self::htmlToText($html));
        return mb_strlen($fromHtml) > mb_strlen($plain) ? $fromHtml : $plain;
    }

    /** @param array<string, mixed> $part */
    private static function walk(array $part, string &$plain, string &$html): void
    {
        $mime = strtolower((string) ($part['mimeType'] ?? ''));
        if (($part['filename'] ?? '') === '' && isset($part['body']['data']) && ($mime === 'text/plain' || $mime === 'text/html')) {
            $data = base64_decode(strtr((string) $part['body']['data'], '-_', '+/'), true);
            if (is_string($data) && $data !== '') {
                if (!mb_check_encoding($data, 'UTF-8')) {
                    $data = mb_convert_encoding($data, 'UTF-8', 'ISO-8859-1');
                }
                if ($mime === 'text/plain') {
                    $plain .= ($plain === '' ? '' : "\n") . $data;
                } else {
                    $html .= ($html === '' ? '' : "\n") . $data;
                }
            }
        }
        foreach ($part['parts'] ?? [] as $child) {
            if (is_array($child)) {
                self::walk($child, $plain, $html);
            }
        }
    }

    public static function htmlToText(string $html): string
    {
        $s = preg_replace('~<(style|script|head|title|svg)\b[^>]*>.*?</\1\s*>~is', ' ', $html) ?? $html;
        $s = preg_replace('~<!--.*?-->~s', ' ', $s) ?? $s;
        $s = preg_replace('~<(br|/p|/div|/tr|/li|/h[1-6]|/table|/blockquote)\b[^>]*>~i', "\n", $s) ?? $s;
        $s = preg_replace('~<li\b[^>]*>~i', "\n- ", $s) ?? $s;
        $s = preg_replace('~<[^>]+>~', ' ', $s) ?? $s;
        return html_entity_decode($s, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }

    /** Removes padding marketers hide in emails, long web addresses, and extra blank space. */
    public static function tidy(string $s): string
    {
        $s = str_replace(["\r\n", "\r"], "\n", $s);
        // Invisible padding: zero-width marks, soft hyphens, the "combining grapheme joiner".
        $s = preg_replace('~[\x{200B}-\x{200F}\x{2060}\x{FEFF}\x{00AD}\x{034F}\x{061C}\x{180E}]~u', '', $s) ?? $s;
        $s = str_replace("\u{00A0}", ' ', $s);
        // A long web address says nothing the assistant needs: keep where it goes.
        $s = preg_replace_callback('~<?(https?://[^\s<>"\')\]]{50,})>?~i', static function (array $m): string {
            $host = (string) parse_url($m[1], PHP_URL_HOST);
            return $host === '' ? '[link]' : "[link: $host]";
        }, $s) ?? $s;
        $s = preg_replace('~[ \t]+~', ' ', $s) ?? $s;
        $s = preg_replace('~ ?\n ?~', "\n", $s) ?? $s;
        $s = preg_replace('~\n{3,}~', "\n\n", $s) ?? $s;
        return trim($s);
    }

    /**
     * Only what this email's sender wrote this time: the copied history
     * under a reply is cut away. A forwarded email keeps what was forwarded,
     * because that is what the sender is passing on.
     */
    public static function newWords(string $text): string
    {
        $lines = explode("\n", $text);
        $n = count($lines);
        $cut = $n;
        for ($i = 0; $i < $n; $i++) {
            $line = trim($lines[$i]);
            $next = $i + 1 < $n ? trim($lines[$i + 1]) : '';
            if (preg_match('~^-{2,} ?Forwarded message ?-{2,}$|^Begin forwarded message:$~i', $line) === 1) {
                // Forwarded on purpose: everything from here on is kept.
                break;
            }
            if (
                preg_match('~^On .{6,200}\bwrote:$~is', $line) === 1
                || (preg_match('~^On .{6,200}$~i', $line) === 1 && preg_match('~\bwrote:$~i', $next) === 1 && mb_strlen($next) < 120)
                || preg_match('~^-{2,} ?Original Message ?-{2,}$~i', $line) === 1
                || (preg_match('~^From: .+~i', $line) === 1 && preg_match('~^(Sent|Date): ~i', $next) === 1)
                || (preg_match('~^_{10,}$~', $line) === 1 && preg_match('~^From: ~i', $next) === 1)
                || preg_match('~^Le .{6,200} a écrit ?:$|^Am .{6,200} schrieb .{1,120}:$|^El .{6,200} escribió:$~iu', $line) === 1
            ) {
                $cut = $i;
                break;
            }
            // A block of quoted lines that runs to the end of the email.
            if (str_starts_with($line, '>')) {
                $rest = true;
                for ($j = $i; $j < $n; $j++) {
                    $t = trim($lines[$j]);
                    if ($t !== '' && !str_starts_with($t, '>')) {
                        $rest = false;
                        break;
                    }
                }
                if ($rest) {
                    $cut = $i;
                    break;
                }
            }
        }
        $kept = trim(implode("\n", array_slice($lines, 0, $cut)));
        // A reply written entirely inside the quoted text has no words above
        // the cut; then the whole text is the best there is.
        return $kept === '' ? trim($text) : $kept;
    }

    /** Cuts to [$max] characters on a word, saying so. */
    public static function clip(string $s, int $max): string
    {
        if (mb_strlen($s) <= $max) {
            return $s;
        }
        $cut = mb_substr($s, 0, $max);
        $space = mb_strrpos($cut, ' ');
        if ($space !== false && $space > $max - 200) {
            $cut = mb_substr($cut, 0, $space);
        }
        return rtrim($cut) . "\n[the rest is not shown]";
    }

    /**
     * The headers of a Gmail message, lower-cased names, first value wins.
     *
     * @param array<string, mixed> $message
     * @return array<string, string>
     */
    public static function headers(array $message): array
    {
        $h = [];
        foreach ($message['payload']['headers'] ?? [] as $header) {
            $name = strtolower((string) ($header['name'] ?? ''));
            $h[$name] ??= (string) ($header['value'] ?? '');
        }
        return $h;
    }
}
