import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:trace/features/settings/application/profile_crop.dart';

class ProfilePictureEditResult {
  const ProfilePictureEditResult({
    required this.transform,
    required this.avatarBytes,
  });

  final ProfileImageTransform transform;
  final Uint8List avatarBytes;
}

/// Full-size, direct-manipulation editor for the retained profile source.
class ProfilePictureEditor extends StatefulWidget {
  const ProfilePictureEditor({
    super.key,
    required this.source,
    required this.initialTransform,
  });

  final Uint8List source;
  final ProfileImageTransform initialTransform;

  @override
  State<ProfilePictureEditor> createState() => _ProfilePictureEditorState();
}

class _ProfilePictureEditorState extends State<ProfilePictureEditor> {
  ui.Image? _image;
  String? _error;
  late ProfileImageTransform _transform;
  late ProfileImageTransform _gestureStart;
  Offset _startFocalPoint = Offset.zero;
  bool _circlePreview = true;
  bool _saving = false;
  bool _hasTransparency = false;
  late final bool _defaultBlurBackground;

  @override
  void initState() {
    super.initState();
    _transform = widget.initialTransform;
    _defaultBlurBackground = !isPngProfileImage(widget.source);
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.source);
      final ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      var hasTransparency = false;
      try {
        hasTransparency = await profileImageHasTransparency(image);
      } catch (_) {
        hasTransparency = isPngProfileImage(widget.source);
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _hasTransparency = hasTransparency;
        if (_transform.blurBackground == null) {
          _transform = _transform.copyWith(
            blurBackground: _defaultBlurBackground && !hasTransparency,
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open this picture.');
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _startGesture(ScaleStartDetails details) {
    _gestureStart = _transform;
    _startFocalPoint = details.localFocalPoint;
  }

  void _updateGesture(ScaleUpdateDetails details, double side) {
    setState(() {
      _transform = transformProfileGesture(
        start: _gestureStart,
        startFocalPoint: _startFocalPoint,
        focalPoint: details.localFocalPoint,
        gestureScale: details.scale,
        gestureRotation: details.rotation,
        viewportSize: side,
      );
    });
  }

  void _change(ProfileImageTransform Function(ProfileImageTransform) change) {
    setState(() => _transform = change(_transform));
  }

  bool get _needsBackground {
    final image = _image;
    return image != null &&
        profileImageNeedsBackground(
          Size(image.width.toDouble(), image.height.toDouble()),
          _transform,
          hasTransparency: _hasTransparency,
        );
  }

  Future<void> _savePicture() async {
    final image = _image;
    if (image == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bytes = await renderProfileImageFromDecoded(
        image,
        transform: _transform,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        ProfilePictureEditResult(transform: _transform, avatarBytes: bytes),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save this picture.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    key: const Key('profile-picture-editor'),
    backgroundColor: const Color(0xFF141518),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Cancel picture editing',
                          color: Colors.white,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          constraints.maxWidth < 500
                              ? 'Picture'
                              : 'Edit profile picture',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      key: const Key('profile-preview-shape-toggle'),
                      tooltip: _circlePreview
                          ? 'Show square preview'
                          : 'Show circular preview',
                      onPressed: () =>
                          setState(() => _circlePreview = !_circlePreview),
                      icon: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(
                            _circlePreview ? 9 : 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = math
                    .min(constraints.maxWidth - 32, constraints.maxHeight - 16)
                    .clamp(1.0, 680.0);
                return Center(
                  child: SizedBox.square(
                    dimension: side,
                    child: GestureDetector(
                      key: const Key('profile-picture-gesture-area'),
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: _image == null ? null : _startGesture,
                      onScaleUpdate: _image == null
                          ? null
                          : (details) => _updateGesture(details, side),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: _circlePreview ? side / 2 : 0,
                        ),
                        duration: const Duration(milliseconds: 220),
                        builder: (context, radius, child) => ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          child: child,
                        ),
                        child: _picturePreview(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Text(
              'Drag to move · Pinch to zoom and rotate',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          if (_error != null && _image != null)
            Text(_error!, style: const TextStyle(color: Color(0xFFFF9F9F))),
          SizedBox(
            height: 48,
            child: _needsBackground
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(
                          child: Text(
                            'Blur uncovered area',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          key: const Key('profile-blur-background-switch'),
                          value: _transform.blurBackground ?? true,
                          onChanged: (value) => _change(
                            (current) =>
                                current.copyWith(blurBackground: value),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 2,
              children: [
                _tool(
                  'Zoom out',
                  Icons.remove,
                  () => _change(
                    (value) => value.copyWith(
                      scale: (value.scale / 1.2).clamp(.25, 6.0),
                    ),
                  ),
                ),
                _tool(
                  'Zoom in',
                  Icons.add,
                  () => _change(
                    (value) => value.copyWith(
                      scale: (value.scale * 1.2).clamp(.25, 6.0),
                    ),
                  ),
                ),
                _tool(
                  'Rotate left',
                  Icons.rotate_left,
                  () => _change(
                    (value) =>
                        value.copyWith(rotation: value.rotation - math.pi / 2),
                  ),
                ),
                _tool(
                  'Rotate right',
                  Icons.rotate_right,
                  () => _change(
                    (value) =>
                        value.copyWith(rotation: value.rotation + math.pi / 2),
                  ),
                ),
                _tool(
                  'Flip horizontally',
                  Icons.flip,
                  () => _change(
                    (value) =>
                        value.copyWith(flipHorizontal: !value.flipHorizontal),
                  ),
                ),
                _tool(
                  'Flip vertically',
                  Icons.swap_vert,
                  () => _change(
                    (value) =>
                        value.copyWith(flipVertical: !value.flipVertical),
                  ),
                ),
                _tool(
                  'Reset picture',
                  Icons.restart_alt,
                  () => setState(
                    () => _transform = ProfileImageTransform(
                      blurBackground:
                          _defaultBlurBackground && !_hasTransparency,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('save-profile-picture-edit'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B68E8),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white24,
                  disabledForegroundColor: Colors.white70,
                ),
                onPressed: _image == null || _saving ? null : _savePicture,
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'Saving picture…' : 'Save picture'),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _picturePreview() => _image == null
      ? Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Text(_error!, style: const TextStyle(color: Colors.white)),
        )
      : Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _TransparencyGridPainter()),
            CustomPaint(
              painter: ProfileImagePainter(
                image: _image!,
                transform: _transform,
              ),
            ),
          ],
        );

  Widget _tool(String label, IconData icon, VoidCallback action) => SizedBox(
    width: 74,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: label,
          color: Colors.white,
          onPressed: _image == null ? null : action,
          icon: Icon(icon),
        ),
        Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}

class _TransparencyGridPainter extends CustomPainter {
  const _TransparencyGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 16.0;
    canvas.drawColor(const Color(0xFF393B40), BlendMode.srcOver);
    final light = Paint()..color = const Color(0xFF50535A);
    for (var row = 0; row * cell < size.height; row++) {
      for (
        var column = row.isEven ? 0 : 1;
        column * cell < size.width;
        column += 2
      ) {
        canvas.drawRect(
          Rect.fromLTWH(column * cell, row * cell, cell, cell),
          light,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TransparencyGridPainter oldDelegate) => false;
}
