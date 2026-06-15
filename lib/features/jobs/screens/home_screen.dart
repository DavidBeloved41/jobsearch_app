import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/job_filters.dart';
import '../../../core/models/match_profile_context.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/match_score_service.dart';
import '../../../core/services/natural_language_search_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/company_logo.dart';
import '../../applications/screens/applications_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../messages/screens/messages_screen.dart';
import '../../profile/screens/notifications_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../widgets/job_filters_sheet.dart';
import 'job_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const JobsFeedScreen(),
    const ApplicationsScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.surf(context),
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Applications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class JobsFeedScreen extends StatefulWidget {
  const JobsFeedScreen({super.key});

  @override
  State<JobsFeedScreen> createState() => _JobsFeedScreenState();
}

class _JobsFeedScreenState extends State<JobsFeedScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _forYouMode = true;
  bool _isOffline = false;
  JobFilters _advancedFilters = const JobFilters();
  final _searchController = TextEditingController();
  Set<String> _savedJobIds = {};
  List<String> _userSkillNames = [];
  int? _userYearsExperience;
  MatchProfileContext _matchContext = const MatchProfileContext();
  String? _nlSearchSummary;
  String? _experienceLevelFilter;
  int _pendingSyncCount = 0;
  Timer? _searchDebounce;
  bool _aiRankingActive = false;

  final List<Map<String, String>> _filters = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Remote', 'value': 'remote'},
    {'label': 'Hybrid', 'value': 'hybrid'},
    {'label': 'On-site', 'value': 'on-site'},
    {'label': 'Full-time', 'value': 'full-time'},
    {'label': 'Contract', 'value': 'contract'},
  ];

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _syncOfflineChanges();
  }

  Future<void> _syncOfflineChanges() async {
    final synced = await OfflineSyncService.syncPendingChanges();
    final pending = await OfflineCacheService.getPendingApplicationCount();
    if (mounted) {
      setState(() => _pendingSyncCount = pending);
      if (synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced $synced offline change${synced == 1 ? '' : 's'}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadJobs();
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserContext() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _savedJobIds = {};
      _userSkillNames = [];
      _userYearsExperience = null;
      return;
    }

    final profile = await SupabaseService.getProfile(user.id);
    final skills = await SupabaseService.getUserSkillNames(user.id);
    final savedIds = await SupabaseService.getSavedJobIds(user.id);

    _savedJobIds = savedIds;
    _userSkillNames = skills;
    _matchContext = MatchProfileContext.fromProfile(profile, skills);
    _userYearsExperience = _matchContext.yearsExperience;
  }

  String? get _effectiveWorkModel {
    if (_advancedFilters.workModel != 'all') return _advancedFilters.workModel;
    if (['remote', 'hybrid', 'on-site'].contains(_selectedFilter)) {
      return _selectedFilter;
    }
    return null;
  }

  String? get _effectiveEmploymentType {
    if (_advancedFilters.employmentType != 'all') {
      return _advancedFilters.employmentType;
    }
    if (['full-time', 'contract'].contains(_selectedFilter)) {
      return _selectedFilter;
    }
    return null;
  }

  Future<bool> _hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
      _aiRankingActive = false;
    });
    final online = await _hasConnection();

    try {
      if (online) {
        await _loadUserContext();
        final jobs = await SupabaseService.getJobs(
          workModel: _effectiveWorkModel,
          employmentType: _effectiveEmploymentType,
          experienceLevel: _experienceLevelFilter,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
          minSalary: _advancedFilters.minSalary,
          maxSalary: _advancedFilters.maxSalary,
          location: _advancedFilters.location.isNotEmpty
              ? _advancedFilters.location
              : null,
          industry: _advancedFilters.industry.isNotEmpty
              ? _advancedFilters.industry
              : null,
          techStack: _advancedFilters.techStack.isNotEmpty
              ? _advancedFilters.techStack
              : null,
        );

        var displayJobs = List<Map<String, dynamic>>.from(jobs);
        if (_forYouMode) {
          displayJobs.sort((a, b) {
            final scoreA = MatchScoreService.calculate(
              job: a,
              userSkillNames: _userSkillNames,
              userYearsExperience: _userYearsExperience,
              profile: _matchContext,
            );
            final scoreB = MatchScoreService.calculate(
              job: b,
              userSkillNames: _userSkillNames,
              userYearsExperience: _userYearsExperience,
              profile: _matchContext,
            );
            return scoreB.compareTo(scoreA);
          });

          if (AiService.isConfigured && displayJobs.length > 1) {
            final profile = await SupabaseService.getProfile(
              Supabase.instance.client.auth.currentUser!.id,
            );
            final rankedIds = await AiService.rankJobIds(
              jobs: displayJobs,
              profile: profile,
              skills: _userSkillNames,
            );
            if (rankedIds != null && rankedIds.isNotEmpty) {
              final byId = {for (final j in displayJobs) j['id']: j};
              final reordered = <Map<String, dynamic>>[];
              for (final id in rankedIds) {
                final job = byId[id];
                if (job != null) reordered.add(job);
              }
              for (final job in displayJobs) {
                if (!rankedIds.contains(job['id'])) reordered.add(job);
              }
              displayJobs = reordered;
              _aiRankingActive = true;
            }
          }
        }

        await OfflineCacheService.cacheJobs(displayJobs);

        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final profile = await SupabaseService.getProfile(user.id);
          if (profile != null) {
            await OfflineCacheService.cacheProfile(user.id, profile);
          }
          await NotificationService.checkHighMatchJobs(
            jobs: displayJobs,
            userSkillNames: _userSkillNames,
            userYearsExperience: _userYearsExperience,
            profile: _matchContext,
          );
        }

        setState(() {
          _jobs = displayJobs;
          _isOffline = false;
          _isLoading = false;
        });
      } else {
        throw Exception('offline');
      }
    } catch (e) {
      final cached = await OfflineCacheService.getCachedJobs();
      setState(() {
        _jobs = cached ?? [];
        _isOffline = cached != null;
        _isLoading = false;
      });
      if (cached == null) {
        debugPrint('Error loading jobs: $e');
      }
    }
  }

  Future<void> _openAdvancedFilters() async {
    final result = await showModalBottomSheet<JobFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => JobFiltersSheet(initialFilters: _advancedFilters),
    );
    if (result != null) {
      setState(() {
        _advancedFilters = result;
        if (result.workModel != 'all') {
          _selectedFilter = result.workModel;
        } else if (result.employmentType != 'all') {
          _selectedFilter = result.employmentType;
        } else if (!['remote', 'hybrid', 'on-site', 'full-time', 'contract']
            .contains(_selectedFilter)) {
          _selectedFilter = 'all';
        }
      });
      _loadJobs();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (value.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _searchQuery = '';
          _nlSearchSummary = null;
          _experienceLevelFilter = null;
        });
        _loadJobs();
        return;
      }

      final parsed = await NaturalLanguageSearchService.parseSmart(value);
      if (!mounted) return;
      setState(() {
        _searchQuery = parsed.keywordQuery ?? value.trim();
        if (parsed.hasStructuredFilters) {
          _advancedFilters = parsed.filters;
          _experienceLevelFilter = parsed.experienceLevel;
          _nlSearchSummary = parsed.summary;
          if (parsed.filters.workModel != 'all') {
            _selectedFilter = parsed.filters.workModel;
          } else if (parsed.filters.employmentType != 'all') {
            _selectedFilter = parsed.filters.employmentType;
          }
        } else {
          _nlSearchSummary = null;
          _experienceLevelFilter = null;
        }
      });
      _loadJobs();
    });
  }

  String _formatSalary(Map<String, dynamic> job) {
    final min = (job['salary_min'] as num?) ?? 0;
    final max = (job['salary_max'] as num?) ?? 0;
    if (min <= 0 && max <= 0) return 'Salary not listed';
    return '\$${(min / 1000).toStringAsFixed(0)}k - \$${(max / 1000).toStringAsFixed(0)}k';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Find Jobs'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _advancedFilters.activeCount > 0,
              label: Text('${_advancedFilters.activeCount}'),
              child: const Icon(Icons.tune),
            ),
            onPressed: _openAdvancedFilters,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadJobs,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_pendingSyncCount > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sync_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_pendingSyncCount application(s) waiting to sync',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.text(context),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _syncOfflineChanges,
                        child: const Text('Sync now'),
                      ),
                    ],
                  ),
                ),
              if (_isOffline)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline — showing cached jobs',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.text(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('For You'),
                          icon: Icon(Icons.auto_awesome, size: 18),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('All jobs'),
                        ),
                      ],
                      selected: {_forYouMode},
                      onSelectionChanged: (s) {
                        setState(() => _forYouMode = s.first);
                        _loadJobs();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bord(context)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: AppColors.text(context)),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText:
                        'Try: Senior roles in London remote over \$60k...',
                    hintStyle:
                        TextStyle(color: AppColors.textSec(context)),
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.textSec(context)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: AppColors.textSec(context)),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_nlSearchSummary != null && _nlSearchSummary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Parsed: $_nlSearchSummary',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSec(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter['value'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter['value']!;
                          final value = filter['value']!;
                          if (value == 'all') {
                            _advancedFilters = _advancedFilters.copyWith(
                              workModel: 'all',
                              employmentType: 'all',
                            );
                          } else if (['remote', 'hybrid', 'on-site']
                              .contains(value)) {
                            _advancedFilters =
                                _advancedFilters.copyWith(workModel: value);
                          } else if (['full-time', 'contract']
                              .contains(value)) {
                            _advancedFilters = _advancedFilters.copyWith(
                              employmentType: value,
                            );
                          }
                        });
                        _loadJobs();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surf(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.bord(context),
                          ),
                        ),
                        child: Text(
                          filter['label']!,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSec(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                _forYouMode
                    ? (_aiRankingActive
                        ? 'AI-ranked for you'
                        : 'Recommended for you')
                    : 'All jobs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 12),

              // Jobs list
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : _jobs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.work_off_outlined,
                                    size: 64,
                                    color: AppColors.textSec(context)),
                                const SizedBox(height: 16),
                                Text(
                                  'No jobs found',
                                  style: TextStyle(
                                      color: AppColors.textSec(context)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: _jobs.map((job) {
                            final company =
                                job['companies'] as Map<String, dynamic>?;
                            final jobId = job['id'] as String? ?? '';
                            final matchScore = MatchScoreService.calculate(
                              job: job,
                              userSkillNames: _userSkillNames,
                              userYearsExperience: _userYearsExperience,
                              profile: _matchContext,
                            );
                            return GestureDetector(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        JobDetailScreen(job: job),
                                  ),
                                );
                                _loadJobs();
                              },
                              child: _JobCard(
                                title: job['title'] ?? '',
                                company: company?['name'] ?? '',
                                location: job['location'] ?? '',
                                salary: _formatSalary(job),
                                workModel: job['work_model'] ?? '',
                                matchScore: matchScore,
                                logoUrl: company?['logo_url'] as String?,
                                jobId: jobId,
                                initialIsSaved: _savedJobIds.contains(jobId),
                                onSaveChanged: (saved) {
                                  setState(() {
                                    if (saved) {
                                      _savedJobIds.add(jobId);
                                    } else {
                                      _savedJobIds.remove(jobId);
                                    }
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatefulWidget {
  final String title;
  final String company;
  final String location;
  final String salary;
  final String workModel;
  final int matchScore;
  final String? logoUrl;
  final String jobId;
  final bool initialIsSaved;
  final void Function(bool saved)? onSaveChanged;

  const _JobCard({
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.workModel,
    required this.matchScore,
    this.logoUrl,
    required this.jobId,
    this.initialIsSaved = false,
    this.onSaveChanged,
  });

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.initialIsSaved;
  }

  @override
  void didUpdateWidget(covariant _JobCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsSaved != widget.initialIsSaved) {
      _isSaved = widget.initialIsSaved;
    }
  }

  Future<void> _toggleSave() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surf(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline,
                      color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You need to sign in to save jobs.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSec(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('Sign in'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Maybe later'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
      return;
    }

    try {
      if (_isSaved) {
        await SupabaseService.unsaveJob(user.id, widget.jobId);
      } else {
        await SupabaseService.saveJob(user.id, widget.jobId);
      }
      setState(() => _isSaved = !_isSaved);
      widget.onSaveChanged?.call(_isSaved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isSaved ? 'Job saved!' : 'Job removed from saved'),
            backgroundColor: _isSaved
                ? AppColors.success
                : AppColors.textSecondary,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling save: $e');
    }
  }

  Color get _workModelColor {
    switch (widget.workModel) {
      case 'remote':
        return AppColors.success;
      case 'hybrid':
        return AppColors.warning;
      default:
        return AppColors.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bord(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CompanyLogo(logoUrl: widget.logoUrl, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.company,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSec(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.matchScore}% match',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textSec(context)),
              const SizedBox(width: 4),
              Text(
                widget.location,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSec(context),
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.attach_money,
                  size: 14, color: AppColors.textSec(context)),
              const SizedBox(width: 4),
              Text(
                widget.salary,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSec(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _workModelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.workModel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _workModelColor,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: _isSaved
                      ? AppColors.primary
                      : AppColors.textSec(context),
                ),
                onPressed: _toggleSave,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}