import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/time_slot.dart';
import '../providers/productivity_provider.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  // Generate 72 slots of 20 minutes for a day
  List<String> _generateTimeBlocks() {
    List<String> blocks = [];
    DateTime start = DateTime(2020, 1, 1, 0, 0); // Arbitrary day
    for(int i = 0; i < 72; i++) {
        String from = DateFormat('HH:mm').format(start);
        start = start.add(const Duration(minutes: 20));
        String to = DateFormat('HH:mm').format(start);
        blocks.add('$from-$to');
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _generateTimeBlocks();

    return Scaffold(
      appBar: AppBar(title: const Text('20-Min Tracking Timeline')),
      body: ListView.builder(
        itemCount: blocks.length,
        itemBuilder: (context, index) {
          return Card(
             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             child: ListTile(
               title: Text(blocks[index], style: const TextStyle(fontWeight: FontWeight.bold)),
               subtitle: const Text('Quick Add Slot...'),
               trailing: IconButton(
                 icon: const Icon(Icons.add_circle, color: Colors.deepPurpleAccent),
                 onPressed: () {
                   _showFastEntryDialog(context, blocks[index]);
                 },
               )
             )
          );
        },
      )
    );
  }

  void _showFastEntryDialog(BuildContext context, String timeRange) {
    // A real app would use a bottom sheet or customized friction-less modal
    showDialog(
      context: context, 
      builder: (ctx) {
         return AlertDialog(
            title: Text('Log $timeRange'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    context.read<ProductivityProvider>().addTimeSlot(TimeSlot(
                      date: DateTime.now().toIso8601String(),
                      timeRange: timeRange,
                      taskSelected: 'Deep Work',
                      category: 'Focus',
                      type: ProductivityType.productive
                    ));
                    Navigator.pop(ctx);
                  }, 
                  child: const Text('Productive (Deep Work)')
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                     context.read<ProductivityProvider>().addTimeSlot(TimeSlot(
                      date: DateTime.now().toIso8601String(),
                      timeRange: timeRange,
                      taskSelected: 'Scrolling',
                      category: 'Social Media',
                      type: ProductivityType.wasted
                    ));
                    Navigator.pop(ctx);
                  }, 
                  child: const Text('Wasted')
                )
              ]
            )
         );
      }
    );
  }
}
