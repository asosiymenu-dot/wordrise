import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'focus_provider.dart';


class FocusSetupScreen extends StatefulWidget {
  const FocusSetupScreen({super.key});

  @override
  State<FocusSetupScreen> createState() => _FocusSetupScreenState();
}

class _FocusSetupScreenState extends State<FocusSetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Sync tab with initial goal type
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FocusProvider>();
      if (provider.goalType == FocusGoalType.words) {
        _tabController.index = 1;
      }
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<FocusProvider>().setGoalType(
          _tabController.index == 0 ? FocusGoalType.time : FocusGoalType.words,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startFocusMode() {
    final provider = context.read<FocusProvider>();
    provider.startFocus();
    
    Navigator.pop(context); // Go back, wrapper will take over
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Mode'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.timer), text: 'Vaqt (Time)'),
            Tab(icon: Icon(Icons.spellcheck), text: 'So\'zlar (Words)'),
          ],
        ),
      ),
      body: Consumer<FocusProvider>(
        builder: (context, provider, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildTimeSetup(provider),
              _buildWordsSetup(provider),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _startFocusMode,
          child: const Text(
            'Qulfni boshlash (Start Focus)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSetup(FocusProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_clock, size: 80, color: Colors.blueGrey),
          const SizedBox(height: 24),
          const Text(
            'Belgilangan vaqt tugamaguncha telefondan foydalana olmaysiz!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          Text(
            '${provider.targetMinutes} daqiqa',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: provider.targetMinutes.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            label: '${provider.targetMinutes} daqiqa',
            onChanged: (val) => provider.setTargetMinutes(val.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildWordsSetup(FocusProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book, size: 80, color: Colors.blueGrey),
          const SizedBox(height: 24),
          const Text(
            'Belgilangan miqdordagi so\'zlarni o\'rganmaguncha telefondan foydalana olmaysiz!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          Text(
            '${provider.targetWords} ta so\'z',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: provider.targetWords.toDouble(),
            min: 5,
            max: 200,
            divisions: 39,
            label: '${provider.targetWords} ta',
            onChanged: (val) => provider.setTargetWords(val.toInt()),
          ),
        ],
      ),
    );
  }
}
