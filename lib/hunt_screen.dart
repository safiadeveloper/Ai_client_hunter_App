import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agent_service.dart';
import 'dart:math';

class HunterService {
  static const String _serpApiKey = '228daae02010ca38796527cd7f39b634f0e34c12';

  static Future<List<dynamic>> huntLeads(String query, {
    String platform = 'Google Maps', 
    bool huntOwners = true,
    String countryCode = 'us'
  }) async {
    try {
      String cleanQuery = query.replaceAll('"', '');
      String finalQuery = cleanQuery;
      String endpoint = 'search';

      // Dynamic Query Builder: Ensure optimized Boolean search
      String ownerFilter = huntOwners 
          ? 'AND ("owner" OR "CEO" OR "Founder")' 
          : '';

      switch (platform) {
        case 'Google Maps':
          endpoint = 'places';
          finalQuery = cleanQuery; 
          break;
        case 'LinkedIn':
          // AS REQUESTED: site:linkedin.com/in/ "roofers" AND ("owner" OR "CEO")
          finalQuery = 'site:linkedin.com/in/ "$cleanQuery" $ownerFilter';
          break;
        case 'Facebook':
          finalQuery = 'site:facebook.com/ "email" AND "$cleanQuery" -groups';
          break;
        case 'Instagram':
          finalQuery = 'site:instagram.com "$cleanQuery" ("@gmail.com" OR "@outlook.com")';
          break;
        case 'Twitter/X':
          finalQuery = 'site:twitter.com "$cleanQuery" "contact"';
          break;
        case 'TikTok':
          finalQuery = 'site:tiktok.com/@ "$cleanQuery" "business email"';
          break;
        case 'Yellow Pages':
          finalQuery = 'site:yellowpages.com "$cleanQuery"';
          break;
        case 'Yelp':
          finalQuery = 'site:yelp.com "$cleanQuery"';
          break;
        case 'Reddit':
          finalQuery = 'site:reddit.com/r/ "$cleanQuery" ("AMAA" OR "Owner" OR "Founder")';
          break;
        case 'Clutch':
          finalQuery = 'site:clutch.co "$cleanQuery" "Verified"';
          break;
        case 'Crunchbase':
          finalQuery = 'site:crunchbase.com/person "$cleanQuery" founder';
          break;
        default:
          finalQuery = '"$cleanQuery" $ownerFilter';
      }

      final url = Uri.parse('https://google.serper.dev/$endpoint');
      
      debugPrint("🚀 [AI HUNTER] DISPATCHING: $finalQuery on $platform ($endpoint)");

      final response = await http.post(
        url,
        headers: {
          'X-API-KEY': _serpApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'q': finalQuery,
          'num': endpoint == 'places' ? 20 : 100, 
          'gl': countryCode.toLowerCase(),
        }),
      );

      // IMMEDIATE ACTION: Log the raw response for debugging
      debugPrint("📥 [AI HUNTER] RAW RESPONSE CODE: ${response.statusCode}");
      debugPrint("📥 [AI HUNTER] RAW BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> results = [];
        
        // Regex Hard-Scan: Run on the entire JSON response string to find "hidden" emails/phones
        final String rawJson = response.body;
        final List<String> allEmails = _extractAllEmails(rawJson);
        final List<String> allPhones = _extractAllPhones(rawJson);
        
        debugPrint("🔍 [AI HUNTER] Regex Scan found ${allEmails.length} emails and ${allPhones.length} phones in raw JSON.");

        if (endpoint == 'places') {
          results = (data['places'] ?? []).map((e) {
            e['source_platform'] = 'Google Maps';
            // Enrich with Regex scan from its own JSON segment
            String itemJson = jsonEncode(e);
            e['email'] ??= _extractEmail(itemJson);
            e['phone'] ??= _extractPhone(itemJson);
            return e;
          }).toList();
        } else {
          results = (data['organic'] ?? []).map((e) {
            e['source_platform'] = platform;
            
            // Regex Hard-Scan on individual result
            String itemJson = jsonEncode(e);
            e['email'] = _extractEmail(itemJson);
            e['phone'] = _extractPhone(itemJson);
            
            // If still null, try snippet specifically
            e['email'] ??= _extractEmail(e['snippet'] ?? '');
            
            return e;
          }).toList();
        }

        if (results.isEmpty) {
          debugPrint("⚠️ [AI HUNTER] Query returned 0 results. Checking for blockers...");
          if (rawJson.toLowerCase().contains("captcha") || rawJson.toLowerCase().contains("unusual traffic")) {
            debugPrint("🛑 [CRITICAL] Captcha/Bot Detection detected. API Key might be flagged or limit reached.");
          }
        }

        return results;
      } else {
        debugPrint("❌ [AI HUNTER] API Error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("❌ [AI HUNTER] Fatal Error: $e");
      return [];
    }
  }

  static String? _extractEmail(String text) {
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}');
    final match = emailRegex.firstMatch(text);
    return match?.group(0);
  }

