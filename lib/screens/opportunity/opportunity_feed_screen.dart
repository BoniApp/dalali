import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/widgets/property_card.dart';

class OpportunityFeedScreen extends StatelessWidget {
  const OpportunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final properties = appState.properties;

    // Simple opportunity scoring
    final recentlyListed = properties.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final fastMoving = properties.where((p) => p.inquiryCount > 2).toList();
    final highDemand = properties.where((p) => p.viewCount > 20).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.opportunityFeed),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(l10n.recentlyListed),
              SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: recentlyListed.take(10).length,
                  itemBuilder: (context, i) => SizedBox(
                    width: 260,
                    child: PropertyCard(property: recentlyListed[i]),
                  ),
                ),
              ),
              _SectionTitle(l10n.fastMoving),
              SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: fastMoving.take(10).length,
                  itemBuilder: (context, i) => SizedBox(
                    width: 260,
                    child: PropertyCard(property: fastMoving[i]),
                  ),
                ),
              ),
              _SectionTitle(l10n.highDemandAreas),
              SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: highDemand.take(10).length,
                  itemBuilder: (context, i) => SizedBox(
                    width: 260,
                    child: PropertyCard(property: highDemand[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
