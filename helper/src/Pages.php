<?php
declare(strict_types=1);

namespace Precis;

/** The helper's own few web pages: setting up, signing in, and the owner's page. */
final class Pages
{
    public static function e(?string $s): string
    {
        return htmlspecialchars((string) $s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }

    public static function layout(string $title, string $body): string
    {
        $t = self::e($title);
        return <<<HTML
            <!doctype html>
            <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="robots" content="noindex, nofollow"><title>$t</title>
            <style>
            :root{color-scheme:light dark;--bg:#f6f5fb;--card:#fff;--ink:#1b1b23;--soft:#5d5c6b;--line:#dcdbe7;--accent:#4a4bd6;--bad:#b3261e;--ok:#1e7b3c}
            @media (prefers-color-scheme:dark){:root{--bg:#131318;--card:#1c1c24;--ink:#e8e7f2;--soft:#a5a4b5;--line:#33323f;--accent:#b9baff;--bad:#ffb4ab;--ok:#8fd9a4}}
            *{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.5 system-ui,"Segoe UI",Roboto,sans-serif}
            main{max-width:760px;margin:0 auto;padding:28px 16px 60px}h1{font-size:26px;margin:0 0 4px}h2{font-size:18px;margin:0 0 10px}
            .sub{color:var(--soft);margin:0 0 22px}.card{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:18px 20px;margin:0 0 16px}
            label{display:block;font-weight:600;margin:12px 0 4px}input[type=text],input[type=password],select{width:100%;padding:10px 12px;border:1px solid var(--line);border-radius:10px;background:transparent;color:inherit;font:inherit}
            button{font:inherit;font-weight:600;padding:9px 16px;border-radius:999px;border:0;background:var(--accent);color:var(--bg);cursor:pointer;margin:14px 8px 0 0}
            button.quiet{background:transparent;color:var(--accent);border:1px solid var(--line)}button.bad{background:transparent;color:var(--bad);border:1px solid var(--line)}
            .note{color:var(--soft);font-size:14px}.bad{color:var(--bad)}.ok{color:var(--ok)}code,.code{font-family:ui-monospace,Consolas,monospace;font-size:14px;word-break:break-all}
            .big{font:700 34px/1.2 ui-monospace,Consolas,monospace;letter-spacing:4px;margin:8px 0}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:7px 8px 7px 0;border-top:1px solid var(--line);vertical-align:top;font-size:15px}
            th{color:var(--soft);font-weight:600;border-top:0}form.inline{display:inline}.flash{border-radius:12px;padding:10px 14px;margin:0 0 16px;border:1px solid var(--line)}
            ol{padding-left:20px;margin:6px 0}li{margin:3px 0}
            </style></head><body><main>$body</main></body></html>
            HTML;
    }

    public static function message(string $title, string $text): string
    {
        return self::layout($title, '<h1>' . self::e($title) . '</h1><p class="sub">' . self::e($text) . '</p>');
    }

    public static function setup(string $key, ?string $error, array $old): string
    {
        $e = [self::class, 'e'];
        $err = $error === null ? '' : '<div class="flash bad">' . $e($error) . '</div>';
        $v = static fn (string $k, string $d = ''): string => self::e((string) ($old[$k] ?? $d));
        return self::layout('Set up the Précis helper', <<<HTML
            <h1>Set up the Précis helper</h1>
            <p class="sub">One time only. The helper needs a place to keep its notes, and a passphrase so only you can open this page.</p>
            $err
            <form method="post" action="/setup" autocomplete="off">
            <input type="hidden" name="key" value="{$e($key)}">
            <div class="card"><h2>Where the helper keeps its notes</h2>
            <p class="note">From Hostinger: Databases, then the database you made for the helper.</p>
            <label for="db_name">Database name</label><input id="db_name" type="text" name="db_name" value="{$v('db_name')}" required>
            <label for="db_user">Database username</label><input id="db_user" type="text" name="db_user" value="{$v('db_user')}" required>
            <label for="db_pass">Database password</label><input id="db_pass" type="password" name="db_pass" required>
            <label for="db_host">Database server</label><input id="db_host" type="text" name="db_host" value="{$v('db_host', 'localhost')}" required>
            </div>
            <div class="card"><h2>Your passphrase for this page</h2>
            <p class="note">At least 12 characters. A few words you will remember is best. It is not your Google or Hostinger password.</p>
            <label for="pass">Passphrase</label><input id="pass" type="password" name="pass" minlength="12" required autocomplete="new-password">
            <label for="pass2">The same passphrase again</label><input id="pass2" type="password" name="pass2" minlength="12" required autocomplete="new-password">
            </div>
            <button type="submit">Finish setup</button>
            </form>
            HTML);
    }

    public static function signIn(?string $error): string
    {
        $err = $error === null ? '' : '<div class="flash bad">' . self::e($error) . '</div>';
        return self::layout('Précis helper', <<<HTML
            <h1>Précis helper</h1><p class="sub">This page is for the owner.</p>$err
            <form method="post" action="/signin" class="card">
            <label for="pass">Passphrase</label><input id="pass" type="password" name="pass" required autofocus autocomplete="current-password">
            <button type="submit">Open</button></form>
            HTML);
    }

    /**
     * @param array<string, mixed> $s what the page shows
     */
    public static function owner(array $s): string
    {
        $e = [self::class, 'e'];
        $csrf = '<input type="hidden" name="csrf" value="' . $e($s['csrf']) . '">';
        $flash = ($s['flash'] ?? '') === '' ? '' : '<div class="flash ' . (($s['flashBad'] ?? false) ? 'bad' : 'ok') . '">' . $e($s['flash']) . '</div>';
        $code = ($s['code'] ?? '') === '' ? '' : '<div class="card"><h2>Code for the new device</h2><div class="big">' . $e($s['code']) . '</div><p class="note">Type it into Précis on that device within 10 minutes. It works once.</p></div>';
        $ago = static function (int $at, int $now): string {
            if ($at <= 0) {
                return 'never';
            }
            $d = max(0, $now - $at);
            return match (true) {
                $d < 90 => 'just now',
                $d < 5400 => (int) round($d / 60) . ' minutes ago',
                $d < 129600 => (int) round($d / 3600) . ' hours ago',
                default => (int) round($d / 86400) . ' days ago',
            };
        };
        $now = (int) $s['now'];
        $base = $e($s['base']);

        // ---- Google
        $google = '';
        if ($s['accounts'] === []) {
            $google .= '<p>No mailbox is connected yet.</p>';
        }
        foreach ($s['accounts'] as $a) {
            $state = $a['last_error'] !== null ? '<span class="bad">' . $e((string) $a['last_error']) . '</span>' : '<span class="ok">Working</span>';
            $first = (int) $a['backfill_done'] === 1 ? 'finished (' . (int) $a['backfill_read'] . ' emails)' : 'in progress (' . (int) $a['backfill_read'] . ' emails so far)';
            $notice = (int) $a['watch_expires'] > $now ? 'on' . ((int) $a['last_notice'] > 0 ? ', last one ' . $ago((int) $a['last_notice'], $now) : ', none received yet') : 'off (the helper looks every minute instead)';
            $google .= '<table><tr><th>Mailbox</th><td>' . $e((string) $a['email']) . '</td></tr>'
                . '<tr><th>State</th><td>' . $state . '</td></tr>'
                . '<tr><th>Last looked</th><td>' . $ago((int) $a['last_checked'], $now) . '</td></tr>'
                . '<tr><th>First read of 30 days</th><td>' . $first . '</td></tr>'
                . '<tr><th>Instant notice</th><td>' . $notice . '</td></tr></table>'
                . '<form method="post" action="/google/disconnect" class="inline">' . $csrf . '<input type="hidden" name="id" value="' . (int) $a['id'] . '"><button class="bad" type="submit">Disconnect this mailbox</button></form>';
        }
        $clientState = $s['hasClient'] ? '<span class="ok">Saved.</span> Paste again only to replace it.' : 'Not saved yet.';
        $connect = $s['hasClient'] ? '<form method="post" action="/google/start" class="inline">' . $csrf . '<button type="submit">' . ($s['accounts'] === [] ? 'Connect Google' : 'Connect Google again') . '</button></form>' : '';
        $topic = $e((string) $s['topic']);
        $hook = $e($s['base'] . '/hook/gmail?k=' . $s['hookSecret']);

        // ---- devices
        $rows = '';
        foreach ($s['devices'] as $d) {
            if ((int) $d['revoked'] === 1) {
                continue;
            }
            $kind = ['windows' => 'Windows PC', 'android' => 'Android phone'][(string) $d['kind']] ?? 'Device';
            $rows .= '<tr><td>' . $e((string) $d['name']) . '</td><td>' . $kind . ((string) $d['kind'] === 'android' ? ((int) ($d['alerts'] ?? 0) === 1 ? ((int) ($d['ring'] ?? 1) === 1 ? ' · rings' : ' · silent') : ' · no alerts yet') : '') . '</td><td>' . $ago((int) $d['last_seen'], $now) . '</td><td>'
                . '<form method="post" action="/devices/signout" class="inline">' . $csrf . '<input type="hidden" name="id" value="' . (int) $d['id'] . '"><button class="bad" type="submit" style="margin:0;padding:4px 12px">Sign out</button></form></td></tr>';
        }
        $devices = $rows === '' ? '<p>No device has joined yet.</p>' : '<table><tr><th>Name</th><th>Kind</th><th>Last seen</th><th></th></tr>' . $rows . '</table>';

        // ---- what Google allows, and alerts to phones
        $g = $s['grants'];
        $allowed = $g['mail'] && $g['calendar'] && $g['contacts']
            ? '<p class="note"><span class="ok">Google allows everything devices need:</span> mail in full, calendar (read only), contacts (read only).</p>'
            : ($s['accounts'] === [] ? '' : '<p class="note"><span class="bad">One more Allow is needed.</span> A phone or second PC that joins by code needs the helper to hold full mail access, your calendar (read only) and your contacts (read only). Press <b>Connect Google again</b> below and leave every box ticked. Today Google allows: mail in full ' . ($g['mail'] ? 'yes' : 'no') . ' · calendar ' . ($g['calendar'] ? 'yes' : 'no') . ' · contacts ' . ($g['contacts'] ? 'yes' : 'no') . '.</p>');
        $p = $s['push'];
        $push = $p['hasKey']
            ? '<p><span class="ok">Set up.</span> Project ' . $e((string) $p['project']) . '. The file is kept locked and is never shown again.</p>'
                . '<form method="post" action="/push/test" class="inline">' . $csrf . '<button type="submit">Send a test alert</button></form> '
                . '<form method="post" action="/push/forget" class="inline">' . $csrf . '<button class="quiet" type="submit">Turn alerts off</button></form>'
            : '<p class="note">Android only lets an app be told something while it is closed through Google’s alert service (Firebase). Paste the whole contents of the service account file from your Firebase project here. It is checked with Google and kept locked.</p>';
        $push .= '<p>' . ($p['hasApp'] ? '<span class="ok">The phone app’s settings file is saved.</span>' : '<span class="bad">The phone app’s settings file is not saved yet.</span> Paste the whole contents of google-services.json below.') . '</p>'
            . '<form method="post" action="/push/app" autocomplete="off">' . $csrf
            . '<label for="papp">App settings file, google-services.json (paste all of it)</label><textarea id="papp" name="app" rows="4" autocomplete="off" spellcheck="false" style="width:100%;padding:10px 12px;border:1px solid var(--line);border-radius:10px;background:transparent;color:inherit;font:inherit"></textarea>'
            . '<button type="submit">' . ($p['hasApp'] ? 'Replace the app settings file' : 'Save the app settings file') . '</button></form>';
        $sd = $s['sending'];
        $sending = $sd['count'] === 0
            ? '<p class="note">Nothing kept yet. Précis on a PC that already sends mail hands them over by itself the next time it is open.</p>'
            : '<p><span class="ok">' . $sd['count'] . ' address' . ($sd['count'] === 1 ? '' : 'es') . ' kept</span>, ' . $sd['passwords'] . ' with the password for a mail server of its own. They are kept locked and are never shown here. Every device that joins gets them, so it can send from the same addresses.</p>'
                . '<form method="post" action="/sending/forget" class="inline">' . $csrf . '<button class="quiet" type="submit">Forget them</button></form>';
        $push .= '<form method="post" action="/push/key" autocomplete="off">' . $csrf
            . '<label for="pacc">Service account file (paste all of it)</label><textarea id="pacc" name="account" rows="4" autocomplete="off" spellcheck="false" style="width:100%;padding:10px 12px;border:1px solid var(--line);border-radius:10px;background:transparent;color:inherit;font:inherit"></textarea>'
            . '<button type="submit">' . ($p['hasKey'] ? 'Replace the file' : 'Save the file') . '</button></form>';

        // ---- the assistant
        $a = $s['assistant'];
        $money = static fn (int $micro): string => Prices::dollars($micro);
        if (!$a['hasKey']) {
            $assistantState = 'No key yet. Nothing is sent to the assistant.';
        } elseif ($a['problem'] !== '') {
            $assistantState = '<span class="bad">Paused.</span> ' . $e((string) $a['problem']);
        } elseif ($a['on']) {
            $assistantState = '<span class="ok">On.</span> Reading with ' . $e((string) $a['modelName']) . '.';
        } else {
            $assistantState = 'Off. Nothing is sent to it.';
        }
        $readerOptions = '<option value="">Choose…</option>';
        foreach ($s['readers'] as $id => $reader) {
            $readerOptions .= '<option value="' . $e((string) $id) . '"' . ($a['model'] === $id ? ' selected' : '') . '>' . $e((string) $reader['name']) . '</option>';
        }
        $ceilingValue = $e(rtrim(rtrim(number_format($a['ceiling'] / 1_000_000, 2, '.', ''), '0'), '.'));
        $assistant = '<table><tr><th>State</th><td>' . $assistantState . '</td></tr>'
            . '<tr><th>Spent this month</th><td>' . $money((int) $a['month']) . ' of a ' . $money((int) $a['ceiling']) . ' ceiling · today ' . $money((int) $a['today']) . '</td></tr>'
            . '<tr><th>Emails read</th><td>' . (int) $a['read'] . ' · waiting to be read: ' . (int) $a['waiting'] . ' · need you now: ' . (int) $a['focus'] . '</td></tr></table>';
        if ($a['hasKey']) {
            $assistant .= '<p class="note"><span class="ok">A key is saved, locked.</span> It is never shown again. Paste a new one only to replace it.</p>';
        } else {
            $assistant .= '<p class="note">The assistant is Claude, reached with your own Anthropic developer key. The key is checked with Anthropic (which costs nothing) and kept locked. It is never shown again, to you or to any device.</p>';
        }
        $assistant .= '<form method="post" action="/assistant/key" autocomplete="off">' . $csrf
            . '<label for="akey">Anthropic key</label><input id="akey" type="password" name="key" autocomplete="off" placeholder="sk-ant-…">'
            . '<button type="submit">' . ($a['hasKey'] ? 'Replace the key' : 'Save the key') . '</button></form>';
        if ($a['hasKey']) {
            $assistant .= '<form method="post" action="/assistant/settings">' . $csrf
                . '<label for="areader">Reader</label><select id="areader" name="model">' . $readerOptions . '</select>'
                . '<label for="aceil">Ceiling, in dollars a month</label><input id="aceil" type="text" name="ceiling" value="' . $ceilingValue . '">'
                . '<p class="note">When a month\'s cost reaches the ceiling, the assistant pauses and says so. Mail keeps being sorted by the fixed rules.</p>'
                . '<button type="submit">Save</button></form>'
                . '<form method="post" action="/assistant/switch" class="inline">' . $csrf . '<input type="hidden" name="on" value="' . ($a['on'] ? '0' : '1') . '"><button type="submit"' . ($a['on'] ? ' class="bad"' : '') . '>' . ($a['on'] ? 'Turn the assistant off' : 'Turn the assistant on') . '</button></form> '
                . '<form method="post" action="/assistant/forget" class="inline">' . $csrf . '<button class="quiet" type="submit">Remove the key</button></form>';
        }

        // ---- timer and log
        $timer = (int) $s['clockLast'] > 0 && $now - (int) $s['clockLast'] < 300 ? '<span class="ok">Running.</span> Last ran ' . $ago((int) $s['clockLast'], $now) . '.' : '<span class="bad">Not running.</span> ' . ((int) $s['clockLast'] > 0 ? 'Last ran ' . $ago((int) $s['clockLast'], $now) . '.' : 'It has never run.');
        $log = '';
        foreach ($s['log'] as $l) {
            $log .= '<tr><td class="note" style="white-space:nowrap">' . $e(gmdate('M j, H:i', (int) $l['at'])) . ' UTC</td><td class="' . ((string) $l['level'] === 'error' ? 'bad' : '') . '">' . $e((string) $l['msg']) . '</td></tr>';
        }
        $log = $log === '' ? '<p class="note">Nothing yet.</p>' : '<table>' . $log . '</table>';
        $counts = $s['counts'];

        return self::layout('Précis helper', <<<HTML
            <h1>Précis helper</h1>
            <p class="sub">Reads your mail around the clock, sorts it, and keeps your devices in step. Version {$e($s['version'])}.</p>
            $flash$code
            <div class="card"><h2>Google</h2>$google $allowed $connect
            <p class="note" style="margin-top:14px">Emails the helper holds facts for: {$counts['emails']} · in Chats: {$counts['people']} · not from a person: {$counts['feeds']} · senders: {$counts['senders']}</p></div>

            <div class="card"><h2>Sign-in client</h2>
            <p class="note">From your Google project: a "Web application" client. $clientState</p>
            <p class="note">The redirect address to give Google:<br><span class="code">$base/google/callback</span></p>
            <form method="post" action="/google/client" autocomplete="off">$csrf
            <label for="cid">Client ID</label><input id="cid" type="text" name="client_id" value="{$e($s['clientId'])}">
            <label for="csec">Client secret</label><input id="csec" type="password" name="client_secret" autocomplete="off">
            <button type="submit">Save</button></form></div>

            <div class="card"><h2>Instant notice</h2>
            <p class="note">Optional. With it, Google tells the helper about new mail within seconds. Without it, the helper looks every minute.</p>
            <p class="note">The address to give Google for the notice (keep it private):<br><span class="code">$hook</span></p>
            <form method="post" action="/google/topic">$csrf
            <label for="topic">Topic name from Google</label><input id="topic" type="text" name="topic" value="$topic" placeholder="projects/your-project/topics/precis-mail">
            <button type="submit">Save</button></form></div>

            <div class="card"><h2>The assistant</h2>$assistant</div>

            <div class="card"><h2>Alerts to phones</h2>$push</div>

            <div class="card"><h2>Addresses you send from</h2>$sending</div>

            <div class="card"><h2>Your devices</h2>$devices
            <form method="post" action="/devices/code">$csrf<button type="submit">Add a device</button></form></div>

            <div class="card"><h2>The every-minute timer</h2><p>$timer</p></div>

            <div class="card"><h2>Recent notes</h2>$log</div>

            <form method="post" action="/signout">$csrf<button class="quiet" type="submit">Close this page</button></form>
            HTML);
    }
}
