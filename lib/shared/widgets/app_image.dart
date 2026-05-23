import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/network/api_constants.dart';
import '../../core/theme/app_colors.dart';

class AppImage extends StatelessWidget {
  static const List<int> _cacheSizeBuckets = [
    192,
    320,
    480,
    640,
    960,
    1280,
    1600
  ];

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? fallbackAsset;
  final Widget? fallbackWidget;
  final int? optimizedSize;
  final FilterQuality filterQuality;

  const AppImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackAsset,
    this.fallbackWidget,
    this.optimizedSize,
    this.filterQuality = FilterQuality.medium,
  });

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl?.trim() ?? '';
    if (optimizedSize != null || _isAssetPath(raw)) {
      final child = _isAssetPath(raw)
          ? _buildAsset(raw, cacheSize: optimizedSize)
          : _buildImage(
              context,
              ApiConstants.resolveImageUrl(raw),
              const BoxConstraints(),
            );
      return _clipIfNeeded(child);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final child = _isAssetPath(raw)
            ? _buildAsset(raw, cacheSize: optimizedSize)
            : _buildImage(
                context,
                ApiConstants.resolveImageUrl(raw),
                constraints,
              );

        return _clipIfNeeded(child);
      },
    );
  }

  Widget _clipIfNeeded(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _buildImage(
    BuildContext context,
    String resolved,
    BoxConstraints constraints,
  ) {
    if (resolved.isEmpty) return _buildFallback();

    final uri = Uri.tryParse(resolved);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    if (isNetwork) {
      final cacheSize = optimizedSize ?? _targetCacheSize(context, constraints);
      final provider = ResizeImage.resizeIfNeeded(
        cacheSize,
        cacheSize,
        NetworkImage(ApiConstants.optimizedImageUrl(resolved, cacheSize)),
      );
      return _buildProviderImage(
        provider,
        loading: _buildLoading,
        error: _buildFallback,
      );
    }

    if ((uri != null && uri.scheme.isNotEmpty) || resolved.contains('://')) {
      return _buildFallback();
    }
    return _buildAsset(resolved, cacheSize: optimizedSize);
  }

  bool _isAssetPath(String value) =>
      value.startsWith('assets/') || value.startsWith('packages/');

  Widget _buildAsset(String assetPath, {int? cacheSize}) {
    return _buildProviderImage(
      ResizeImage.resizeIfNeeded(
        cacheSize,
        cacheSize,
        AssetImage(assetPath),
      ),
      error: _buildFallback,
    );
  }

  int _targetCacheSize(BuildContext context, BoxConstraints constraints) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final logicalWidth =
        _finitePositive(width) ?? _finitePositive(constraints.maxWidth);
    final logicalHeight =
        _finitePositive(height) ?? _finitePositive(constraints.maxHeight);
    final logicalSize = math.max(logicalWidth ?? 0, logicalHeight ?? 0);
    final fallbackSize = MediaQuery.sizeOf(context).shortestSide;
    final pixelSize =
        ((logicalSize > 0 ? logicalSize : fallbackSize) * devicePixelRatio)
            .round();
    final clampedSize = pixelSize.clamp(
      _cacheSizeBuckets.first,
      _cacheSizeBuckets.last,
    );
    return _cacheSizeBuckets.firstWhere(
      (bucket) => clampedSize <= bucket,
      orElse: () => _cacheSizeBuckets.last,
    );
  }

  double? _finitePositive(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;

  Widget _buildLoading() {
    return Container(
      width: width,
      height: height,
      color: AppColors.neutral100,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildFallback() {
    if (fallbackWidget != null) return fallbackWidget!;
    if (fallbackAsset != null) {
      return _buildProviderImage(
        ResizeImage.resizeIfNeeded(
          optimizedSize,
          optimizedSize,
          AssetImage(fallbackAsset!),
        ),
        error: _fallbackBox,
      );
    }
    return _fallbackBox();
  }

  Widget _buildProviderImage(
    ImageProvider imageProvider, {
    Widget Function()? loading,
    required Widget Function() error,
  }) {
    return Image(
      image: imageProvider,
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null
              ? child
              : loading?.call() ?? _buildLoading(),
      errorBuilder: (_, __, ___) => error(),
    );
  }

  Widget _fallbackBox() {
    return Container(
      width: width,
      height: height,
      color: AppColors.neutral100,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_rounded,
        color: AppColors.neutral400,
        size: 32,
      ),
    );
  }
}
