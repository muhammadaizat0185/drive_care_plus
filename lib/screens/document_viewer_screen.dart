import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/color_utils.dart';
import '../core/theme/tokens/tokens.dart';
import '../core/util/expiry.dart';
import '../core/util/format_bytes.dart';
import '../widgets/ui/ui.dart';
import 'document_vault/_widgets.dart';

class DocumentViewerScreen extends StatelessWidget {
  final VaultDocument document;

  const DocumentViewerScreen({
    super.key,
    required this.document,
  });

  static const String routeName = '/document-viewer';

  bool _isImage(String url) {
    final String path = url.split('?').first.toLowerCase();
    return path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }

  String _getFileExtension(String url) {
    try {
      final String path = url.split('?').first.toLowerCase();
      return path.split('.').last;
    } catch (_) {
      return '';
    }
  }

  Future<void> _openDocument(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open document: $e')),
        );
      }
    }
  }

  void _copyLink(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document link copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;

    final String fileUrl = document.fileUrl ?? '';
    final bool hasFile = fileUrl.isNotEmpty;
    final bool isImg = hasFile && _isImage(fileUrl);
    final String ext = hasFile ? _getFileExtension(fileUrl).toUpperCase() : '';

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            document.title,
            style: typography.headline.copyWith(color: colors.foreground),
          ),
          actions: <Widget>[
            if (hasFile) ...[
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy link',
                onPressed: () => _copyLink(context, fileUrl),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_browser),
                tooltip: 'Open in browser',
                onPressed: () => _openDocument(context, fileUrl),
              ),
            ]
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Viewer/Preview area
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.muted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(radii.large),
                      border: Border.all(color: colors.foreground.withValues(alpha: 0.08)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isImg
                        ? InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Center(
                              child: Image.network(
                                fileUrl,
                                loadingBuilder: (BuildContext context, Widget child,
                                    ImageChunkEvent? loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: colors.emerald500,
                                    ),
                                  );
                                },
                                errorBuilder: (BuildContext context, Object error,
                                    StackTrace? stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Icon(Icons.broken_image, size: 48, color: colors.error),
                                        SizedBox(height: spacing.sm),
                                        Text(
                                          'Failed to load preview',
                                          style: typography.bodyLarge.copyWith(color: colors.error),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  hasFile
                                      ? (ext == 'PDF' ? Icons.picture_as_pdf : Icons.description)
                                      : Icons.notes_outlined,
                                  size: 72,
                                  color: colors.emerald500,
                                ),
                                SizedBox(height: spacing.md),
                                Text(
                                  hasFile ? '$ext File Attached' : 'Text Record Only',
                                  style: typography.headline.copyWith(color: colors.foreground),
                                ),
                                if (hasFile) ...[
                                  SizedBox(height: spacing.xs),
                                  if (document.fileSizeBytes != null)
                                    Text(
                                      formatBytes(document.fileSizeBytes!),
                                      style: typography.bodyLarge.copyWith(
                                        color: colors.foreground.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  SizedBox(height: spacing.lg),
                                  AppGradientButton(
                                    label: 'Open Document',
                                    icon: Icons.open_in_new,
                                    onPressed: () => _openDocument(context, fileUrl),
                                  ),
                                ]
                              ],
                            ),
                          ),
                  ),
                ),
              ),

              // Metadata Details Area
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                document.title,
                                style: typography.title.copyWith(
                                  color: colors.foreground,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AppBadge(text: document.category),
                          ],
                        ),
                        SizedBox(height: spacing.md),
                        if (document.expiryDate != null) ...[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: colors.foreground.withValues(alpha: 0.5),
                              ),
                              SizedBox(width: spacing.sm),
                              Text(
                                'Expires ${document.expiryDate!.day}/${document.expiryDate!.month}/${document.expiryDate!.year}',
                                style: typography.bodyLarge.copyWith(
                                  color: colors.foreground.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing.md),
                        ],
                        if (document.note.isNotEmpty) ...[
                          Text(
                            'Note',
                            style: typography.label.copyWith(
                              color: colors.foreground.withValues(alpha: 0.5),
                            ),
                          ),
                          SizedBox(height: spacing.xs),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(spacing.md),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(radii.medium),
                              border: Border.all(color: colors.foreground.withValues(alpha: 0.05)),
                            ),
                            child: Text(
                              document.note,
                              style: typography.bodyLarge.copyWith(color: colors.foreground),
                            ),
                          ),
                          SizedBox(height: spacing.lg),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
