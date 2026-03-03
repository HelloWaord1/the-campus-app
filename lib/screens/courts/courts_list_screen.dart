import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/club.dart';
import '../../services/api_service.dart';
import 'club_details_screen.dart';

class CourtsListScreen extends StatefulWidget {
  const CourtsListScreen({super.key});

  @override
  State<CourtsListScreen> createState() => _CourtsListScreenState();
}

class _CourtsListScreenState extends State<CourtsListScreen> {
  late Future<List<Club>> _clubsFuture;

  @override
  void initState() {
    super.initState();
    _clubsFuture = _fetchClubs();
  }

  Future<List<Club>> _fetchClubs() async {
    try {
      // Используем реальный API для получения клубов
      final response = await ApiService.getClubs();
      return response.clubs;
    } catch (e) {
      // В случае ошибки возвращаем тестовые данные с URL изображениями
      print('Ошибка загрузки клубов: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset('assets/images/back_icon.svg', width: 24, height: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Бронирование корта',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: SvgPicture.asset('assets/icons/filter_icon.svg', width: 24, height: 24),
            onPressed: () {
              // TODO: Implement filter logic
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
            child: Text(
              'Выберите клуб',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222223),
                letterSpacing: -0.32,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Club>>(
              future: _clubsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Клубы не найдены'));
                }

                final clubs = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: clubs.length,
                  itemBuilder: (context, index) {
                    return _ClubCard(club: clubs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  final Club club;

  const _ClubCard({required this.club});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubDetailsScreen(club: club),
          ),
        );
      },
      child: Container(
        height: 96,
        width: 358,
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD9D9D9)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  image: club.photoUrl != null && club.photoUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(club.photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: club.photoUrl == null || club.photoUrl!.isEmpty
                      ? const Color(0xFFE0E0E0)
                      : null,
                ),
                child: club.photoUrl == null || club.photoUrl!.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.sports_tennis,
                          size: 24,
                          color: Color(0xFF9E9E9E),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 0.0),
                    child: Text(
                      club.name,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222223),
                        letterSpacing: -0.28,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    club.address.isNotEmpty ? club.address : (club.city ?? 'Адрес не указан'),
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF89867E),
                      letterSpacing: -0.28,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    'от ${club.minPrice?.toStringAsFixed(0) ?? 'N/A'} ₽/час',
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF89867E),
                      letterSpacing: -0.28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
