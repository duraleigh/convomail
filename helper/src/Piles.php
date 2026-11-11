<?php
declare(strict_types=1);

namespace Precis;

/** Feed or Noise for a sender that is not a person. Same as the app's piles.dart. */
final class Piles
{
    public const NOISE_CATEGORIES = [Classifier::PROMOTION => true, Classifier::SOCIAL => true];
    public const NEWSLETTER_OPENED_SHARE = 0.3;

    /**
     * The user's own choice always wins. Otherwise it goes by what the
     * sender mostly sends: mostly promotions and social notices is Noise,
     * mostly newsletters is Feed only when they get opened, the rest is Feed.
     *
     * @param array<string, array{total: int, unread: int}>|null $mail emails counted by category ('' for none)
     */
    public static function pileFor(?string $chosen, ?string $category, int $total, int $unread, ?array $mail = null): string
    {
        if ($chosen === 'feed' || $chosen === 'noise') {
            return $chosen;
        }
        $counts = $mail === null || $mail === [] ? [($category ?? '') => ['total' => $total, 'unread' => $unread]] : $mail;
        $all = 0;
        $noisy = 0;
        foreach ($counts as $cat => $c) {
            $all += (int) $c['total'];
            if (isset(self::NOISE_CATEGORIES[(string) $cat])) {
                $noisy += (int) $c['total'];
            }
        }
        if ($all === 0) {
            return isset(self::NOISE_CATEGORIES[(string) $category]) || $category === Classifier::NEWSLETTER ? 'noise' : 'feed';
        }
        if ($noisy * 2 > $all) {
            return 'noise';
        }
        $letters = $counts[Classifier::NEWSLETTER] ?? null;
        if ($letters !== null && (int) $letters['total'] * 2 > $all) {
            $opened = (int) $letters['total'] - (int) $letters['unread'];
            return $opened >= (int) $letters['total'] * self::NEWSLETTER_OPENED_SHARE ? 'feed' : 'noise';
        }
        return 'feed';
    }
}
