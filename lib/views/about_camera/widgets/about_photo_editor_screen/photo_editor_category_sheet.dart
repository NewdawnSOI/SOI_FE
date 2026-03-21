import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'category_list_widget.dart';

class PhotoEditorCategorySheetController {
  _PhotoEditorCategorySheetState? _state;

  void _attach(_PhotoEditorCategorySheetState state) {
    _state = state;
  }

  void _detach(_PhotoEditorCategorySheetState state) {
    if (_state == state) {
      _state = null;
    }
  }

  void ensureLockedOpen() {
    _state?._ensureLockedOpen();
  }

  Future<void> resetIfNeeded() {
    return _state?._resetIfNeeded() ?? Future.value();
  }

  void collapseToStart() {
    _state?._collapseToStart();
  }
}

class PhotoEditorCategorySheet extends StatefulWidget {
  const PhotoEditorCategorySheet({
    super.key,
    required this.controller,
    required this.selectedCategoryIds,
    required this.onCategorySelected,
    required this.addCategoryPressed,
    required this.onConfirmSelection,
    required this.isHidden,
    required this.shouldAutoOpen,
  });

  static const double initialSheetExtent = 0.0;
  static const double lockedSheetExtent = 0.19;
  static const double expandedSheetExtent = 0.31;
  static const double maxSheetExtent = 0.8;

  final PhotoEditorCategorySheetController controller;
  final List<int> selectedCategoryIds;
  final ValueChanged<int> onCategorySelected;
  final VoidCallback addCategoryPressed;
  final VoidCallback onConfirmSelection;
  final bool isHidden;
  final bool shouldAutoOpen;

  @override
  State<PhotoEditorCategorySheet> createState() =>
      _PhotoEditorCategorySheetState();
}

class _PhotoEditorCategorySheetState extends State<PhotoEditorCategorySheet> {
  final DraggableScrollableController _draggableScrollController =
      DraggableScrollableController();

  double _minChildSize = PhotoEditorCategorySheet.initialSheetExtent;
  double _initialChildSize = PhotoEditorCategorySheet.lockedSheetExtent;
  bool _hasLockedSheetExtent = false;
  bool _isAnimatingSheet = false;
  bool _hasAutoOpened = false;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _ensureLockedOpen();
  }

  @override
  void didUpdateWidget(PhotoEditorCategorySheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.shouldAutoOpen && widget.shouldAutoOpen) {
      _ensureLockedOpen();
    }

    if (oldWidget.selectedCategoryIds.isEmpty &&
        widget.selectedCategoryIds.isNotEmpty) {
      _animateSheetToIfNeeded(PhotoEditorCategorySheet.expandedSheetExtent);
    }

    if (oldWidget.selectedCategoryIds.isNotEmpty &&
        widget.selectedCategoryIds.isEmpty) {
      _animateSheetTo(PhotoEditorCategorySheet.lockedSheetExtent);
    }

    if (oldWidget.isHidden &&
        !widget.isHidden &&
        widget.selectedCategoryIds.isNotEmpty) {
      _animateSheetToIfNeeded(PhotoEditorCategorySheet.expandedSheetExtent);
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _collapseToStart();
    _draggableScrollController.dispose();
    super.dispose();
  }

  void _ensureLockedOpen() {
    if (_hasAutoOpened || widget.isHidden || !widget.shouldAutoOpen) {
      return;
    }

    _hasAutoOpened = true;
    _animateSheetTo(
      PhotoEditorCategorySheet.lockedSheetExtent,
      lockExtent: true,
    );
  }

  Future<void> _resetIfNeeded() async {
    if (!_draggableScrollController.isAttached) {
      return;
    }

    final targetSize = _hasLockedSheetExtent
        ? PhotoEditorCategorySheet.lockedSheetExtent
        : _initialChildSize;
    final currentSize = _draggableScrollController.size;
    if ((currentSize - targetSize).abs() <= 0.001) {
      return;
    }

    await _draggableScrollController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _collapseToStart() {
    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
  }

  void _animateSheetToIfNeeded(double targetSize) {
    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_draggableScrollController.isAttached) {
        return;
      }

      final currentExtent = _draggableScrollController.size;
      if (currentExtent >= targetSize - 0.02) {
        return;
      }

      _animateSheetTo(targetSize);
    });
  }

  void _animateSheetTo(
    double size, {
    bool lockExtent = false,
    int retryCount = 0,
  }) {
    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      if (!_draggableScrollController.isAttached) {
        if (retryCount < 50) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          _animateSheetTo(
            size,
            lockExtent: lockExtent,
            retryCount: retryCount + 1,
          );
        }
        return;
      }

      _isAnimatingSheet = true;
      try {
        await _draggableScrollController.animateTo(
          size,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        if (lockExtent && !_hasLockedSheetExtent && mounted) {
          setState(() {
            _minChildSize = size;
            _initialChildSize = size;
            _hasLockedSheetExtent = true;
          });
        }
      } finally {
        _isAnimatingSheet = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHidden) {
      return const SizedBox.shrink();
    }

    _ensureLockedOpen();

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (_isAnimatingSheet) {
          return true;
        }

        if (widget.selectedCategoryIds.isNotEmpty) {
          if (notification.extent <
              PhotoEditorCategorySheet.lockedSheetExtent - 0.02) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  !_isAnimatingSheet &&
                  _draggableScrollController.isAttached) {
                _draggableScrollController.jumpTo(
                  PhotoEditorCategorySheet.lockedSheetExtent,
                );
              }
            });
          }
          return true;
        }

        if (!_hasLockedSheetExtent && notification.extent < 0.01) {
          _animateSheetTo(
            PhotoEditorCategorySheet.lockedSheetExtent,
            lockExtent: true,
          );
        }
        return true;
      },
      child: DraggableScrollableSheet(
        controller: _draggableScrollController,
        initialChildSize: _initialChildSize,
        minChildSize: _minChildSize,
        maxChildSize: PhotoEditorCategorySheet.maxSheetExtent,
        expand: false,
        builder: (context, scrollController) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight;
              final handleHeight = 25.h;
              final spacing = maxHeight > handleHeight ? 4.h : 0.0;
              final contentHeight = math.max(
                0.0,
                maxHeight - handleHeight - spacing,
              );

              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xff171717),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: handleHeight,
                        child: Center(
                          child: Container(
                            height: 3.h,
                            width: 56.w,
                            margin: EdgeInsets.symmetric(vertical: 11.h),
                            decoration: BoxDecoration(
                              color: const Color(0xffcdcdcd),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: spacing),
                      SizedBox(
                        height: contentHeight,
                        child: CategoryListWidget(
                          scrollController: scrollController,
                          selectedCategoryIds: widget.selectedCategoryIds,
                          onCategorySelected: widget.onCategorySelected,
                          addCategoryPressed: widget.addCategoryPressed,
                          onConfirmSelection: widget.onConfirmSelection,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
