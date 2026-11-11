<?php
declare(strict_types=1);

namespace Precis;

use RuntimeException;

/** Web requests through curl. Only https, only to the hosts the helper is meant to reach. */
final class CurlHttp implements Http
{
    /** Hosts the helper may call. Nothing else is ever contacted. */
    public const ALLOWED_HOSTS = ['accounts.google.com', 'oauth2.googleapis.com', 'gmail.googleapis.com', 'www.googleapis.com'];

    public function __construct(private readonly int $timeout = 25, private readonly int $parallel = 8)
    {
    }

    public function request(string $method, string $url, array $headers = [], ?string $body = null): array
    {
        $ch = $this->handle($method, $url, $headers, $body);
        $out = curl_exec($ch);
        if ($out === false) {
            $err = curl_error($ch);
            curl_close($ch);
            throw new RuntimeException('The request did not go through: ' . $err);
        }
        $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        curl_close($ch);
        return ['status' => $status, 'body' => (string) $out];
    }

    public function getMany(array $urls, array $headers = []): array
    {
        $answers = [];
        foreach (array_chunk($urls, $this->parallel, true) as $chunk) {
            $multi = curl_multi_init();
            $handles = [];
            foreach ($chunk as $i => $url) {
                $handles[$i] = $this->handle('GET', $url, $headers, null);
                curl_multi_add_handle($multi, $handles[$i]);
            }
            do {
                $status = curl_multi_exec($multi, $running);
                if ($running) {
                    curl_multi_select($multi, 1.0);
                }
            } while ($running && $status === CURLM_OK);
            foreach ($handles as $i => $ch) {
                $body = curl_multi_getcontent($ch);
                $code = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
                $answers[$i] = ['status' => $code === 0 ? 599 : $code, 'body' => (string) $body];
                curl_multi_remove_handle($multi, $ch);
                curl_close($ch);
            }
            curl_multi_close($multi);
        }
        ksort($answers);
        return array_values($answers);
    }

    /** @return \CurlHandle */
    private function handle(string $method, string $url, array $headers, ?string $body)
    {
        $parts = parse_url($url);
        if (($parts['scheme'] ?? '') !== 'https' || !in_array($parts['host'] ?? '', self::ALLOWED_HOSTS, true)) {
            throw new RuntimeException('The helper does not call that address.');
        }
        $ch = curl_init($url);
        $list = [];
        foreach ($headers as $k => $v) {
            $list[] = "$k: $v";
        }
        curl_setopt_array($ch, [
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $list,
            CURLOPT_TIMEOUT => $this->timeout,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_PROTOCOLS => CURLPROTO_HTTPS,
            CURLOPT_ENCODING => '',
        ]);
        if ($body !== null) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
        }
        return $ch;
    }
}
