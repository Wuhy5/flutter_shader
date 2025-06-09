import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import 'shader_painter.dart';

/// 高性能的着色器翻页组件
class ShaderPageView extends StatefulWidget {
  final List<Widget> children;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final String shaderAsset;
  final Duration animationDuration;
  final Curve animationCurve;
  final double pageMargin;
  final bool physics;

  const ShaderPageView({
    super.key,
    required this.children,
    required this.shaderAsset,
    this.controller,
    this.onPageChanged,
    this.animationDuration = const Duration(milliseconds: 350),
    this.animationCurve = Curves.easeOutQuart,
    this.pageMargin = 0.0,
    this.physics = true,
  });

  @override
  State<ShaderPageView> createState() => _ShaderPageViewState();
}

class _ShaderPageViewState extends State<ShaderPageView>
    with TickerProviderStateMixin {
  // 拖拽相关
  Offset _dragPosition = Offset.zero;
  Offset _dragStart = Offset.zero;
  bool _isDragging = false;
  bool _isAnimating = false;

  // 速度追踪 - 优化版本
  final List<_VelocityData> _velocityData = [];
  Offset _velocity = Offset.zero;

  // 页面管理
  late PageController _pageController;
  int _currentPageIndex = 0;
  final List<ui.Image?> _pageImages = [];

  ui.Image? _frontImage;
  ui.Image? _backImage;
  Size _currentSize = Size.zero;

  // 优化的动画控制器
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _progressAnimation;

  Offset _animationStartPosition = Offset.zero;
  Offset _animationEndPosition = Offset.zero;

  // 性能优化
  bool _needsImageUpdate = true;
  DateTime _lastFrameTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pageController = widget.controller ?? PageController();
    _currentPageIndex = _pageController.initialPage;

    // 优化的动画控制器设置
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _setupAnimations();

    // 延迟加载图片
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImages();
    });
  }

  void _setupAnimations() {
    _offsetAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(CurvedAnimation(
          parent: _animationController,
          curve: widget.animationCurve,
        ));

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(
          parent: _animationController,
          curve: widget.animationCurve,
        ));

    _offsetAnimation.addListener(_onAnimationUpdate);
    _animationController.addStatusListener(_onAnimationStatusChange);
  }

  void _onAnimationUpdate() {
    if (_isAnimating && mounted) {
      final now = DateTime.now();
      // 限制重绘频率到60fps
      if (now.difference(_lastFrameTime).inMilliseconds >= 16) {
        _lastFrameTime = now;
        setState(() {
          _dragPosition = _offsetAnimation.value;
        });
      }
    }
  }

  void _onAnimationStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _handleAnimationComplete();
    }
  }

  Size get _pageSize {
    final size = _currentSize;
    return Size(
      math.max(0, size.width - widget.pageMargin * 2),
      math.max(0, size.height - widget.pageMargin * 2),
    );
  }

  Future<void> _loadImages() async {
    if (_currentSize.width <= 0 || _currentSize.height <= 0) return;

    _pageImages.clear();
    final pageSize = _pageSize;
    
    if (pageSize.width <= 0 || pageSize.height <= 0) return;

    for (int i = 0; i < widget.children.length; i++) {
      final image = await _createPageImage(i, pageSize);
      _pageImages.add(image);
    }

    if (mounted) {
      setState(() {
        _updateCurrentImages();
        _needsImageUpdate = false;
      });
    }
  }

  Future<ui.Image> _createPageImage(int index, Size size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 创建颜色渐变背景
    final colors = [
      Colors.white,
      Colors.lightBlue.shade50,
      Colors.lightGreen.shade50,
      Colors.orange.shade50,
      Colors.pink.shade50,
    ];
    
    final bgColor = colors[index % colors.length];
    
    // 绘制渐变背景
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        bgColor,
        bgColor.withOpacity(0.8),
      ],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 绘制页面内容
    final titleStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontWeight: FontWeight.bold,
      fontSize: 28,
    );
    
    final contentStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 16,
    );

    // 标题
    final titleBuilder = ui.ParagraphBuilder(titleStyle)
      ..pushStyle(ui.TextStyle(color: Colors.black87))
      ..addText('第${index + 1}页');
    
    final titleParagraph = titleBuilder.build()
      ..layout(ui.ParagraphConstraints(width: size.width - 40));
    
    // 内容
    final contentBuilder = ui.ParagraphBuilder(contentStyle)
      ..pushStyle(ui.TextStyle(color: Colors.black54))
      ..addText('这是第${index + 1}页的内容\n\n着色器翻页效果演示');
    
    final contentParagraph = contentBuilder.build()
      ..layout(ui.ParagraphConstraints(width: size.width - 40));

    // 绘制文本
    canvas.drawParagraph(titleParagraph, Offset(20, size.height / 2 - 100));
    canvas.drawParagraph(contentParagraph, Offset(20, size.height / 2 - 20));

    final picture = recorder.endRecording();
    return await picture.toImage(size.width.toInt(), size.height.toInt());
  }

  void _updateCurrentImages() {
    if (_pageImages.isEmpty) return;

    _frontImage = _pageImages[_currentPageIndex];
    _backImage = _getBackImage();
  }

  ui.Image? _getBackImage() {
    if (_dragStart == Offset.zero) {
      return _frontImage;
    }
    
    final isCurlFromRight = _dragStart.dx > _currentSize.width / 2;
    
    if (isCurlFromRight && _currentPageIndex < _pageImages.length - 1) {
      return _pageImages[_currentPageIndex + 1];
    } else if (!isCurlFromRight && _currentPageIndex > 0) {
      return _pageImages[_currentPageIndex - 1];
    }
    
    return _frontImage;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newSize = constraints.biggest;
        if (_currentSize != newSize) {
          _currentSize = newSize;
          _needsImageUpdate = true;
          // 延迟重新加载图片
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_needsImageUpdate) {
              _loadImages();
            }
          });
        }

        return Stack(
          children: [
            if (_frontImage != null && _backImage != null)
              _buildShaderCanvas()
            else
              const Center(child: CircularProgressIndicator()),
            _buildPageIndicator(),
          ],
        );
      },
    );
  }

  Widget _buildShaderCanvas() {
    return Center(
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: ShaderBuilder(
          assetKey: widget.shaderAsset,
          (context, shader, child) => RepaintBoundary(
            child: CustomPaint(
              size: _pageSize,
              painter: ShaderPainter(
                shader: shader,
                frontImage: _frontImage!,
                backImage: _backImage!,
                mousePos: _dragPosition,
                mouseStart: _dragStart,
                isDragging: _isDragging || _isAnimating,
                animationProgress: _progressAnimation.value,
              ),
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.children.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == _currentPageIndex ? 12 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: index == _currentPageIndex
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade400,
            ),
          );
        }),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.physics) return;

    if (!_canFlipPage(details.localPosition)) return;

    if (_isAnimating) {
      _animationController.stop();
      _isAnimating = false;
    }

    // 清空速度数据
    _velocityData.clear();
    _addVelocityData(details.localPosition);

    setState(() {
      _isDragging = true;
      _dragStart = details.localPosition;
      _dragPosition = details.localPosition;
      _velocity = Offset.zero;
      _updateCurrentImages();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating) return;

    _addVelocityData(details.localPosition);

    setState(() {
      _dragPosition = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    _calculateVelocity();
    
    final shouldComplete = _shouldCompletePage();
    final targetPosition = _calculateAnimationTarget();

    setState(() {
      _isDragging = false;
      _isAnimating = true;
      _animationStartPosition = _dragPosition;
      _animationEndPosition = targetPosition;
    });

    _startOptimizedAnimation(targetPosition, shouldComplete);
  }

  void _addVelocityData(Offset position) {
    final now = DateTime.now();
    _velocityData.add(_VelocityData(position, now));
    
    // 只保留最近100ms的数据
    _velocityData.removeWhere(
      (data) => now.difference(data.time).inMilliseconds > 100,
    );
  }

  void _calculateVelocity() {
    if (_velocityData.length < 2) {
      _velocity = Offset.zero;
      return;
    }

    final latest = _velocityData.last;
    final earliest = _velocityData.first;
    
    final timeDiff = latest.time.difference(earliest.time).inMilliseconds;
    if (timeDiff <= 0) {
      _velocity = Offset.zero;
      return;
    }

    final positionDiff = latest.position - earliest.position;
    _velocity = positionDiff * (1000.0 / timeDiff);
  }

  void _startOptimizedAnimation(Offset targetPosition, bool shouldComplete) {
    final distance = (targetPosition - _dragPosition).distance;
    final speed = _velocity.distance;

    // 智能动画时长计算
    Duration duration;
    if (shouldComplete) {
      // 完成翻页：基于距离和速度的动态时长
      final baseDuration = math.max(200, math.min(500, (distance / speed * 1000).round()));
      duration = Duration(milliseconds: baseDuration);
    } else {
      // 回弹动画：固定较短时长
      duration = const Duration(milliseconds: 250);
    }

    _animationController.duration = duration;

    // 选择合适的动画曲线
    final curve = shouldComplete ? Curves.easeOutQuart : Curves.elasticOut;

    _offsetAnimation = Tween<Offset>(
      begin: _animationStartPosition,
      end: _animationEndPosition,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: curve,
    ));

    _animationController.forward(from: 0.0);
  }

  bool _canFlipPage(Offset position) {
    final isCurlFromRight = position.dx > _currentSize.width / 2;
    return isCurlFromRight
        ? _currentPageIndex < widget.children.length - 1
        : _currentPageIndex > 0;
  }

  bool _shouldCompletePage() {
    if (_dragStart == Offset.zero || !_canFlipPage(_dragStart)) return false;

    final dragDistance = (_dragPosition - _dragStart).distance;
    final screenDiagonal = math.sqrt(
      _currentSize.width * _currentSize.width + _currentSize.height * _currentSize.height,
    );

    // 自适应阈值
    final distanceThreshold = screenDiagonal * 0.2;
    final speedThreshold = 600.0;

    final hasEnoughDistance = dragDistance > distanceThreshold;
    final hasEnoughSpeed = _velocity.distance > speedThreshold;

    // 方向验证
    final dragDirection = _dragPosition - _dragStart;
    final isCurlFromRight = _dragStart.dx > _currentSize.width / 2;
    final isCorrectDirection = isCurlFromRight ? dragDirection.dx < -10 : dragDirection.dx > 10;

    return isCorrectDirection && (hasEnoughDistance || hasEnoughSpeed);
  }

  Offset _calculateAnimationTarget() {
    if (_shouldCompletePage()) {
      final isCurlFromRight = _dragStart.dx > _currentSize.width / 2;
      final halfHeight = _currentSize.height / 2;

      return isCurlFromRight
          ? Offset(0, halfHeight)
          : Offset(_currentSize.width, halfHeight);
    } else {
      return _dragStart;
    }
  }

  void _handleAnimationComplete() {
    if (_shouldCompletePage()) {
      _swapPages();
    }

    setState(() {
      _isAnimating = false;
      _dragPosition = Offset.zero;
      _dragStart = Offset.zero;
      _velocity = Offset.zero;
    });
  }

  void _swapPages() {
    final isCurlFromRight = _dragStart.dx > _currentSize.width / 2;

    if (isCurlFromRight && _currentPageIndex < widget.children.length - 1) {
      _currentPageIndex++;
    } else if (!isCurlFromRight && _currentPageIndex > 0) {
      _currentPageIndex--;
    }

    _updateCurrentImages();

    if (widget.onPageChanged != null) {
      widget.onPageChanged!(_currentPageIndex);
    }

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        _currentPageIndex,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (widget.controller == null) {
      _pageController.dispose();
    }
    super.dispose();
  }
}

// 速度数据结构
class _VelocityData {
  final Offset position;
  final DateTime time;

  _VelocityData(this.position, this.time);
}
