import 'package:flutter/material.dart';

import '../controller.dart';
import '../issues.dart';

/// Side panel listing the overflows and errors caught on every device.
class MirrorIssuesPanel extends StatelessWidget {
  /// Creates the panel for [controller].
  const MirrorIssuesPanel({super.key, required this.controller});

  /// The controller holding the issues.
  final ResponsiveMirrorController controller;

  @override
  Widget build(BuildContext context) {
    final issues = controller.issues;
    return Container(
      key: const ValueKey('rm_issues_panel'),
      width: 360,
      color: const Color(0xFF161922),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(children: [
              Text(
                'Issues (${issues.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: issues.isEmpty ? null : controller.clearIssues,
                child: const Text('Clear'),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => controller.showIssues = false,
              ),
            ]),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: issues.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No overflow or errors on any device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: issues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _IssueCard(issue: issues[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});

  final MirrorIssue issue;

  @override
  Widget build(BuildContext context) {
    final overflow = issue.kind == MirrorIssueKind.overflow;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF221A1F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x55E5484D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              overflow ? Icons.unfold_more_double : Icons.error_outline,
              size: 16,
              color: const Color(0xFFFF8A8E),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                issue.where,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (issue.count > 1)
              Text('×${issue.count}',
                  style: const TextStyle(color: Colors.white54)),
          ]),
          const SizedBox(height: 6),
          SelectableText(
            issue.message,
            style: const TextStyle(fontSize: 12.5, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
