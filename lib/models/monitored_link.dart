class MonitoredLink {
  int? id;
  String name;
  String url;
  String cssSelector;
  int intervalMinutes;
  bool isActive;
  DateTime lastCheckedAt;
  bool hasUpdate;
  String lastSnapshot;
  String previousSnapshot;
  String
      preNavigationScript; // Optional JS to run before scraping (e.g. click a menu)

  MonitoredLink({
    this.id,
    required this.name,
    required this.url,
    this.cssSelector = '',
    this.intervalMinutes = 15,
    this.isActive = true,
    required this.lastCheckedAt,
    this.hasUpdate = false,
    this.lastSnapshot = '',
    this.previousSnapshot = '',
    this.preNavigationScript = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'cssSelector': cssSelector,
      'intervalMinutes': intervalMinutes,
      'isActive': isActive ? 1 : 0,
      'lastCheckedAt': lastCheckedAt.toIso8601String(),
      'hasUpdate': hasUpdate ? 1 : 0,
      'lastSnapshot': lastSnapshot,
      'previousSnapshot': previousSnapshot,
      'preNavigationScript': preNavigationScript,
    };
  }

  factory MonitoredLink.fromMap(Map<String, dynamic> map) {
    return MonitoredLink(
      id: map['id'],
      name: map['name'],
      url: map['url'],
      cssSelector: map['cssSelector'] ?? '',
      intervalMinutes: map['intervalMinutes'] ?? 15,
      isActive: map['isActive'] == 1,
      lastCheckedAt: DateTime.parse(map['lastCheckedAt']),
      hasUpdate: map['hasUpdate'] == 1,
      lastSnapshot: map['lastSnapshot'] ?? '',
      previousSnapshot: map['previousSnapshot'] ?? '',
      preNavigationScript: map['preNavigationScript'] ?? '',
    );
  }
}
