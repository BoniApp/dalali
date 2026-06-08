import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/models/property_registry_model.dart';
import 'package:dalali/services/data_service.dart';

class PropertyRegistryAdminScreen extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const PropertyRegistryAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Registry'),
      ),
      body: StreamBuilder<List<PropertyRegistryModel>>(
        stream: DataService().getPropertyRegistry(limit: 500),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('No registry entries yet.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final r = list[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(r.propertyType.name.substring(0, 1).toUpperCase()),
                ),
                title: Text(r.address),
                subtitle: Text('${r.landlordPhone} • ${r.rooms} rooms'),
                trailing: Chip(
                  label: Text(r.verificationStatus.name),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
