import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/image_share_exception.dart';
import '../../../../../core/errors/month_export_exception.dart';
import '../../../domain/entities/calendar_month.dart';
import '../../../domain/entities/image_share_result.dart';
import '../../../domain/repositories/image_sharer.dart';
import '../../../domain/repositories/month_exporter.dart';
import 'month_share_state.dart';

class MonthShareCubit extends Cubit<MonthShareState> {
  MonthShareCubit(this.month, this._exporter, this._share)
    : super(const MonthShareState());
  final CalendarMonth month;
  final MonthExporter _exporter;
  final ImageSharer _share;
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
      final result = await _share.share(image, month.fileName, (
        left: origin.left,
        top: origin.top,
        width: origin.width,
        height: origin.height,
      ));
      message = switch (result) {
        ImageShareResult.dismissed => 'Sharing cancelled.',
        ImageShareResult.unavailable =>
          'Share sheet closed. Sharing could not be confirmed.',
        ImageShareResult.selected => 'Share action selected.',
      };
    } on ImageShareException catch (error) {
      message = error.message;
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
