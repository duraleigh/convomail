import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/tokens.dart';
import 'destinations.dart';
import 'settings.dart';
import 'settings_navigation.dart';

/// First-run onboarding (plan M12) is shown only by the real app: main
/// overrides this to true. Tests and benches keep the shell as is.
final showOnboardingProvider = Provider<bool>((ref) => false);

/// Welcome screen shown while there are no accounts and onboarding has not
/// been dismissed. Two exits: add an account, or explore the empty shell.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        // Scrolls when the window is too short to show it all.
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/logo.png', key: const ValueKey('app-logo'), width: 64, height: 64, filterQuality: FilterQuality.medium),
                  const SizedBox(height: AppSpace.xl),
                  Text('Welcome to Précis', style: text.displaySmall),
                  const SizedBox(height: AppSpace.sm),
                  Text('Mail organized by the people you talk to, not by folders.', style: text.titleMedium!.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpace.xl),
                  const _Point(icon: Icons.people_alt_outlined, title: 'One conversation per person', body: 'Everything you and a contact have sent each other, in one chat-style thread. Groups you define get their own row.'),
                  const _Point(
                    icon: Icons.rss_feed_rounded,
                    title: 'Receipts and promotions stay out of the way',
                    body: 'Mail that is not from a person lands in Feed when it is worth knowing and in Noise when it is not. Only people count toward your badge unless you say otherwise.',
                  ),
                  const _Point(icon: Icons.today_outlined, title: 'Your day on one page', body: 'Today shows your calendar, who you are still waiting on, and what you put off until later.'),
                  const _Point(icon: Icons.shield_outlined, title: 'Local first', body: 'Mail syncs straight from your provider over IMAP. Passwords live in Windows Credential Manager; nothing goes through a relay server.'),
                  const SizedBox(height: AppSpace.xl),
                  Row(
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('onboarding-add-account'),
                        onPressed: () {
                          ref.read(settingsSectionProvider.notifier).select(SettingsSection.accounts);
                          ref.read(settingsAddAccountRequestProvider.notifier).set(true);
                          ref.read(destinationProvider.notifier).select(Destination.settings);
                          ref.read(settingsProvider.notifier).setOnboardingDone(true);
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add your account'),
                      ),
                      const SizedBox(width: AppSpace.md),
                      TextButton(key: const ValueKey('onboarding-skip'), onPressed: () => ref.read(settingsProvider.notifier).setOnboardingDone(true), child: const Text('Explore first')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                Text(body, style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
