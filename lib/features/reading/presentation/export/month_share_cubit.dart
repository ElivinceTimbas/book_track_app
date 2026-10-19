import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/calendar_month.dart';
import '../../domain/month_export.dart';

typedef ShareImage = Future<ShareResult> Function(ShareParams params);

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

class MonthShareCubit extends Cubit<MonthShareState> {
  MonthShareCubit(this.month, this._exporter, this._share)
    : super(const MonthShareState());
  final CalendarMonth month;
  final MonthExporter _exporter;
  final ShareImage _share;
  bool _preparing = false;

  Future<void> prepare() async {
    if (isClosed || _preparing || state.phase == MonthSharePhase.sharing) {
      return;
    }
    _preparing = true;
    emit(const MonthShareState());
    try {
      final image = await _exporter.prepare(month, (completed, total) {
        if (!isClosed) {
          emit(MonthShareState(completed: completed, total: total));
        }
      });
      if (!isClosed) {
        emit(MonthShareState(phase: MonthSharePhase.ready, image: image));
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          MonthShareState(
            phase: MonthSharePhase.failed,
            message: error is MonthExportException
                ? error.message
                : 'The month image couldn’t be prepared. Please retry.',
          ),
        );
      }
    } finally {
      _preparing = false;
    }
  }

  Future<void> share(Rect origin) async {
    final image = state.image;
    if (isClosed ||
        image == null ||
        state.phase == MonthSharePhase.sharing ||
        origin.isEmpty ||
        !origin.isFinite) {
      return;
    }
    emit(MonthShareState(phase: MonthSharePhase.sharing, image: image));
    String? message;
    try {
      final result = await _share(
        ShareParams(
          files: [
            XFile.fromData(
              image.bytes,
              mimeType: 'image/png',
              name: month.fileName,
            ),
          ],
          fileNameOverrides: [month.fileName],
          text: image.summary,
          title: 'Folio — ${month.fileName.substring(6, 13)}',
          sharePositionOrigin: origin,
        ),
      );
      message = switch (result.status) {
        ShareResultStatus.dismissed => 'Sharing cancelled.',
        ShareResultStatus.unavailable =>
          'Share sheet closed. Sharing could not be confirmed.',
        ShareResultStatus.success => 'Share action selected.',
      };
    } on MissingPluginException {
      message = 'Sharing needs a full app rebuild after installation. Stop and rebuild Folio, then try again.';
    } catch (_) {
      message = 'The share sheet couldn’t open. Please try Share image again.';
    }
    if (!isClosed) {
      emit(
        MonthShareState(
          phase: MonthSharePhase.ready,
          image: image,
          message: message,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _exporter.dispose();
    return super.close();
  }
}
