import 'package:flutter/material.dart';
import 'plan_service.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LeadFlow Plans')),
      body: ValueListenableBuilder(
        valueListenable: PlanService.plansNotifier,
        builder: (context, plans, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            child: Column(
              children: [
                const Text(
                  "Select Your Growth Plan",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -1),
                ),
                const SizedBox(height: 8),
                const Text("Unlock autonomous AI sales power", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                ...plans.map((plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildPlanCard(
                        context,
                        plan: plan,
                        color: plan.isPopular ? const Color(0xFF007AFF) : (plan.title == "Enterprise" ? const Color(0xFF1C1C1E) : Colors.blueGrey),
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, {required SubscriptionPlan plan, required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: plan.isPopular ? color : (isDark ? Colors.white10 : Colors.grey.shade100), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.isPopular)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: const Text("RECOMMENDED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          Text(plan.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("\$${plan.price}", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
              const Text("/mo", style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
          ...plan.features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: color, size: 18),
                    const SizedBox(width: 12),
                    Expanded(child: Text(f, style: const TextStyle(fontWeight: FontWeight.w500))),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("Upgrade Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
