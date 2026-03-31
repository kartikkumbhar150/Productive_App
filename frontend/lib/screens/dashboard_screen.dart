import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/productivity_provider.dart';
import 'timeline_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
      context.read<ProductivityProvider>().loadDailyData(DateTime.now())
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<ProductivityProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());

          // Sample formula computation
          int totalTrackedSlots = provider.slots.length;
          int productiveSlots = provider.slots.where((s) => s.type.toString().endsWith('productive')).length;
          double prodPercent = totalTrackedSlots > 0 ? (productiveSlots / totalTrackedSlots) * 100 : 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Today\'s Productivity: ${prodPercent.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(color: Colors.green, value: productiveSlots.toDouble(), title: 'Prod'),
                      PieChartSectionData(color: Colors.red, value: (totalTrackedSlots - productiveSlots).toDouble(), title: 'Waste'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Uneditable task list
              const Text('Immutable Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              for (var task in provider.tasks)
                ListTile(
                  title: Text(task.taskName, style: TextStyle(decoration: task.isCompleted ? TextDecoration.lineThrough : null)),
                  trailing: Checkbox(
                    value: task.isCompleted,
                    onChanged: (val) {
                      if (val == true && !task.isCompleted) {
                        provider.completeTask(task);
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.timer),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TimelineScreen()));
        },
      ),
    );
  }
}
