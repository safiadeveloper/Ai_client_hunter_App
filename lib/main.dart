import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'hunt_screen.dart';
import 'discovery_screen.dart';
import 'hot_leads_screen.dart';
import 'config_screen.dart';
import 'chat_list_screen.dart';
import 'admin_dashboard.dart';
import 'subscription_screen.dart';
import 'business_profile_screen.dart';
import 'agent_service.dart';

// یہ وہ فنکشن ہے جو بیک گراؤنڈ میں خود بخود چلے گا
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("🤖 Background Agent checking for work...");
    
    try {
      // ⚠️ یہ لائن لازمی ہے، ورنہ بیک گراؤنڈ میں ڈیٹا بیس کام نہیں کرے گا
      await Supabase.initialize(
        url: 'https://iomnaxzmvrewehicplwh.supabase.co',
        anonKey: 'sb_publishable_yRwX0DAGcMJskOkY2i_YWA_wgs3vL1l',
      );

      // Outreach اور Follow-up دونوں ٹاسک رن کریں
      await AgentService.runContinuousOutreach();
      await AgentService.runAutoFollowUp(); 
      
      return Future.value(true);
    } catch (e) {
      debugPrint("❌ Background Task Error: $e");
      return Future.value(false);
    }
  });
}

// مستقل ایجنٹ جو ایپ کھلی رہنے پر چلتا رہے گا
void startPermanentAgent() async {
  debugPrint("🚀 Permanent Agent Started...");
  
  while (true) {
    try {
      // 1. کام چیک کرو
      await AgentService.runContinuousOutreach();
      
      // 2. مناسب وقفہ (مثلاً 15 منٹ)
      debugPrint("😴 Agent taking a 15-minute nap...");
    } catch (e) {
      debugPrint("❌ Permanent Agent Error: $e");
    }
    
    await Future.delayed(const Duration(minutes: 15));
    // لوپ دوبارہ چلے گا، ایجنٹ کبھی فارغ نہیں بیٹھے گا
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://iomnaxzmvrewehicplwh.supabase.co',
    anonKey: 'sb_publishable_yRwX0DAGcMJskOkY2i_YWA_wgs3vL1l',
  );

  // ایجنٹ کو فوراً ایک بار چلائیں (بغیر کسی انتظار کے)
  AgentService.runContinuousOutreach();

  // Workmanager شروع کریں (بیک گراؤنڈ ٹاسکس کے لیے)
  await Workmanager().initialize(callbackDispatcher);

  // 1. پرانا ٹاسک کینسل کریں تاکہ فریش اسٹارٹ ہو
  await Workmanager().cancelAll();

  // 2. فوری ایک بار چلانے کے لیے "OneOffTask"
  await Workmanager().registerOneOffTask(
    "urgent_start", 
    "autoAgentTask"
  );

  // 3. پھر اسے شیڈول پر ڈال دیں
  await Workmanager().registerPeriodicTask(
    "24_7_Agent", 
    "autoAgentTask",
    frequency: const Duration(minutes: 15), // ہر 15 منٹ بعد
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    constraints: Constraints(
      networkType: NetworkType.connected, // صرف انٹرنیٹ ہونے پر چلے
    ),
  );

  // مستقل ایجنٹ شروع کریں
  startPermanentAgent();

  runApp(const LeadFlowAIApp());
}

class LeadFlowAIApp extends StatefulWidget {
  const LeadFlowAIApp({super.key});

  @override
  State<LeadFlowAIApp> createState() => _LeadFlowAIAppState();
}

class _LeadFlowAIAppState extends State<LeadFlowAIApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeadFlow AI',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFF),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF), brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF), brightness: Brightness.dark),
      ),
      home: SplashScreen(onThemeChanged: toggleTheme),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const MainNavigationScreen({super.key, required this.onThemeChanged});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  void _checkAdmin() async {
    await AdminService.checkAdminStatus();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> screens = [
      const HuntScreen(),
      const DiscoveryLeadsScreen(),
      const HotLeadsScreen(),
      const ChatListScreen(),
      AccountMenuScreen(onThemeChanged: widget.onThemeChanged),
    ];

    return Scaffold(
      extendBody: false, // Changed from true to false
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: NavigationBar(
            height: 65,
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              _buildNavDest(Icons.radar_rounded, 'Hunt', isDark),
              _buildNavDest(Icons.travel_explore_rounded, 'Discovery', isDark),
              _buildNavDest(Icons.whatshot_rounded, 'Hot Leads', isDark),
              _buildNavDest(Icons.chat_bubble_rounded, 'Chats', isDark),
              _buildNavDest(Icons.account_circle_rounded, 'Menu', isDark),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildNavDest(IconData icon, String label, bool isDark) {
    return NavigationDestination(
      icon: Icon(icon, color: isDark ? Colors.white70 : Colors.black87),
      selectedIcon: Icon(icon, color: const Color(0xFF007AFF)),
      label: label,
    );
  }
}

class AccountMenuScreen extends StatelessWidget {
  final Function(bool) onThemeChanged;
  const AccountMenuScreen({super.key, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Account & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildMenuSection("AI Business Profile"),
          _buildMenuTile(context, "My Business Profile", Icons.business_center_rounded, const Color(0xFF007AFF), () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BusinessProfileScreen()))),
          const SizedBox(height: 24),
          _buildMenuSection("Preferences"),
          _buildMenuTile(context, "Setup Agent", Icons.tune_rounded, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ConfigScreen()))),
          _buildMenuTile(context, "Subscription Plans", Icons.card_membership_rounded, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SubscriptionScreen()))),
          
          if (AdminService.currentUserIsAdmin) ...[
            const SizedBox(height: 24),
            _buildMenuSection("Administration"),
            _buildMenuTile(context, "Admin Dashboard", Icons.admin_panel_settings_rounded, const Color(0xFF1C1C1E), () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminDashboard()))),
          ],
          
          const SizedBox(height: 24),
          _buildMenuSection("App Settings"),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.dark_mode_rounded, color: isDark ? Colors.white : Colors.black87),
            title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: Switch(value: isDark, onChanged: onThemeChanged, activeThumbColor: const Color(0xFF007AFF)),
          ),
          _buildMenuTile(context, "Logout", Icons.logout_rounded, Colors.redAccent, () async {
             await Supabase.instance.client.auth.signOut();
             if (context.mounted) {
               Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen(onThemeChanged: onThemeChanged)),
                  (route) => false,
                );
             }
          }),
          const SizedBox(height: 100), // Added extra space at bottom to ensure scrolling past bottom bar
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.5)),
    );
  }

  Widget _buildMenuTile(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? Colors.white.withAlpha(10) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50))),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
      ),
    );
  }
}
