import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../l10n/l10n.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _appVersion = '1.0.0 (1)';
  static const _buildDate = 'May 25, 2025 10:30';
  static const _websiteUrl = 'https://openmodscan.com';
  static const _emailUrl = 'mailto:support@openmodscan.com';
  static const _docsUrl = 'https://docs.openmodscan.com';
  static const _issuesUrl = 'https://github.com/openmodscan/mobile/issues';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          // App icon + name
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icon/icon.png',
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: l10n.appBarName,
                    style: tt.titleLarge!.copyWith(color: cs.onSurface),
                  ),
                  TextSpan(
                    text: l10n.appBarNameSuffix,
                    style: tt.titleLarge!.copyWith(color: appColors.brandGreen),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Version $_appVersion',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 28),

          // Info card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _infoTile(
                  context,
                  Icons.info_outline,
                  l10n.aboutApplication,
                  l10n.appTitle,
                ),
                _divider(context),
                _infoTile(context, Icons.code, l10n.aboutVersion, _appVersion),
                _divider(context),
                _infoTile(
                  context,
                  Icons.calendar_today_outlined,
                  l10n.aboutBuildDate,
                  _buildDate,
                ),
                _divider(context),
                _infoTile(
                  context,
                  Icons.shield_outlined,
                  l10n.aboutLicense,
                  l10n.aboutLicenseMit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Links card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _linkTile(
                  context,
                  Icons.language,
                  l10n.aboutWebsite,
                  _websiteUrl,
                ),
                _divider(context),
                _linkTile(
                  context,
                  Icons.email_outlined,
                  l10n.aboutEmail,
                  _emailUrl,
                ),
                _divider(context),
                _linkTile(
                  context,
                  Icons.article_outlined,
                  l10n.aboutDocumentation,
                  _docsUrl,
                ),
                _divider(context),
                _linkTile(
                  context,
                  Icons.chat_bubble_outline,
                  l10n.aboutReportIssue,
                  _issuesUrl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Copyright
          Center(
            child: Text(
              l10n.aboutCopyright,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Divider(
    height: 1,
    indent: 56,
    color: Theme.of(context).dividerTheme.color,
  );

  Widget _infoTile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 16),
          Text(label, style: tt.bodyLarge),
          const Spacer(),
          Text(
            value,
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _linkTile(
    BuildContext context,
    IconData icon,
    String label,
    String url,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final displayUrl = url.startsWith('mailto:') ? url.substring(7) : url;
    return InkWell(
      onTap: () => _launch(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: tt.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    displayUrl,
                    style: TextStyle(color: cs.primary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 18, color: cs.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