  static List<String> _extractAllEmails(String text) {
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}');
    return emailRegex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  static String? _extractPhone(String text) {
    final phoneRegex = RegExp(r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}');
    final match = phoneRegex.firstMatch(text);
    return match?.group(0);
  }

  static List<String> _extractAllPhones(String text) {
    final phoneRegex = RegExp(r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}');
    return phoneRegex.allMatches(text).map((m) => m.group(0)!).toList();
  }
}

class HuntScreen extends StatefulWidget {
  const HuntScreen({super.key});

  @override
  State<HuntScreen> createState() => _HuntScreenState();
}

class _HuntScreenState extends State<HuntScreen> with SingleTickerProviderStateMixin {
  bool isHunting = false;
  late AnimationController _pulseController;
  final TextEditingController _queryController = TextEditingController();
  final supabase = Supabase.instance.client;

  List<dynamic> _foundLeads = [];
  int totalScanned = 0;
  bool huntOwners = true;
  String selectedCountry = 'US';

  final List<Map<String, String>> countries = [
    {'name': 'United States', 'code': 'US'},
    {'name': 'United Kingdom', 'code': 'GB'},
    {'name': 'Canada', 'code': 'CA'},
    {'name': 'Australia', 'code': 'AU'},
    {'name': 'United Arab Emirates', 'code': 'AE'},
    {'name': 'Pakistan', 'code': 'PK'},
    {'name': 'India', 'code': 'IN'},
    {'name': 'Germany', 'code': 'DE'},
  ];

  final List<Map<String, dynamic>> platforms = [
    {'name': 'Google Maps', 'icon': Icons.map, 'color': Colors.red},
    {'name': 'LinkedIn', 'icon': Icons.business, 'color': Colors.blue},
    {'name': 'Facebook', 'icon': Icons.facebook, 'color': Colors.indigo},
    {'name': 'Instagram', 'icon': Icons.camera_alt, 'color': Colors.pink},
    {'name': 'Twitter/X', 'icon': Icons.close, 'color': Colors.black},
    {'name': 'TikTok', 'icon': Icons.video_library, 'color': Colors.black},
    {'name': 'Yellow Pages', 'icon': Icons.pages, 'color': Colors.orange},
    {'name': 'Yelp', 'icon': Icons.star, 'color': Colors.redAccent},
    {'name': 'Reddit', 'icon': Icons.forum, 'color': Colors.deepOrange},
    {'name': 'Clutch', 'icon': Icons.rocket_launch, 'color': Colors.deepPurple},
  ];

  List<String> selectedPlatforms = ['Google Maps', 'LinkedIn'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _startGlobalHunt() async {
    if (_queryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("What are you looking for?")));
      return;
    }

    setState(() {
      isHunting = true;
      _pulseController.repeat(reverse: true);
      _foundLeads = [];
    });

    final user = supabase.auth.currentUser;
    final profile = user != null ? await supabase.from('profiles').select().eq('id', user.id).maybeSingle() : null;

