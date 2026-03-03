import 'package:flutter/material.dart';
import '../models/match.dart';
import '../widgets/user_avatar.dart';

class RatePlayersModal extends StatefulWidget {
  final List<MatchParticipant> participantsToRate;
  final Function(List<Map<String, dynamic>>) onSubmit;

  const RatePlayersModal({
    super.key,
    required this.participantsToRate,
    required this.onSubmit,
  });

  @override
  State<RatePlayersModal> createState() => _RatePlayersModalState();
}

class _RatePlayersModalState extends State<RatePlayersModal> {
  int _currentPlayerIndex = 0;
  final List<Map<String, int>> _ratings = [];
  
  // Текущие оценки для каждого критерия (0 = не оценено, 1-5 = оценка)
  int _skillRating = 0; // Соответствие уровня игры рейтингу
  int _behaviorRating = 0; // Спортивное поведение
  int _communicationRating = 0; // Общение и атмосфера
  
  bool get _isCurrentPlayerRated => _skillRating > 0 && _behaviorRating > 0 && _communicationRating > 0;
  
  MatchParticipant get _currentParticipant => widget.participantsToRate[_currentPlayerIndex];
  
  void _nextPlayer() {
    if (!_isCurrentPlayerRated) return;
    
    // Сохраняем оценку текущего игрока
    _ratings.add({
      'skill': _skillRating,
      'behavior': _behaviorRating,
      'communication': _communicationRating,
    });
    
    if (_currentPlayerIndex < widget.participantsToRate.length - 1) {
      // Переходим к следующему игроку
      setState(() {
        _currentPlayerIndex++;
        _skillRating = 0;
        _behaviorRating = 0;
        _communicationRating = 0;
      });
    } else {
      // Все игроки оценены - формируем итоговый результат
      List<Map<String, dynamic>> reviews = [];
      for (int i = 0; i < widget.participantsToRate.length; i++) {
        final rating = _ratings[i];
        final totalScore = rating['skill']! + rating['behavior']! + rating['communication']!;
        reviews.add({
          'reviewee_id': widget.participantsToRate[i].userId,
          'all_score': totalScore,
        });
      }
      widget.onSubmit(reviews);
      Navigator.of(context).pop();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Оценка игроков',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222223),
                          letterSpacing: -1.2,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 0),
                      Text(
                        'Игрок ${_currentPlayerIndex + 1}/${widget.participantsToRate.length}',
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF89867E),
                          letterSpacing: -0.8,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFAEAEAE),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ваши оценки помогут формировать \nрейтинг надёжности.',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222223),
                      letterSpacing: -0.8,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 19),
                  
                  // Player card
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        // Player info
                        Row(
                          children: [
                            UserAvatar(
                              imageUrl: _currentParticipant.avatarUrl,
                              userName: _currentParticipant.name,
                              isDeleted: _currentParticipant.isDeleted,
                              radius: 22,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentParticipant.name,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF222223),
                                    letterSpacing: -0.8,
                                    height: 1.125,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentParticipant.formattedRating,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF00897B),
                                    letterSpacing: -0.8,
                                    height: 1.286,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 19),
                        
                        // Rating criteria
                        _buildRatingCriterion(
                          'Соответствие уровня игры рейтингу',
                          _skillRating,
                          (rating) => setState(() => _skillRating = rating),
                        ),
                        const SizedBox(height: 16),
                        Container(height: 1, color: const Color(0xFFECECEC)),
                        const SizedBox(height: 14),
                        
                        _buildRatingCriterion(
                          'Спортивное поведение',
                          _behaviorRating,
                          (rating) => setState(() => _behaviorRating = rating),
                        ),
                        const SizedBox(height: 16),
                        Container(height: 1, color: const Color(0xFFECECEC)),
                        const SizedBox(height: 14),
                        
                        _buildRatingCriterion(
                          'Общение и атмосфера во время игры',
                          _communicationRating,
                          (rating) => setState(() => _communicationRating = rating),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCurrentPlayerRated ? _nextPlayer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCurrentPlayerRated 
                            ? const Color(0xFF00897B) 
                            : const Color(0xFF7F8AC0),
                        disabledBackgroundColor: const Color(0xFF7F8AC0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPlayerIndex < widget.participantsToRate.length - 1 
                            ? 'Продолжить' 
                            : 'Отправить',
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRatingCriterion(String title, int rating, Function(int) onRatingChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF222223),
            letterSpacing: -1.2,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            final isSelected = starValue <= rating;
            
            return Padding(
              padding: EdgeInsets.only(right: index < 4 ? 11 : 0),
              child: GestureDetector(
                onTap: () => onRatingChanged(starValue),
                child: Container(
                  width: 24.5,
                  height: 24.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFF00897B) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF00897B) : const Color(0xFFD9D9D9),
                      width: 2,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

