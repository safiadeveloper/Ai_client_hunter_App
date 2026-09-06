import 'package:flutter/material.dart';
import 'ai_handler.dart';

class AITestScreen extends StatefulWidget {
  const AITestScreen({super.key});

  @override
  State<AITestScreen> createState() => _AITestScreenState();
}

class _AITestScreenState extends State<AITestScreen> {
  String aiResult = "AI ka message yahan nazar ayega...";
  bool isLoading = false;

  void _testAI() async {
    setState(() => isLoading = true);
    
    // Test ke liye farzi data
    try {
      String result = await AIHandler.generateEmail(
        targetName: "John Doe",
        targetBusiness: "Modern Gym",
        targetLocation: "Dubai",
      );

      setState(() {
        aiResult = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        aiResult = "Error: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LeadFlow AI Engine")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("AI Testing Mode", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: isLoading 
                ? const Center(child: CircularProgressIndicator())
                : Text(aiResult, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _testAI,
              icon: const Icon(Icons.bolt),
              label: const Text("Generate Test Message"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
