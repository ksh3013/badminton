String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0
      ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
      : '$minutes:$seconds';
}

String formatHoursMinutes(Duration duration) =>
    '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';

String formatDate(DateTime? date) {
  if (date == null) return '날짜 미정';
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String formatStorageBytes(int? bytes) {
  if (bytes == null) return '확인 필요';
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB 여유';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB 여유';
}

String formatTodayHeading(DateTime date) {
  const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${weekdays[date.weekday - 1]} · ${date.day} ${months[date.month - 1]} ${date.year}';
}
