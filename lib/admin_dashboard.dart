import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'plan_service.dart';

class AdminService {
  static final supabase = Supabase.instance.client;
  
  // یہ ویری ایبل بتائے گا کہ لاگ ان یوزر ایڈمن ہے یا نہیں
  static bool currentUserIsAdmin = false;

  // ایپ لوڈ ہوتے ہی یا لاگ ان کے بعد یہ فنکشن کال کریں
  static Future<void> checkAdminStatus() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();
      
      if (data != null) {
        currentUserIsAdmin = data['is_admin'] ?? false;
      }
    }
  }

  // 1. ریونیو اور یوزرز کا ڈیٹا لانا
  static Future<Map<String, dynamic>> fetchAppStats() async {
    final data = await supabase.from('app_stats').select().eq('id', 1).single();
    return data;
  }

  // 2. ریونیو اپ ڈیٹ کرنا (ایڈمن پینل سے)
  static Future<void> updateStats(String revenue, String users) async {
    await supabase.from('app_stats').update({
      'total_revenue': revenue,
      'active_users': users,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', 1);
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final TextEditingController _revenueController = TextEditingController(text: "42,800");
  final TextEditingController _usersController = TextEditingController(text: "154");
  bool _isStatsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isStatsLoading = true);
    try {
      final stats = await AdminService.fetchAppStats();
      setState(() {
        _revenueController.text = stats['total_revenue']?.toString() ?? "0";
        _usersController.text = stats['active_users']?.toString() ?? "0";
      });
    } catch (e) {
      debugPrint("Error loading stats: $e");
    } finally {
      setState(() => _isStatsLoading = false);
    }
  }

  Future<void> _saveStats() async {
    setState(() => _isStatsLoading = true);
    try {
      await AdminService.updateStats(_revenueController.text, _usersController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Stats Updated Online! 📈"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"))
        );
      }
    } finally {
      setState(() => _isStatsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Control Panel'),
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isStatsLoading ? null : _saveStats,
            icon: const Icon(Icons.save_rounded, color: Colors.blueAccent),
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: PlanService.plansNotifier,
        builder: (context, plans, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Revenue & Growth", Icons.insights),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildEditableStat("Total Revenue", _revenueController, "\$", Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildEditableStat("Active Users", _usersController, "", Colors.blue)),
                  ],
                ),
                if (_isStatsLoading) const LinearProgressIndicator(),
                const SizedBox(height: 32),
                _buildSectionHeader("Edit Subscription Plans", Icons.edit_note),
                const SizedBox(height: 16),
                ...plans.asMap().entries.map((entry) => _buildPlanEditorCard(entry.value, entry.key)),
                const SizedBox(height: 32),
                _buildSectionHeader("AI Feature Management", Icons.memory),
                const SizedBox(height: 16),
                _buildFeatureToggle("Email Scraping Engine", true),
                _buildFeatureToggle("LinkedIn Automation Bot", true),
                _buildFeatureToggle("WhatsApp API Gateway", false),
                _buildFeatureToggle("AI Voice Call Module", true),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF007AFF)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEditableStat(String title, TextEditingController controller, String prefix, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (prefix.isNotEmpty) Text(prefix, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPlanEditorCard(SubscriptionPlan plan, int planIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF007AFF).withAlpha(25),
                radius: 18,
                child: const Icon(Icons.workspace_premium, color: Color(0xFF007AFF), size: 18),
              ),
              const SizedBox(width: 12),
              Text(plan.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              Container(
                width: 80,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Text("\$", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: plan.price),
                        onChanged: (val) => plan.price = val,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text("Plan Features", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          ...plan.features.asMap().entries.map((fEntry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: fEntry.value),
                        onChanged: (val) => plan.features[fEntry.key] = val,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                      onPressed: () => setState(() => PlanService.removeFeature(planIndex, fEntry.key)),
                    ),
                  ],
                ),
              )),
          TextButton.icon(
            onPressed: () {
              setState(() => PlanService.addFeature(planIndex, "New Feature"));
            },
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text("Add Feature"),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF007AFF)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await PlanService.updatePlanInSupabase(plan);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("${plan.title} Plan Updated Online! 🚀"))
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"))
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save Changes"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFeatureToggle(String title, bool val) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        value: val,
        onChanged: (v) {},
        contentPadding: EdgeInsets.zero,
        activeThumbColor: const Color(0xFF34C759),
      ),
    );
  }
}