    try {
      for (var platformName in selectedPlatforms) {
        if (!isHunting) break;
        
        final results = await HunterService.huntLeads(
          _queryController.text,
          platform: platformName,
          huntOwners: huntOwners,
          countryCode: selectedCountry,
        );

        setState(() {
          _foundLeads.addAll(results);
          totalScanned += results.length;
        });

        if (profile != null && results.isNotEmpty) {
          for (var lead in results) {
            AgentService.processLeadsWithDelay([lead], profile, source: platformName);

            // 🎲 20 se 60 seconds ka random delay (std. hata diya gaya hai)
            final randomSeconds = 20 + Random().nextInt(41);
            await Future.delayed(Duration(seconds: randomSeconds));
          }
        }
      }
    } catch (e) {
      debugPrint("Hunt Failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          isHunting = false;
          _pulseController.stop();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Hunt Complete! Found ${_foundLeads.length} leads. AI is contacting them..."),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('GLOBAL AI HUNTER', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAgentBanner(),
            const SizedBox(height: 25),
            _buildCountrySelector(),
            const SizedBox(height: 20),
            _buildSearchBox(),
            const SizedBox(height: 25),
            const Text("Select Target Platforms", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            _buildPlatformSelection(),
            const SizedBox(height: 20),
            _buildTargetToggle(),
            const SizedBox(height: 30),
            if (isHunting) _buildLiveLoader(),
            if (_foundLeads.isNotEmpty) _buildResultsList(),
            if (!isHunting && _foundLeads.isEmpty) _buildWelcomeSection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isHunting ? () => setState(() => isHunting = false) : _startGlobalHunt,
        label: Text(isHunting ? "STOP AGENT" : "START GLOBAL HUNT"),
        icon: Icon(isHunting ? Icons.stop_circle : Icons.rocket_launch),
        backgroundColor: isHunting ? Colors.redAccent : const Color(0xFF007AFF),
      ),
    );
  }

  Widget _buildAgentBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isHunting ? [const Color(0xFF007AFF), Colors.blueAccent] : [Colors.black, Colors.grey.shade900]),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.2).animate(_pulseController),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHunting ? "AI AGENT: EXTRACTING OWNERS" : "AI AGENT: IDLE",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  isHunting ? "Scanning $selectedCountry across ${selectedPlatforms.length} platforms..." : "Deploy AI to find business owners worldwide.",
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountrySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Target Country", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCountry,
              isExpanded: true,
              items: countries.map((c) => DropdownMenuItem(value: c['code'], child: Text(c['name']!))).toList(),
              onChanged: (v) => setState(() => selectedCountry = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        controller: _queryController,
        decoration: const InputDecoration(
          hintText: "e.g. Roofers in London or Tech CEOs",
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.blue),
        ),
      ),
    );
  }

  Widget _buildPlatformSelection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: platforms.map((p) {
        bool selected = selectedPlatforms.contains(p['name']);
        return InkWell(
          onTap: () {
            setState(() {
              if (selected) {
                if (selectedPlatforms.length > 1) selectedPlatforms.remove(p['name']);
              } else {
                selectedPlatforms.add(p['name']);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? p['color'] : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: selected ? Colors.transparent : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(p['icon'], size: 14, color: selected ? Colors.white : Colors.black54),
                const SizedBox(width: 8),
                Text(p['name'], style: TextStyle(color: selected ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTargetToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle, color: Colors.blue),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Target Owners/Decision Makers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text("Filter results for founders and CEOs", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Switch.adaptive(
            value: huntOwners,
            activeColor: const Color(0xFF007AFF),
            onChanged: (v) => setState(() => huntOwners = v),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLoader() {
    return Column(
      children: [
        const LinearProgressIndicator(backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF))),
        const SizedBox(height: 10),
        Text("AI is deep-scanning ${selectedPlatforms.join(', ')}...", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Leads Discovered", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("${_foundLeads.length} Total", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 15),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _foundLeads.length > 50 ? 50 : _foundLeads.length,
          itemBuilder: (context, index) {
            final lead = _foundLeads[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade100)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Icon(_getIconFor(lead['source_platform']), size: 16, color: Colors.blue),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lead['title'] ?? lead['name'] ?? 'Target Lead', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(lead['source_platform'] ?? 'Web Search', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getIconFor(String? platform) {
    if (platform == null) return Icons.public;
    try {
      return platforms.firstWhere((e) => e['name'] == platform)['icon'];
    } catch (_) {
      return Icons.public;
    }
  }

  Widget _buildWelcomeSection() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Icon(Icons.public, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 15),
          const Text("Search globally across all platforms.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const Text("AI will automatically hunt and contact owners.", style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}
