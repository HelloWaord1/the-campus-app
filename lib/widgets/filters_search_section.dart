import 'package:flutter/material.dart';

class FiltersSearchSection extends StatelessWidget {
  final String? currentValue;
  final String? secondaryValue;
  final Function(String? value, {bool isCity}) onSearchResult;

  const FiltersSearchSection({
    super.key,
    this.currentValue,
    this.secondaryValue,
    required this.onSearchResult,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final res = await Navigator.of(context).pushNamed('/clubs_search') as Map<String, dynamic>?;
        if (res != null) {
          if (res.containsKey('clear')) {
            onSearchResult(null, isCity: false);
          } else if (res.containsKey('clubName')) {
            onSearchResult(res['clubName'] as String?, isCity: false);
          } else if (res.containsKey('city')) {
            onSearchResult(res['city'] as String?, isCity: true);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF89867E), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getDisplayText(),
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.8,
                  color: _isEmpty()
                      ? const Color(0xFF79766E)
                      : const Color(0xFF222223),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDisplayText() {
    if (currentValue != null && currentValue!.isNotEmpty) {
      return currentValue!;
    }
    if (secondaryValue != null && secondaryValue!.isNotEmpty) {
      return secondaryValue!;
    }
    return 'Поиск';
  }

  bool _isEmpty() {
    return (currentValue == null || currentValue!.isEmpty) &&
           (secondaryValue == null || secondaryValue!.isEmpty);
  }
}

