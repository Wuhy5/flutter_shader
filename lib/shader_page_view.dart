import 'dart:math' as math; // 用于数学计算，如平方根、最大最小值
import 'dart:ui' as ui; // 用于 ui.Image 等底层图形接口

import 'package:flutter/material.dart';
import 'package:flutter_shader/shader_painter.dart'; // 自定义的着色器绘制器
import 'package:flutter_shaders/flutter_shaders.dart'; // flutter_shaders 包，用于加载和使用着色器

// ShaderPageView 是一个 StatefulWidget，用于显示可翻页的图片列表，并应用着色器效果
class ShaderPageView extends StatefulWidget {
  const ShaderPageView({
    super.key,
    required this.images, // 需要显示的 ui.Image 列表
    required this.pageSize, // 每个页面的尺寸
    this.initialPage = 0, // 初始显示的页面索引，默认为0
    this.onPageChanged, // 页面切换时的回调函数
  });

  final List<ui.Image?> images;
  final Size pageSize;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;

  @override
  State<ShaderPageView> createState() => _ShaderPageViewState();
}

// ShaderPageView 的状态管理类
class _ShaderPageViewState extends State<ShaderPageView>
    with TickerProviderStateMixin {
  //混入 TickerProviderStateMixin 以提供 AnimationController 所需的 Ticker
  // 拖动状态变量
  Offset _dragPosition = Offset.zero; // 当前拖动/手指位置
  Offset _dragStart = Offset.zero; // 拖动开始时的位置

  bool _isDragging = false; // 标记是否正在拖动
  bool _isAnimating = false; // 标记是否正在执行翻页动画

  // 页面管理变量
  int _currentPageIndex = 0; // 当前页面索引
  int get _totalPages => widget.images.length; // 总页面数，从 widget.images 获取
  ui.Image? _frontImage; // 当前显示的正面图片
  ui.Image? _backImage; // 翻页时显示的背面图片（即下一页或上一页）
  Size _currentSize = Size.zero; // 当前组件的尺寸，通常等于 widget.pageSize

  // 动画控制器和动画对象
  late AnimationController _flingController; // 用于控制惯性翻页动画
  late Animation<Offset> _offsetAnimation; // 描述拖动位置变化的动画

  // 动画的起始和结束位置
  Offset _animationStartPosition = Offset.zero;
  Offset _animationEndPosition = Offset.zero;
  Offset _velocity = Offset.zero; // 拖动结束时的速度，用于计算惯性动画

  // 最小动画速度，当检测到的拖动速度过低时，使用此速度以确保动画平滑
  static const double _minAnimationSpeed = 800.0;

  // _shouldCompletePage constants
  static const double _kDistanceThresholdFactor = 0.25; // 距离阈值因子
  static const double _kSpeedThreshold = 500.0; // 速度阈值
  static const double _kSpeedBasedDistanceFactor = 0.4; // 基于速度的距离调整因子
  static const double _kDragDirectionTolerance = 20.0; // 拖动方向容差
  static const double _kLargeDragFactor = 0.3; // 大幅度拖动判断因子

  // _calculateAnimationTarget constants
  static const double _kVerticalCenterToleranceFactor = 0.3; // 垂直中心判断容差因子

  // _startFlingAnimation constants
  static const int _kMinAnimationDurationMs = 200; // 最小动画时长 (ms)
  static const int _kBaseMaxAnimationDurationMs = 400; // 基础最大动画时长 (ms)
  static const double _kDurationDistanceFactor = 500.0; // 动画时长计算中的距离因子
  static const double _kDurationSpeedDivisor = 800.0; // 动画时长计算中的速度除数

  @override
  void initState() {
    super.initState();
    _currentSize = widget.pageSize; // 初始化当前尺寸
    _currentPageIndex = widget.initialPage; // 初始化当前页面索引
    _updatePageImages(); // 根据当前索引更新正面和背面图片

    // 初始化惯性动画控制器
    _flingController = AnimationController(
      duration: const Duration(milliseconds: 450), // 优化动画时长，更快响应
      vsync: this, // TickerProvider
    );

    // 初始化位移动画，初始值设为零，后续会根据实际拖动和目标位置更新
    _offsetAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _flingController,
            curve: Curves.easeOutCubic, // 使用更流畅的缓动曲线
          ),
        );
    // 添加动画监听器，当动画值改变时更新 _dragPosition 并重绘
    _offsetAnimation.addListener(_animationListener);
    // 添加动画状态监听器，当动画完成时调用 _handleAnimationComplete
    _offsetAnimation.addStatusListener(_animationStatusListener);
  }

  @override
  void didUpdateWidget(ShaderPageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool needsUpdate = false;

    // 当 widget 的属性更新时调用
    if (oldWidget.pageSize != widget.pageSize) {
      _currentSize = widget.pageSize;
      needsUpdate = true;
    }

    // 如果图片列表或初始页面索引发生变化，则更新页面状态
    if (oldWidget.images != widget.images ||
        oldWidget.initialPage != widget.initialPage) {
      _currentPageIndex = widget.initialPage.clamp(0, widget.images.length - 1);
      _updatePageImages();
      needsUpdate = true;
    }

    // 统一触发状态更新
    if (needsUpdate && mounted) {
      setState(() {});
    }
  }

  // 根据 _currentPageIndex 更新 _frontImage 和 _backImage
  void _updatePageImages() {
    if (widget.images.isEmpty) {
      // 如果图片列表为空，则清空前后图片
      _frontImage = null;
      _backImage = null;
      return;
    }
    // 设置当前页为正面图片
    _frontImage = widget.images[_currentPageIndex];
    // 设置下一页（或当前页，如果已是最后一页）为背面图片
    _backImage = _currentPageIndex + 1 < _totalPages
        ? widget.images[_currentPageIndex + 1]
        : widget.images[_currentPageIndex];
  }

  @override
  Widget build(BuildContext context) {
    // 如果正面或背面图片为空，或者图片列表为空，则显示提示信息或不显示任何内容
    if (_frontImage == null || _backImage == null || widget.images.isEmpty) {
      return SizedBox(
        width: _currentSize.width,
        height: _currentSize.height,
        child: const Center(child: Text("No images to display")), // Make const
      );
    }

    // 使用 GestureDetector 监听拖动手势
    return GestureDetector(
      onPanStart: (details) {
        // 检查是否可以翻页（例如，不是第一页尝试向前翻，或不是最后一页尝试向后翻）
        if (!_canFlipPage(details.localPosition)) {
          return; // 如果不能翻页，则不处理手势
        }
        // 如果当前正在执行动画禁止拖动
        if (_isAnimating) {
          return;
        }
        setState(() {
          _isDragging = true; // 标记开始拖动
          _dragStart = details.localPosition; // 记录拖动起始点
          _dragPosition = details.localPosition; // 初始化当前拖动点
          _velocity = Offset.zero; // 重置速度
          _updateBackImageOnDragStart(_dragStart); // 更新背面图片
        });
      },
      onPanUpdate: (details) {
        // 如果正在拖动且未在执行动画，则更新拖动位置
        if (!_isAnimating && _isDragging) {
          setState(() {
            _dragPosition = details.localPosition;
          });
        }
      },
      onPanEnd: (details) {
        if (!_isDragging) return; // 如果没有开始拖动（例如，只是点击），则不处理
        _velocity = details.velocity.pixelsPerSecond; // 获取拖动结束时的速度
        final speed = _velocity.distance; // 计算速度大小
        final targetPosition = _calculateAnimationTarget(); // 计算动画的目标位置
        // 如果速度过低，使用最小速度，否则使用实际速度
        final effectiveSpeed = speed < _minAnimationSpeed
            ? _minAnimationSpeed
            : speed;

        setState(() {
          _isDragging = false; // 标记拖动结束
          _isAnimating = true; // 标记动画开始
          _animationStartPosition = _dragPosition; // 动画起始位置为当前拖动位置
          _animationEndPosition = targetPosition; // 动画结束位置
        });
        // 启动惯性动画
        _startFlingAnimation(targetPosition, effectiveSpeed);
      },
      // 使用 ShaderBuilder 加载和应用片段着色器
      child: ShaderBuilder(
        assetKey: 'shaders/page_curl.frag', // 着色器文件路径
        (context, shader, child) {
          return AnimatedBuilder(
            animation: _offsetAnimation,
            builder: (BuildContext context, Widget? _) {
              // Wrap CustomPaint with RepaintBoundary
              return RepaintBoundary(
                child: CustomPaint(
                  // 使用 CustomPaint 进行自定义绘制
                  size: _currentSize, // 绘制区域大小
                  painter: ShaderPainter(
                    // 自定义的绘制器
                    shader: shader, // 传入加载好的着色器
                    frontImage: _frontImage!, // 正面图片
                    backImage: _backImage!, // 背面图片
                    mousePos:
                        _dragPosition, // 当前鼠标/触摸位置 (由 _animationListener 更新)
                    mouseStart: _dragStart, // 鼠标/触摸起始位置
                    isDragging: _isDragging || _isAnimating, // 是否正在拖动或动画中
                  ),
                ),
              );
            },
          );
        },
        // ShaderBuilder 的 child 参数，通常用于显示加载指示器等
        child: const Center(child: CircularProgressIndicator()), // Make const
      ),
    );
  }

  @override
  void dispose() {
    _flingController.dispose(); // 释放动画控制器资源
    _offsetAnimation.removeListener(_animationListener); // 移除监听器
    _offsetAnimation.removeStatusListener(_animationStatusListener); // 移除监听器
    super.dispose();
  }

  // 交换前后图片并更新页面索引，在翻页动画完成后调用
  void _swapImages() {
    // 判断是从右边还是左边开始翻页
    final isCurlFromRight = _dragStart.dx > _currentSize.width / 2;
    int newPageIndex = _currentPageIndex;

    if (isCurlFromRight) {
      // 从右向左翻页（下一页）
      if (_currentPageIndex < _totalPages - 1) {
        newPageIndex++;
      }
    } else {
      // 从左向右翻页（上一页）
      if (_currentPageIndex > 0) {
        newPageIndex--;
      }
    }

    // 如果页面索引发生变化，则更新状态并调用回调
    if (newPageIndex != _currentPageIndex) {
      _currentPageIndex = newPageIndex;
      _updatePageImages(); // 更新显示的图片

      // 延迟调用回调，确保状态更新完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPageChanged?.call(_currentPageIndex); // 通知父组件页面已更改
      });
    }
  }

  // 检查在给定位置是否可以开始翻页
  bool _canFlipPage(Offset position) {
    if (widget.images.length <= 1) return false; // 如果只有一页或没有页面，则不能翻页
    // 判断是从右边还是左边开始翻页
    final isCurlFromRight = position.dx > _currentSize.width / 2;
    if (isCurlFromRight) {
      // 尝试从右向左翻
      return _currentPageIndex < _totalPages - 1; // 必须有下一页
    } else {
      // 尝试从左向右翻
      return _currentPageIndex > 0; // 必须有上一页
    }
  }

  // 在拖动开始时，根据翻页方向更新背面图片
  void _updateBackImageOnDragStart(Offset startPosition) {
    final isCurlFromRight = startPosition.dx > _currentSize.width / 2;

    if (isCurlFromRight && _currentPageIndex < _totalPages - 1) {
      // 从右向左翻，背面是下一页
      _backImage = widget.images[_currentPageIndex + 1];
    } else if (!isCurlFromRight && _currentPageIndex > 0) {
      // 从左向右翻，背面是上一页
      _backImage = widget.images[_currentPageIndex - 1];
    }
  }

  // Helper methods for _shouldCompletePage
  bool _hasEnoughDragDistance(double dragDistance, double screenDiagonal) {
    final distanceThreshold = screenDiagonal * _kDistanceThresholdFactor;
    return dragDistance > distanceThreshold;
  }

  bool _hasEnoughDragSpeed(double speed) {
    return speed > _kSpeedThreshold;
  }

  bool _isCorrectDragDirection(Offset dragDirection, bool isCurlFromRight) {
    return isCurlFromRight
        ? dragDirection.dx < _kDragDirectionTolerance
        : dragDirection.dx > -_kDragDirectionTolerance;
  }

  double _getSpeedAdjustedDistanceThreshold(
    double baseDistanceThreshold,
    bool hasEnoughSpeed,
  ) {
    return hasEnoughSpeed
        ? baseDistanceThreshold * _kSpeedBasedDistanceFactor
        : baseDistanceThreshold;
  }

  bool _isLargeDrag(double dragDistance, double screenDiagonal) {
    return dragDistance > screenDiagonal * _kLargeDragFactor;
  }

  // 判断拖动是否足以触发完整的翻页动作
  bool _shouldCompletePage() {
    if (_dragStart == Offset.zero) return false; // 如果没有拖动起始点，则不翻页
    if (!_canFlipPage(_dragStart)) return false; // 如果从起始点就不能翻页，则不翻页

    final dragDistance = (_dragPosition - _dragStart).distance; // 计算拖动距离
    final screenDiagonal = math.sqrt(
      _currentSize.width * _currentSize.width +
          _currentSize.height * _currentSize.height,
    );
    final speed = _velocity.distance; // 获取拖动速度
    final dragDirection = _dragPosition - _dragStart; // 拖动方向向量
    final isCurlFromRight = _dragStart.dx > _currentSize.width / 2; // 是否从右侧开始翻页

    // 阈值和条件判断
    final hasEnoughDistance = _hasEnoughDragDistance(
      dragDistance,
      screenDiagonal,
    );
    final hasEnoughSpeed = _hasEnoughDragSpeed(speed);

    final baseDistanceThreshold = screenDiagonal * _kDistanceThresholdFactor;
    final speedAdjustedDistanceThreshold = _getSpeedAdjustedDistanceThreshold(
      baseDistanceThreshold,
      hasEnoughSpeed,
    );

    final isCorrectDirection = _isCorrectDragDirection(
      dragDirection,
      isCurlFromRight,
    );
    final isLargeDrag = _isLargeDrag(dragDistance, screenDiagonal);
    final finalDirectionCheck = isCorrectDirection || isLargeDrag;

    // 综合判断：方向基本正确，并且（距离足够 或 (速度足够且拖动超过速度调整后的距离阈值)）
    return finalDirectionCheck &&
        (hasEnoughDistance ||
            (hasEnoughSpeed && dragDistance > speedAdjustedDistanceThreshold));
  }

  // 计算翻页动画的目标位置
  Offset _calculateAnimationTarget() {
    if (_shouldCompletePage()) {
      // 如果判断应该完成翻页
      final isCurlFromRight = _dragStart.dx > _currentSize.width / 2;
      final halfHeight = _currentSize.height / 2;
      // 判断拖动起始点是否在垂直方向的中间区域
      final isNearVerticalCenter =
          (_dragStart.dy - halfHeight).abs() <
          halfHeight * _kVerticalCenterToleranceFactor; // 30% 容差

      if (isNearVerticalCenter) {
        // 如果起始点在垂直中线附近
        // 目标位置设为对应边界的中点
        return Offset(isCurlFromRight ? 0 : _currentSize.width, halfHeight);
      } else {
        // 如果起始点偏上或偏下
        // 目标位置设为对应边界的对角点
        final targetY = _dragStart.dy < halfHeight ? 0.0 : _currentSize.height;
        return Offset(isCurlFromRight ? 0 : _currentSize.width, targetY);
      }
    } else {
      // 如果不应完成翻页，则动画目标为回到拖动起始位置
      return _dragStart;
    }
  }

  // 启动惯性动画
  void _startFlingAnimation(Offset targetPosition, double speed) {
    // 根据速度和距离动态调整动画时长，使动画更流畅
    final distance = (_animationStartPosition - _animationEndPosition).distance;
    final screenDiagonal = math.sqrt(
      _currentSize.width * _currentSize.width +
          _currentSize.height * _currentSize.height,
    );

    // 基于距离和速度的动态时长计算
    final baseDuration = math.max(
      _kMinAnimationDurationMs, // 最小动画时长
      math.min(
        _kBaseMaxAnimationDurationMs,
        (distance / screenDiagonal * _kDurationDistanceFactor +
                _kDurationSpeedDivisor / speed)
            .round(),
      ), // 动态计算
    );
    final duration = Duration(milliseconds: baseDuration);
    _flingController.duration = duration; // 设置动画控制器时长

    // 更新动画的起始点和结束点
    // 注意：_animationStartPosition 和 _animationEndPosition 应该在调用此方法前已在 setState 中设置
    _offsetAnimation =
        Tween<Offset>(
          begin: _animationStartPosition, // 动画起始于当前拖动位置
          end: _animationEndPosition, // 动画结束于计算出的目标位置
        ).animate(
          CurvedAnimation(
            parent: _flingController,
            curve: Curves.fastOutSlowIn, // 使用快出慢入曲线
          ),
        );
    // 移除旧的监听器，防止重复添加或监听旧的动画实例
    _offsetAnimation.removeListener(_animationListener);
    _offsetAnimation.removeStatusListener(_animationStatusListener);
    // 添加新的监听器到新的动画实例
    _offsetAnimation.addListener(_animationListener);
    _offsetAnimation.addStatusListener(_animationStatusListener);

    _flingController.forward(from: 0.0); // 从头开始播放动画
  }

  // 动画监听器回调，在动画每一帧更新时调用
  void _animationListener() {
    if (mounted) {
      // 更新拖动位置，AnimatedBuilder 将处理重绘
      _dragPosition = _offsetAnimation.value; // 更新拖动位置为当前动画值
      // setState(() {}); // 触发重绘 - 由 AnimatedBuilder 处理
    }
  }

  // 动画状态监听器回调
  void _animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // 当动画完成时
      _handleAnimationComplete(); // 处理动画完成后的逻辑
    }
  }

  // 处理动画完成后的逻辑
  void _handleAnimationComplete() {
    // 在重置状态前，根据动画结束时的位置重新判断是否应该完成翻页
    final shouldComplete = _shouldCompletePage();

    // 先更新动画状态
    _isAnimating = false;

    if (shouldComplete) {
      // 如果确定要完成翻页，先交换图片
      _swapImages();
    } else {
      // 如果动画是回弹（未完成翻页），确保图片状态正确
      _updatePageImages();
    }

    // 重置拖动和动画相关的状态变量
    _dragPosition = Offset.zero;
    _dragStart = Offset.zero;
    _velocity = Offset.zero;

    // 统一触发UI更新，避免多次setState
    if (mounted) {
      setState(() {});
    }
  }
}
