import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/status_service.dart';
import '../core/services/emoji_service.dart';
import '../core/models/user_status.dart';

class HomeScreenWidget extends ConsumerStatefulWidget {
  const HomeScreenWidget({super.key});

  @override
  ConsumerState<HomeScreenWidget> createState() => _HomeScreenWidgetState();
}

class _HomeScreenWidgetState extends ConsumerState<HomeScreenWidget> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  String? _lastSelectedEmoji;
  bool _isProcessing = false;

  // Los 6 emojis principales cargados desde Firebase
  List<StatusType> _emojis = [];

  // Mapping de IDs antiguos a nuevos (para compatibilidad)
  static const _emojiMapping = [
    'away', // Ausente (antes leave)
    'busy', // Ocupado
    'fine',
    'do_not_disturb', // No molestar (antes sad)
    'fine',
    'sos', // SOS
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadEmojis();
    _initializeWidget();
  }

  Future<void> _loadEmojis() async {
    try {
      final allEmojis = await EmojiService.getPredefinedEmojis();
      final selectedEmojis = <StatusType>[];

      for (final id in _emojiMapping) {
        final emoji = allEmojis.firstWhere(
          (e) => e.id == id,
          orElse: () => StatusType.fallbackPredefined.first,
        );
        selectedEmojis.add(emoji);
      }

      if (mounted) {
        setState(() => _emojis = selectedEmojis);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _emojis = StatusType.fallbackPredefined.take(6).toList());
      }
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _initializeWidget() async {
    await HomeWidget.setAppGroupId('group.zync.widget');
    await _updateWidgetData();
  }

  Future<void> _updateWidgetData() async {
    await HomeWidget.saveWidgetData(
        'emojis',
        _emojis
            .map((e) => {
                  'emoji': e.emoji,
                  'label': e.shortLabel,
                  'status': e.id,
                })
            .toList());

    await HomeWidget.updateWidget(
      name: 'ZyncStatusWidget',
      androidName: 'ZyncStatusWidget',
      iOSName: 'ZyncStatusWidget',
    );
  }

  Future<void> _handleEmojiTap(StatusType statusType) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _lastSelectedEmoji = statusType.emoji;
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    HapticFeedback.mediumImpact();

    try {
      // Usar StatusService con el StatusType correcto
      await StatusService.updateUserStatus(statusType);
      await _showSuccessFeedback(statusType.emoji);
    } catch (e) {
      await _showErrorFeedback();
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _showSuccessFeedback(String emoji) async {
    await HomeWidget.saveWidgetData('lastStatus', emoji);
    await HomeWidget.saveWidgetData('lastUpdate', DateTime.now().toIso8601String());
    await _updateWidgetData();

    setState(() {
      _lastSelectedEmoji = '✅';
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _lastSelectedEmoji = emoji;
    });
  }

  Future<void> _showErrorFeedback() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _lastSelectedEmoji = '❌';
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _lastSelectedEmoji = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1CE4B3).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _emojis.length,
            itemBuilder: (context, index) {
              final emojiData = _emojis[index];
              final isSelected = _lastSelectedEmoji == emojiData.emoji;
              final isProcessing = _isProcessing && isSelected;

              return GestureDetector(
                onTap: () => _handleEmojiTap(emojiData),
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isProcessing ? _scaleAnimation.value : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1CE4B3).withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1CE4B3) : Colors.grey.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              emojiData.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              emojiData.shortLabel,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected ? const Color(0xFF1CE4B3) : Colors.grey,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: _isProcessing ? Colors.orange : const Color(0xFF1CE4B3),
              ),
              const SizedBox(width: 8),
              Text(
                _isProcessing ? 'Enviando...' : 'Zync',
                style: TextStyle(
                  fontSize: 12,
                  color: _isProcessing ? Colors.orange : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
