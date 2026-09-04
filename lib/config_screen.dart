import 'package:flutter/material.dart';
import 'agent_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final TextEditingController _targetController = TextEditingController();

  final Map<String, bool> _selectedPlatforms = {
    'Google': true,
    'LinkedIn': true,
    'Facebook': false,
    'Instagram': false,
    'TikTok': false,
    'WhatsApp': true,
    'Twitter (X)': false,
    'Reddit': false,
    'Quora': false,
    'Pinterest': false,
  };

  final Map<String, IconData> _platformIcons = {
    'Google': Icons.language_rounded,
    'LinkedIn': Icons.link_rounded,
    'Facebook': Icons.facebook_rounded,
    'Instagram': Icons.camera_alt_rounded,
    'TikTok': Icons.music_note_rounded,
    'WhatsApp': Icons.chat_bubble_rounded,
    'Twitter (X)': Icons.close_rounded, // اسپیس فکس کر دی گئی ہے
    'Reddit': Icons.reddit_rounded,
    'Quora': Icons.question_answer_rounded,
    'Pinterest': Icons.pin_drop_rounded,
  };

  bool _aiAutoReply = true;
  bool _notifyWhatsApp = true;
  bool _notifyGmail = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  // ایجنٹ لانچ کرنے کا مین فنکشن
  Future<void> _handleLaunch() async {
    if (_targetController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a business target first!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // منتخب پلیٹ فارمز نکالنا
    List<String> selected = _selectedPlatforms.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    try {
      // ایجنٹ سروس کال کریں
      await AgentService.launchAgent(
        query: _targetController.text.trim(),
        platforms: selected,
        autoReply: _aiAutoReply,
        notifyWhatsApp: _notifyWhatsApp,
        notifyGmail: _notifyGmail,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Agent Launched! Hunting leads for you... 🚀"),
            backgroundColor: Color(0xFF34C759),
          ),
        );

        // یوزر کو واپس یا پائپ لائن اسکرین پر بھیج دیں
        Future.delayed(const Duration(seconds: 1), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Launch Failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup AI Agent', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("1. Business Target", Icons.radar_rounded),
            const SizedBox(height: 12),
            _buildTargetInput(isDark),

            const SizedBox(height: 24),
            _buildSectionHeader("2. Target Platforms", Icons.hub_rounded),
            const SizedBox(height: 12),
            _buildPlatformGrid(size, isDark),

            const SizedBox(height: 24),
            _buildSectionHeader("3. System Preferences", Icons.settings_suggest_rounded),
            const SizedBox(height: 12),
            _buildSettingsToggle("AI Auto-Reply", _aiAutoReply, (v) => setState(() => _aiAutoReply = v)),
            _buildSettingsToggle("Notify on WhatsApp", _notifyWhatsApp, (v) => setState(() => _notifyWhatsApp = v)),
            _buildSettingsToggle("Notify on Gmail", _notifyGmail, (v) => setState(() => _notifyGmail = v)),

            const SizedBox(height: 32),
            _buildLaunchButton(isDark),
          ],
        ),
      ),
    );
  }

  // --- ریوز ایبل وزٹس (Reusable Widgets) ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF007AFF)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildTargetInput(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: _targetController,
        decoration: InputDecoration(
          hintText: "e.g. Real Estate Karachi",
          filled: true,
          fillColor: isDark ? Colors.white.withAlpha(15) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: const Icon(Icons.tune_rounded, size: 18),
        ),
      ),
    );
  }

  Widget _buildPlatformGrid(Size size, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: size.width > 600 ? 5 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _selectedPlatforms.length,
      itemBuilder: (context, index) {
        String platform = _selectedPlatforms.keys.elementAt(index);
        bool isSelected = _selectedPlatforms[platform]!;
        return GestureDetector(
          onTap: () => setState(() => _selectedPlatforms[platform] = !isSelected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF007AFF) : (isDark ? Colors.white.withAlpha(10) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey.shade200)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _platformIcons[platform] ?? Icons.public,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade600),
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  platform,
                  style: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsToggle(String title, bool val, Function(bool) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        value: val,
        onChanged: onChanged,
        activeColor: const Color(0xFF007AFF),
      ),
    );
  }

  Widget _buildLaunchButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1C1C1E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : _handleLaunch,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, size: 20),
            SizedBox(width: 10),
            Text("SAVE & LAUNCH AGENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}