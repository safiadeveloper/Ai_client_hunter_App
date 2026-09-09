import 'package:supabase_flutter/supabase_flutter.dart';
import 'hunt_screen.dart';
import 'agent_service.dart';

/// Specialized Hunting Modules as requested
class AdvancedHunting {
  static final _supabase = Supabase.instance.client;

  /// 1. Social Scraper: Hunt for business owners using niche-based hashtags
  static Future<List<dynamic>> socialScraper(String niche, String platform) async {
    // Custom query focusing on hashtags and "owner" mentions
    String query = "#$niche \"business owner\"";
    if (platform == 'Instagram') query = "site:instagram.com #$niche \"DM for business\"";
    if (platform == 'TikTok') query = "site:tiktok.com #$niche \"business owner\"";
    
    return await HunterService.huntLeads(query, platform: platform);
  }

  /// 2. LinkedIn Specialist: Find Decision Makers for existing leads (Enrichment)
  static Future<void> linkedinSpecialistEnrich(Map<String, dynamic> lead) async {
    String businessName = lead['name'] ?? '';
    if (businessName.isEmpty) return;

    String query = "\"$businessName\" (Founder OR CEO OR Owner)";
    final results = await HunterService.huntLeads(query, platform: 'LinkedIn', huntOwners: true);
    
    if (results.isNotEmpty) {
      final bestMatch = results.first;
      await _supabase.from('leads').update({
        'metadata': {
          ...?lead['metadata'],
          'linkedin_profile': bestMatch['link'],
          'decision_maker': bestMatch['title'],
          'enrichment_source': 'LinkedIn Specialist'
        }
      }).eq('id', lead['id']);
    }
  }

  /// 3. Local SEO Hunter: Scan Google Maps for low ratings (< 3.5)
  static Future<List<dynamic>> localSEOHunter(String niche, String countryCode) async {
    final results = await HunterService.huntLeads(
      niche, 
      platform: 'Google Maps', 
      countryCode: countryCode
    );

    // Filter for low ratings which indicate a need for SEO/Reputation services
    return results.where((place) {
      double rating = (place['rating'] ?? 5.0).toDouble();
      return rating < 3.5;
    }).toList();
  }
}

/// Autonomous Decision Engine (Manager Function)
class AutonomousManager {
  static final _supabase = Supabase.instance.client;

  /// Decides which platform to hunt next based on simple success heuristics
  static Future<void> runManagerCycle(Map<String, dynamic> profile) async {
    String niche = profile['business_name'] ?? 'Local Business'; // Using business name as niche if not set
    String country = 'us'; // Default

    // Logic: Pick platform based on current rotation or success
    // In a real scenario, we'd query past lead conversion rates here.
    List<String> platforms = ['Google Maps', 'Instagram', 'LinkedIn', 'Facebook', 'TikTok'];
    String selectedPlatform = platforms[DateTime.now().minute % platforms.length];

    print("🤖 Manager Decision: Hunting $niche on $selectedPlatform");

    List<dynamic> leads = [];
    if (selectedPlatform == 'Google Maps') {
      leads = await AdvancedHunting.localSEOHunter(niche, country);
    } else if (['Instagram', 'TikTok', 'Facebook'].contains(selectedPlatform)) {
      leads = await AdvancedHunting.socialScraper(niche, selectedPlatform);
    } else {
      leads = await HunterService.huntLeads(niche, platform: selectedPlatform);
    }

    if (leads.isNotEmpty) {
      await AgentService.processLeadsWithDelay(leads, profile, source: "AI_Manager_$selectedPlatform");
    }
  }
}

/// Cross-Platform Logic: Updates missing social handles for existing rows
class CrossPlatformEnricher {
  static Future<void> enrichLeadSocials(Map<String, dynamic> lead) async {
    final supabase = Supabase.instance.client;
    String name = lead['name'] ?? '';
    if (name.isEmpty) return;

    // List of social platforms to check for
    Map<String, String> platformsToCheck = {
      'instagram': 'Instagram',
      'facebook': 'Facebook',
    };

    for (var entry in platformsToCheck.entries) {
      // If the column doesn't exist or is empty in metadata/table
      if (lead[entry.key] == null) {
        final results = await HunterService.huntLeads("\"$name\" official ${entry.value}", platform: entry.value);
        if (results.isNotEmpty) {
          await supabase.from('leads').update({
            entry.key: results.first['link']
          }).eq('id', lead['id']);
        }
      }
    }
    
    // Also run LinkedIn Specialist if it's not a LinkedIn lead
    if (lead['source'] != 'LinkedIn') {
      await AdvancedHunting.linkedinSpecialistEnrich(lead);
    }
  }
}
