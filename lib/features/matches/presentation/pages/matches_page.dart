import 'package:flutter/material.dart';

import '../../domain/match.dart';
import '../widgets/match_widgets.dart';

class MatchesPage extends StatelessWidget {
  const MatchesPage({
    required this.matches,
    required this.onCreate,
    required this.onOpen,
    super.key,
  });

  final List<MatchData> matches;
  final VoidCallback onCreate;
  final ValueChanged<MatchData> onOpen;

  @override
  Widget build(BuildContext context) => PageScroll(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          eyebrow: 'MATCH LIBRARY',
          title: '내 경기',
          subtitle: '녹화한 경기와 업로드 상태를 한 곳에서 관리하세요.',
          action: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('경기 만들기'),
          ),
        ),
        for (final match in matches)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MatchRow(match: match, onTap: () => onOpen(match)),
          ),
      ],
    ),
  );
}
