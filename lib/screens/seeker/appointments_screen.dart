import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/providers/app_state.dart';
// import 'package:dalali/models/appointment_model.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:provider/provider.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<AppState>().userAppointments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: appointments.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No appointments yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final a = appointments[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                a.propertyTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Helpers.appointmentStatusColor(a.status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                Helpers.appointmentStatusLabel(a.status),
                                style: TextStyle(
                                  color: Helpers.appointmentStatusColor(a.status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(Helpers.formatDate(a.scheduledDate)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(a.seekerName),
                          ],
                        ),
                        if (a.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Notes: ${a.notes}', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
