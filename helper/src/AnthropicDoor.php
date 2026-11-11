<?php
declare(strict_types=1);

namespace Precis;

use Psr\Http\Client\ClientInterface;
use Psr\Http\Message\RequestInterface;
use Psr\Http\Message\ResponseInterface;
use RuntimeException;

/**
 * The one way out to the assistant. Whatever asks, a request leaves the
 * helper only when it is https and going to Anthropic's own address.
 * Nothing else is ever contacted through here.
 */
final class AnthropicDoor implements ClientInterface
{
    public const HOST = 'api.anthropic.com';

    public function __construct(private readonly ClientInterface $inner)
    {
    }

    public function sendRequest(RequestInterface $request): ResponseInterface
    {
        $uri = $request->getUri();
        if (strtolower($uri->getScheme()) !== 'https' || strtolower($uri->getHost()) !== self::HOST || ($uri->getPort() !== null && $uri->getPort() !== 443)) {
            throw new RuntimeException('The helper does not call that address.');
        }
        return $this->inner->sendRequest($request);
    }
}
