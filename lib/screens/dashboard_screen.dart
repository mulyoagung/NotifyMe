import 'package:flutter/material.dart';
import '../models/monitored_link.dart';
import '../services/database_helper.dart';
import 'add_edit_link_screen.dart';
import 'detail_screen.dart';
import '../theme.dart';
import 'dart:ui'; // For BackdropFilter

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MonitoredLink> links = [];
  bool isLoading = true;
  String _searchQuery = '';
  bool _isSearchingMobile = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLinks();
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m yg lalu';
    if (diff.inHours < 24) return '${diff.inHours}j yg lalu';
    return '${diff.inDays}h yg lalu';
  }

  Future<void> _loadLinks() async {
    setState(() => isLoading = true);
    final fetchedLinks = await DatabaseHelper.instance.readAllLinks();

    // Urutkan List (Updates di atas, lalu urutkan kapan terakhir mengecek)
    fetchedLinks.sort((a, b) {
      if (a.hasUpdate == b.hasUpdate) {
        return b.lastCheckedAt.compareTo(a.lastCheckedAt);
      }
      return a.hasUpdate ? -1 : 1;
    });

    if (mounted) {
      setState(() {
        links = fetchedLinks;
        isLoading = false;
      });
    }
  }

  List<MonitoredLink> _getFilteredLinks(List<MonitoredLink> sourceLinks) {
    if (_searchQuery.isEmpty) return sourceLinks;
    return sourceLinks.where((link) {
      return link.name.toLowerCase().contains(_searchQuery) ||
          link.url.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToAddEdit([MonitoredLink? link]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditLinkScreen(link: link)),
    );
    _loadLinks();
  }

  void _navigateToDetail(MonitoredLink link) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetailScreen(link: link)),
    );
    _loadLinks();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isDesktop = MediaQuery.of(context).size.width >= 1024;

    if (isDesktop) {
      return _buildDesktopDashboard(isDark);
    } else {
      return _buildMobileDashboard(isDark);
    }
  }

  Widget _buildDesktopDashboard(bool isDark) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Background is inherited from MainNavigation
      body: Column(
        children: [
          // Header
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0A0F0D).withOpacity(0.5)
                      : Colors.white.withOpacity(0.8),
                  border: Border(
                      bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monitor Dashboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 256,
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search,
                                  size: 18, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value.toLowerCase();
                                    });
                                  },
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: 'Search monitors...',
                                    hintStyle: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: () => _navigateToAddEdit(),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor:
                                const Color(0xFF0A0F0D), // dark background
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: 8,
                            shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add Website',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Body Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: _buildGridView(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDashboard(bool isDark) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchingMobile
            ? TextField(
                autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search URL or Name...',
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
              )
            : Row(
                children: [
                  Icon(Icons.monitor_heart, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text('NotifyMe',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearchingMobile ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearchingMobile) {
                  _searchQuery = '';
                }
                _isSearchingMobile = !_isSearchingMobile;
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Errors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMobileListView(_getFilteredLinks(links), isDark),
          _buildMobileListView(
              _getFilteredLinks(links.where((l) => l.isActive).toList()),
              isDark),
          _buildMobileListView(
              _getFilteredLinks(links
                  .where((l) => !l.isActive || (l.isActive && !l.hasUpdate))
                  .toList()),
              isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEdit(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.backgroundDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildMobileListView(List<MonitoredLink> itemLinks, bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadLinks,
      color: AppTheme.primaryColor,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemLinks.length,
        itemBuilder: (context, index) {
          return _buildMobileMonitorCard(itemLinks[index], isDark);
        },
      ),
    );
  }

  Widget _buildMobileMonitorCard(MonitoredLink link, bool isDark) {
    bool isErrorState = !link.isActive && !link.hasUpdate;
    return Card(
      color: isDark ? AppTheme.cardDark : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetail(link),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isErrorState
                          ? Colors.red
                          : (link.hasUpdate
                              ? AppTheme.primaryColor
                              : Colors.grey),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      link.name,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings,
                        size: 20, color: Colors.grey.shade500),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _navigateToAddEdit(link),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${link.intervalMinutes}m',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      link.url,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Icon(Icons.update, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeAgo(link.lastCheckedAt),
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              if (link.hasUpdate)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Update Detected',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridView(bool isDark) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 1400 ? 3 : (screenWidth > 1024 ? 2 : 1);

    final filteredLinks = _getFilteredLinks(links);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.3, // Adjust card proportion
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: filteredLinks.length,
      itemBuilder: (context, index) {
        return _buildDesktopMonitorCard(filteredLinks[index], isDark);
      },
    );
  }

  Widget _buildDesktopMonitorCard(MonitoredLink link, bool isDark) {
    bool isErrorState = !link.isActive && !link.hasUpdate;

    // Outer border color overrides
    Color defaultBorderColor =
        isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;
    Color borderColor = link.hasUpdate
        ? AppTheme.primaryColor.withOpacity(0.3)
        : (isErrorState ? Colors.red.withOpacity(0.3) : defaultBorderColor);
    Color cardColor = isDark ? AppTheme.cardDark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8))
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Blob blur for hasUpdate (mocked using positioned container)
            if (link.hasUpdate)
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            // Card Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upper Row: Icon & Titles
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.shade200),
                        ),
                        child: Icon(
                          isErrorState
                              ? Icons.error_outline
                              : (link.name.contains('Store')
                                  ? Icons.storefront
                                  : Icons.language),
                          color: isErrorState
                              ? Colors.red.shade400
                              : (isDark ? Colors.white : Colors.grey.shade800),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              link.url,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings,
                            size: 20, color: Colors.grey.shade500),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _navigateToAddEdit(link),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Tags Row
                  Row(
                    children: [
                      // Status Label
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isErrorState
                              ? Colors.red.withOpacity(0.1)
                              : AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isErrorState)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle),
                                margin: const EdgeInsets.only(right: 6),
                              ),
                            Text(
                              isErrorState ? 'Error (502)' : 'Active',
                              style: TextStyle(
                                color: isErrorState
                                    ? Colors.redAccent
                                    : AppTheme.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Time Label
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule,
                                size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 6),
                            Text(
                              _formatTimeAgo(link.lastCheckedAt),
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Footer Actions
                  if (link.hasUpdate)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('UPDATES DETECTED',
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5)),
                              Text('Price update',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: AppTheme.backgroundDark,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _navigateToDetail(link),
                            icon: const Text('View Changes',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            label: const Icon(Icons.visibility, size: 20),
                          ),
                        ),
                      ],
                    )
                  else if (isErrorState)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gateway Timeout detected. Retrying...',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {},
                            icon: const Text('Reconnect',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                            label: const Icon(Icons.refresh,
                                size: 20, color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.shade100)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Last change: 2 days ago',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13)),
                          IconButton(
                            icon: Icon(Icons.settings,
                                size: 20, color: AppTheme.primaryColor),
                            onPressed: () => _navigateToAddEdit(link),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
