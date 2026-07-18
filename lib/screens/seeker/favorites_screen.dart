import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/widgets/property_card.dart';
import 'package:dalali/screens/shared/property_detail_screen.dart';
import 'package:provider/provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<AppState>().favoriteProperties;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No favorites yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Tap the heart icon on properties to save them', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) => PropertyCard(
                property: favorites[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PropertyDetailScreen(property: favorites[index]),
                  ),
                ),
              ),
            ),
    );
  }
}
