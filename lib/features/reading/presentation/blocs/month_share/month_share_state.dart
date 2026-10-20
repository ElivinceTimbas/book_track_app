import 'package:equatable/equatable.dart';

import '../../../domain/entities/month_image.dart';

enum MonthSharePhase { preparing, ready, sharing, failed }

class MonthShareState extends Equatable {
  const MonthShareState({
    this.phase = MonthSharePhase.preparing,
    this.completed = 0,
    this.total = 0,
    this.image,
    this.message,
  });
  final MonthSharePhase phase;
  final int completed;
  final int total;
  final MonthImage? image;
  final String? message;

  @override
  List<Object?> get props => [phase, completed, total, image, message];
}
