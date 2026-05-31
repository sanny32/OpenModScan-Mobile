import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../services/build_info_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const _websiteUrl = 'https://github.com/sanny32/OpenModScan-Mobile';
  static const _emailUrl = 'mailto:mail@ananev.org';
  static const _issuesUrl =
      'https://github.com/sanny32/OpenModScan-Mobile/issues';

  late final Future<DateTime?> _packageBuildDate = const BuildInfoService()
      .packageBuildDate();
  late final Future<PackageVersion?> _packageVersion = const BuildInfoService()
      .packageVersion();

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
            child: _packageVersionValue(
              context,
              prefix: '${l10n.aboutVersion} ',
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
                _infoTile(
                  context,
                  Icons.code,
                  l10n.aboutVersion,
                  _packageVersionValue(context),
                ),
                _divider(context),
                _infoTile(
                  context,
                  Icons.calendar_today_outlined,
                  l10n.aboutBuildDate,
                  _buildDateValue(context),
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
                  Icons.chat_bubble_outline,
                  l10n.aboutReportIssue,
                  _issuesUrl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDateValue(BuildContext context) => FutureBuilder<DateTime?>(
    future: _packageBuildDate,
    builder: (context, snapshot) {
      final buildDate = snapshot.data;
      final label = buildDate == null
          ? '-'
          : DateFormat('MMM d, y HH:mm').format(buildDate.toLocal());
      return Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    },
  );

  Widget _packageVersionValue(
    BuildContext context, {
    String prefix = '',
    TextStyle? style,
  }) => FutureBuilder<PackageVersion?>(
    future: _packageVersion,
    builder: (context, snapshot) => Text(
      '$prefix${snapshot.data?.display ?? '-'}',
      style:
          style ??
          Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    ),
  );

  Widget _divider(BuildContext context) => Divider(
    height: 1,
    indent: 56,
    color: Theme.of(context).dividerTheme.color,
  );

  Widget _infoTile(
    BuildContext context,
    IconData icon,
    String label,
    Object value,
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
          if (value is Widget)
            value
          else
            Text(
              value.toString(),
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
