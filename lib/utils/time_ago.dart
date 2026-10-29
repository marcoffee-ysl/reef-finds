String timeAgo(String? value) {
  final date = DateTime.tryParse(value ?? '')?.toLocal();
  if (date == null) return '';

  final difference = DateTime.now().difference(date);
  if (difference.isNegative || difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  if (difference.inDays < 7) {
    final days = difference.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }
  final weeks = difference.inDays ~/ 7;
  return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
}
