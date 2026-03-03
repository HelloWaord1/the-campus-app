import 'package:flutter/material.dart';
import '../models/match.dart';
import 'match_score_input.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ScoreInputModalContent extends StatelessWidget {
  final List<TextEditingController> teamAControllers;
  final List<TextEditingController> teamBControllers;
  final List<MatchParticipant?> participantsA;
  final List<MatchParticipant?> participantsB;
  final Duration duration;
  final bool isLocked;
  final VoidCallback? onAddSet;
  final VoidCallback onSubmit;
  final bool isFormValid;
  final bool isSubmitting;
  final String titleText;
  final String subtitleText;
  final String submitButtonText;
  final VoidCallback? onClose;

  const ScoreInputModalContent({
    super.key,
    required this.teamAControllers,
    required this.teamBControllers,
    required this.participantsA,
    required this.participantsB,
    required this.duration,
    this.isLocked = false,
    this.onAddSet,
    required this.onSubmit,
    required this.isFormValid,
    this.isSubmitting = false,
    required this.titleText,
    required this.subtitleText,
    required this.submitButtonText,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 11,
            bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF222223),
                              letterSpacing: -0.8,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 0),
                          Text(
                            subtitleText,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF89867E),
                              letterSpacing: -0.32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: GestureDetector(
                        onTap: onClose ?? () => Navigator.of(context).pop(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/images/close_button_bg.svg',
                                width: 30,
                                height: 30,
                              ),
                              SvgPicture.asset(
                                'assets/images/close_icon_x.svg',
                                width: 11,
                                height: 11,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 23),
              Builder(
                builder: (context) {
                  // Нормализуем участников для 1x1: по одному в каждую команду
                  List<MatchParticipant?> normalizedA = List<MatchParticipant?>.from(participantsA);
                  List<MatchParticipant?> normalizedB = List<MatchParticipant?>.from(participantsB);
                  final merged = <MatchParticipant?>[
                    ...participantsA,
                    ...participantsB,
                  ].where((p) => p != null).toList();
                  if (merged.length == 2 && (participantsA.length != 1 || participantsB.length != 1)) {
                    normalizedA = [merged[0]];
                    normalizedB = [merged[1]];
                  }

                  return MatchScoreInput(
                    teamAControllers: teamAControllers,
                    teamBControllers: teamBControllers,
                    participantsA: normalizedA,
                    participantsB: normalizedB,
                    duration: duration,
                    isLocked: isLocked,
                    onAddSet: onAddSet,
                  );
                },
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: (!isFormValid || isSubmitting) ? null : onSubmit,
                  style: TextButton.styleFrom(
                    backgroundColor: (isFormValid && !isSubmitting)
                        ? const Color(0xFF262F63)
                        : const Color(0xFF7F8AC0),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          submitButtonText,
                          style: const TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.32,
                            color: Colors.white,
                          ),
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


