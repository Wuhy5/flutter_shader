import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image frontImage;
  final ui.Image backImage;
  final Offset mousePos;
  final Offset mouseStart;
  final bool isDragging;
  Size lastSize = Size.zero;

  ShaderPainter({
    required this.shader,
    required this.frontImage,
    required this.backImage,
    required this.mousePos,
    required this.mouseStart,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    lastSize = size;

    // 设置着色器输入参数
    shader.setFloat(0, size.width); // iResolution.x
    shader.setFloat(1, size.height); // iResolution.y    // 设置鼠标位置
    shader.setFloat(2, isDragging ? mousePos.dx : size.width); // iMouse.x
    shader.setFloat(3, isDragging ? mousePos.dy : 0); // iMouse.y
    shader.setFloat(4, isDragging ? mouseStart.dx : size.width); // iMouse.z
    shader.setFloat(5, isDragging ? mouseStart.dy : 0.0); // iMouse.w

    // 设置前后图片
    shader.setImageSampler(0, frontImage); // iFrontImage
    shader.setImageSampler(1, backImage); // iBackImage

    // 判断是否从左向右翻页或从右向左翻页
    // 1.0 表示从左向右翻页，-1.0 表示从右向左翻页
    final iCurlDirection = mouseStart.dx > size.width / 2 ? -1.0 : 1.0;
    if (isDragging) {
      shader.setFloat(
        6,
        iCurlDirection > 0 ? 1.0 : -1.0, // 根据鼠标位置判断翻页方向
      ); // iCurlDirection
    } else {
      shader.setFloat(6, -1.0); // 默认从左向右翻页
    }

    // 绘制全屏矩形
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    print(
      '绘制着色器，鼠标位置: $mousePos, 起始位置: $mouseStart, 是否拖动: $isDragging , 翻页方向: ${iCurlDirection > 0 ? '左向右' : '右向左'}',
    );
  }

  @override
  bool shouldRepaint(ShaderPainter oldDelegate) {
    // 重新绘制条件：鼠标位置、拖动状态、起始位置或大小发生变化
    return oldDelegate.mousePos != mousePos ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.mouseStart != mouseStart ||
        oldDelegate.lastSize != lastSize ||
        oldDelegate.frontImage != frontImage ||
        oldDelegate.backImage != backImage;
  }
}
