import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'photo_editor_media_processing_service.dart';

class PhotoEditorPreviewState {
  const PhotoEditorPreviewState({
    required this.isLoading,
    required this.showImmediatePreview,
    required this.useLocalImage,
    this.initialImageProvider,
    this.errorMessageKey,
    this.errorMessageArgs,
    this.resolvedFilePath,
  });

  const PhotoEditorPreviewState.textOnly()
    : isLoading = false,
      showImmediatePreview = false,
      useLocalImage = false,
      initialImageProvider = null,
      errorMessageKey = null,
      errorMessageArgs = null,
      resolvedFilePath = null;

  final bool isLoading;
  final bool showImmediatePreview;
  final bool useLocalImage;
  final ImageProvider? initialImageProvider;
  final String? errorMessageKey;
  final Map<String, String>? errorMessageArgs;
  final String? resolvedFilePath;
}

class PhotoEditorScreenInitService {
  const PhotoEditorScreenInitService({
    required PhotoEditorMediaProcessingService mediaProcessingService,
  }) : _mediaProcessingService = mediaProcessingService;

  final PhotoEditorMediaProcessingService _mediaProcessingService;

  static bool isTextOnlyMode({
    required String? inputText,
    required String? filePath,
    required AssetEntity? asset,
    required String? downloadUrl,
  }) {
    final text = inputText?.trim();
    return text != null &&
        text.isNotEmpty &&
        filePath == null &&
        asset == null &&
        downloadUrl == null;
  }

  static String textOnlyContent(String? inputText) => inputText?.trim() ?? '';

  PhotoEditorPreviewState primeImmediatePreview({
    required ImageProvider? initialImage,
    required String? filePath,
  }) {
    if (initialImage != null) {
      return PhotoEditorPreviewState(
        isLoading: false,
        showImmediatePreview: true,
        useLocalImage: true,
        initialImageProvider: initialImage,
      );
    }

    if (filePath == null || filePath.isEmpty) {
      return const PhotoEditorPreviewState(
        isLoading: true,
        showImmediatePreview: false,
        useLocalImage: false,
      );
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      return const PhotoEditorPreviewState(
        isLoading: true,
        showImmediatePreview: false,
        useLocalImage: false,
      );
    }

    return PhotoEditorPreviewState(
      isLoading: false,
      showImmediatePreview: true,
      useLocalImage: true,
      resolvedFilePath: filePath,
    );
  }

  Future<PhotoEditorPreviewState> resolveAssetPreview({
    required AssetEntity asset,
    required bool showImmediatePreview,
    required ImageProvider? initialImageProvider,
    required bool useLocalImage,
  }) async {
    try {
      final file = await asset.file;
      if (file == null) {
        return PhotoEditorPreviewState(
          isLoading: false,
          showImmediatePreview: showImmediatePreview,
          useLocalImage: useLocalImage,
          initialImageProvider: initialImageProvider,
          errorMessageKey: 'camera.editor.image_not_found',
        );
      }

      if (showImmediatePreview) {
        return PhotoEditorPreviewState(
          isLoading: false,
          showImmediatePreview: true,
          useLocalImage: useLocalImage,
          initialImageProvider: initialImageProvider,
          resolvedFilePath: file.path,
        );
      }

      return loadImage(
        filePath: file.path,
        showImmediatePreview: false,
        initialImageProvider: initialImageProvider,
        useLocalImage: useLocalImage,
      );
    } catch (e) {
      return PhotoEditorPreviewState(
        isLoading: false,
        showImmediatePreview: showImmediatePreview,
        useLocalImage: useLocalImage,
        initialImageProvider: initialImageProvider,
        errorMessageKey: 'camera.editor.image_load_error_with_reason',
        errorMessageArgs: {'error': e.toString()},
      );
    }
  }

  Future<PhotoEditorPreviewState> loadImage({
    required String? filePath,
    required bool showImmediatePreview,
    required ImageProvider? initialImageProvider,
    required bool useLocalImage,
  }) async {
    if (showImmediatePreview) {
      return PhotoEditorPreviewState(
        isLoading: false,
        showImmediatePreview: true,
        useLocalImage: useLocalImage,
        initialImageProvider: initialImageProvider,
        resolvedFilePath: filePath,
      );
    }

    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      try {
        final exists = await file.exists();
        if (exists) {
          return PhotoEditorPreviewState(
            isLoading: false,
            showImmediatePreview: true,
            useLocalImage: true,
            initialImageProvider: initialImageProvider,
            resolvedFilePath: filePath,
          );
        }

        return PhotoEditorPreviewState(
          isLoading: false,
          showImmediatePreview: false,
          useLocalImage: false,
          initialImageProvider: initialImageProvider,
          errorMessageKey: 'camera.editor.image_not_found',
        );
      } catch (e) {
        return PhotoEditorPreviewState(
          isLoading: false,
          showImmediatePreview: false,
          useLocalImage: false,
          initialImageProvider: initialImageProvider,
          errorMessageKey: 'camera.editor.image_load_error_with_reason',
          errorMessageArgs: {'error': e.toString()},
        );
      }
    }

    return PhotoEditorPreviewState(
      isLoading: false,
      showImmediatePreview: false,
      useLocalImage: useLocalImage,
      initialImageProvider: initialImageProvider,
    );
  }

  Future<File>? createImagePreCompressionTask({
    required bool isVideo,
    required String? filePath,
  }) {
    if (isVideo || filePath == null || filePath.isEmpty) {
      return null;
    }

    return _mediaProcessingService.compressImageIfNeeded(File(filePath));
  }
}
