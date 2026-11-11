<?php
declare(strict_types=1);

namespace Precis;

use Anthropic\Client;
use Anthropic\Core\Exceptions\APIConnectionException;
use Anthropic\Core\Exceptions\APIStatusException;
use Anthropic\Messages\JSONOutputFormat;
use Anthropic\Messages\OutputConfig;
use Psr\Http\Client\ClientInterface;

/**
 * The assistant: Claude, reached with the owner's own Anthropic developer
 * key through Anthropic's own library.
 *
 * Each reading is one request: standing instructions, one email, and the
 * shape the answer must have. Anthropic reports what the reading used, and
 * that is what the meter counts.
 */
final class Claude implements Assistant
{
    /** Room for the reader's own thinking plus a short answer. */
    private const MAX_TOKENS = 4000;

    private readonly Client $client;

    /**
     * @param ClientInterface|null $transport how requests leave the helper; the checks pass a stand-in
     */
    public function __construct(string $key, ?ClientInterface $transport = null, float $timeout = 60.0, int $retries = 2)
    {
        if (!class_exists(Client::class)) {
            throw new AssistantError('The assistant\'s library is not installed on the helper.');
        }
        $this->client = new Client(
            apiKey: $key,
            requestOptions: [
                'transporter' => new AnthropicDoor($transport ?? new \GuzzleHttp\Client(['timeout' => $timeout, 'connect_timeout' => 10, 'http_errors' => false, 'allow_redirects' => false])),
                'timeout' => $timeout,
                'maxRetries' => $retries,
            ],
            // The helper keeps its own count; nothing is sent to a tracing service.
            openTelemetry: false,
        );
    }

    public function read(string $model, string $instructions, string $email, array $shape): array
    {
        try {
            $message = $this->client->messages->create(
                maxTokens: self::MAX_TOKENS,
                messages: [['role' => 'user', 'content' => $email]],
                model: $model,
                // The instructions are the same for every email, so Anthropic
                // can keep them ready and charge a fraction for them.
                system: [['type' => 'text', 'text' => $instructions, 'cacheControl' => ['type' => 'ephemeral']]],
                // A short, exact reading: little thinking, a fixed shape.
                outputConfig: OutputConfig::with(effort: 'low', format: JSONOutputFormat::with(schema: $shape)),
            );
        } catch (APIStatusException $e) {
            throw self::explain($e);
        } catch (APIConnectionException $e) {
            throw new AssistantError('Anthropic could not be reached.', 'busy');
        }
        $usage = $message->usage;
        $out = [
            'data' => null,
            'refused' => $message->stopReason === 'refusal',
            'cut' => $message->stopReason === 'max_tokens',
            'model' => (string) $message->model,
            'in' => (int) $usage->inputTokens,
            'out' => (int) $usage->outputTokens,
            'cacheRead' => (int) ($usage->cacheReadInputTokens ?? 0),
            'cacheWrite' => (int) ($usage->cacheCreationInputTokens ?? 0),
        ];
        if ($out['refused']) {
            return $out;
        }
        foreach ($message->content as $block) {
            if ($block->type === 'text') {
                $data = json_decode((string) $block->text, true);
                if (is_array($data)) {
                    $out['data'] = $data;
                }
                break;
            }
        }
        return $out;
    }

    public function keyWorks(): bool
    {
        try {
            $this->client->models->retrieve('claude-haiku-5-5');
            return true;
        } catch (APIStatusException $e) {
            $err = self::explain($e);
            if ($err->kind === 'key') {
                return false;
            }
            throw $err;
        } catch (APIConnectionException $e) {
            throw new AssistantError('Anthropic could not be reached.', 'busy');
        }
    }

    /** Says what went wrong in the owner's words. Never includes an email's text. */
    private static function explain(APIStatusException $e): AssistantError
    {
        $status = (int) ($e->status ?? 0);
        $type = (string) ($e->getType() ?? '');
        $said = mb_strtolower((string) ($e->getAPIMessage() ?? ''));
        return match (true) {
            $status === 401 || $type === 'authentication_error' => new AssistantError('Anthropic did not accept the key.', 'key', $status),
            $type === 'billing_error' || $status === 402 || str_contains($said, 'credit balance') || str_contains($said, 'spend limit') => new AssistantError('The Anthropic account has no credit left, or reached its own spending limit.', 'credit', $status),
            $status === 403 || $type === 'permission_error' => new AssistantError('Anthropic does not let this key use that reader.', 'key', $status),
            $status === 429 || $status === 529 || $status >= 500 || $type === 'rate_limit_error' || $type === 'overloaded_error' => new AssistantError('Anthropic is busy. The helper will try again shortly.', 'busy', $status),
            default => new AssistantError('Anthropic refused a reading (' . $status . ($type === '' ? '' : ' ' . $type) . ').', 'other', $status),
        };
    }
}
