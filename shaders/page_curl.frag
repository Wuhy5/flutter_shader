#version 460

#include <flutter/runtime_effect.glsl>

// 定义渲染分辨率uniform变量
uniform vec2 iResolution; // 渲染分辨率
// 定义鼠标位置和状态uniform变量
uniform vec4 iMouse; // 鼠标位置和状态 xy: 鼠标位置, zw: 鼠标起始点击位置
// 定义正面纹理采样器
uniform sampler2D iChannel0; // 正面纹理
// 定义背面纹理采样器
uniform sampler2D iChannel1; // 背面纹理
// 定义翻页方向控制变量
uniform float iCurlDirection; // 翻页方向：1.0 表示从左向右翻页，-1.0 表示从右向左翻页

// 定义数学常数圆周率（注意：这会覆盖第16行的pi定义）
const float pi = 3.14159265359; // 圆周率
// 定义翻页效果的曲率半径
const float radius = 0.05; // 翻页曲率半径
// 定义阴影效果的宽度
const float shadowWidth = 0.02; // 阴影宽度
// 定义轨道线的显示厚度
const float trackLineThickness = 0.002; // 轨道线的厚度
// 定义调试点的显示大小
const float pointSize = 0.01; // 点的大小
// 定义调试线条的显示厚度
const float lineThickness = 0.003; // 线条厚度

// 阴影参数
const vec2 shadowOffset = vec2(0.005, -0.003); // 阴影偏移
const float shadowIntensity = 0.3;             // 阴影强度

// 抗锯齿参数
// 抗锯齿采样数（2x2 = 4个采样点）
const int aasamples = 3;
// 抗锯齿采样范围
// 每个采样点的宽度
const float aawidth = 0.7;

// 显示调试信息的开关
const bool showDebug = true; // 是否显示调试信息

// 定义片段着色器输出颜色
out vec4 fragColor;


/**
 * 绘制限制轨道圆
 * 用于调试显示圆形轨道边界
 * @param uv 纹理坐标
 * @param center 圆心
 * @param arcRadius 圆弧半径
 * @param aspect 宽高比
 * @return 是否在轨道线上
 */
bool drawTrackCircle(vec2 uv, vec2 center, float arcRadius, float aspect) {
    // 计算当前点到圆心的距离
    float dist = distance(uv, center);
    // 判断距离是否接近圆弧半径，在误差范围内则认为在轨道线上
    return abs(dist - arcRadius) < trackLineThickness;
}

/**
 * 绘制调试点
 * 用于在着色器中显示特定位置的调试点
 * @param uv 纹理坐标
 * @param point 点位置
 * @return 是否在点上
 */
bool drawPoint(vec2 uv, vec2 point) {
    // 判断当前位置是否在指定点的显示范围内
    return distance(uv, point) < pointSize;
}

/**
 * 绘制调试线段
 * 用于在着色器中显示两点之间的连线
 * @param uv 纹理坐标
 * @param start 起始点
 * @param end 结束点
 * @return 是否在线段上
 */
bool drawLine(vec2 uv, vec2 start, vec2 end) {
    // 计算线段方向向量
    vec2 line = end - start;
    // 计算当前点相对于起始点的向量
    vec2 toPoint = uv - start;
    // 计算当前点在线段上的投影参数，限制在[0,1]范围内
    float t = clamp(dot(toPoint, line) / dot(line, line), 0.0, 1.0);
    // 计算线段上距离当前点最近的点
    vec2 closestPoint = start + t * line;
    // 判断当前点是否在线段的显示厚度范围内
    return distance(uv, closestPoint) < lineThickness;
}

/**
 * 绘制角度范围（扇形区域边界）
 * 用于显示扇形区域的边界线
 * @param uv 纹理坐标
 * @param center 圆心
 * @param direction 基准方向
 * @param angleRange 角度范围（弧度）
 * @param radiusLimit 半径限制
 * @return 是否在扇形边界上
 */
bool drawAngleRange(vec2 uv, vec2 center, vec2 direction, float angleRange, float radiusLimit) {
    // 计算从圆心到当前点的向量
    vec2 toUv = uv - center;
    // 计算距离
    float dist = length(toUv);

    // 如果距离超出半径限制或太接近圆心，则不在边界上
    if (dist > radiusLimit || dist < 0.01) return false;

    // 归一化方向向量
    vec2 normalizedToUv = normalize(toUv);
    vec2 normalizedDir = normalize(direction);

    // 计算当前点与基准方向的夹角
    float angle = acos(clamp(dot(normalizedToUv, normalizedDir), -1.0, 1.0));

    // 使用叉积判断方向（用于确定角度的正负）
    float cross = normalizedToUv.x * normalizedDir.y - normalizedToUv.y * normalizedDir.x;

    // 判断是否在扇形的两个边界线上，并且距离接近半径限制
    return (abs(angle - angleRange) < 0.05 || abs(angle + angleRange) < 0.05) && abs(dist - radiusLimit) < lineThickness * 2.0;
}

/**
 * 检查点是否在扇形区域内
 * 用于判断某个点是否位于指定的扇形范围内
 * @param uv 纹理坐标
 * @param center 圆心
 * @param direction 基准方向
 * @param angleRange 角度范围（弧度）
 * @param radiusLimit 半径限制
 * @return 是否在扇形区域内
 */
bool isInAngleRange(vec2 uv, vec2 center, vec2 direction, float angleRange, float radiusLimit) {
    // 计算从圆心到当前点的向量
    vec2 toUv = uv - center;
    // 计算距离
    float dist = length(toUv);

    // 如果距离超出半径限制或太接近圆心，则不在区域内
    if (dist > radiusLimit || dist < 0.01) return false;

    // 归一化方向向量
    vec2 normalizedToUv = normalize(toUv);
    vec2 normalizedDir = normalize(direction);

    // 计算夹角
    float angle = acos(clamp(dot(normalizedToUv, normalizedDir), -1.0, 1.0));

    // 判断角度是否在允许范围内
    return angle <= angleRange;
}

/**
 * 计算改进的阴影强度
 * 使用平滑过渡和偏移的高级阴影算法
 * @param targetPoint 目标点位置
 * @param aspect 宽高比
 * @return 返回阴影强度 (0.0 = 完全阴影, 1.0 = 无阴影)
 */
float calculateAdvancedShadow(vec2 targetPoint, float aspect) {
    // 计算阴影偏移后的位置
    vec2 shadowPoint = targetPoint + shadowOffset;

    // 检查是否在页面边界外

    if (!(shadowPoint.x < 0.0 || shadowPoint.x > aspect || shadowPoint.y < 0.0 || shadowPoint.y > 1.0)) {
        return 1.0; // 在边界内，无阴影
    }

    // 计算到边界的距离
    float distToBoundary = 0.0;

    // X方向边界距离
    if (shadowPoint.x < 0.0) {
        distToBoundary = max(distToBoundary, abs(shadowPoint.x));
    } else if (shadowPoint.x > aspect) {
        distToBoundary = max(distToBoundary, shadowPoint.x - aspect);
    }

    // Y方向边界距离
    if (shadowPoint.y < 0.0) {
        distToBoundary = max(distToBoundary, abs(shadowPoint.y));
    } else if (shadowPoint.y > 1.0) {
        distToBoundary = max(distToBoundary, shadowPoint.y - 1.0);
    }

    // 使用平滑步进函数创建渐变阴影
    float shadowFactor = 1.0 - smoothstep(0.0, shadowWidth, distToBoundary);

    // 应用阴影强度并确保最小亮度
    return mix(1.0 - shadowIntensity, 1.0, 1.0 - shadowFactor);
}

/**
 * 旋转二维向量
 * 将二维向量按指定角度进行旋转变换
 * @param v 输入向量
 * @param a 旋转角度
 * @return 旋转后的向量
 */
vec2 rotate(vec2 v, float a) {
    // 计算旋转角度的正弦值
    float s = sin(a); // 计算正弦
    // 计算旋转角度的余弦值
    float c = cos(a); // 计算余弦
    // 应用二维旋转矩阵变换
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y); // 应用旋转矩阵
}

/**
 * 计算圆上的点
 * 根据起始点、弧长等参数计算圆弧上的目标点位置
 * @param center 圆心
 * @param startPoint 起始点
 * @param currentRadius 当前半径
 * @param arcLength 弧长
 * @param clockwise 是否顺时针
 * @return 圆上的目标点
 */
vec2 pointOnCircle(vec2 center, vec2 startPoint, float currentRadius, float arcLength, bool clockwise) {
    // 根据弧长和半径计算旋转角度
    float theta = arcLength / currentRadius; // 计算角度
    // 计算从圆心到起始点的向量
    vec2 startVec = startPoint - center; // 起始向量
    // 将起始向量归一化为单位向量
    startVec = normalize(startVec); // 归一化
    // 根据顺时针或逆时针确定旋转方向
    float rotationAngle = clockwise ? -theta : theta; // 判断旋转方向
    // 将起始向量按计算出的角度进行旋转
    vec2 rotatedVec = rotate(startVec, rotationAngle); // 旋转向量
    // 根据圆心、旋转后的方向向量和半径计算最终点位置
    vec2 endPoint = center + rotatedVec * currentRadius; // 得到终点
    // 返回计算得到的圆弧上的点
    return endPoint; // 返回终点
}



/**
 * 转换坐标到纹理坐标
 * 将世界坐标转换为适合纹理采样的归一化坐标
 * @param coord 输入坐标
 * @param aspect 宽高比
 * @return 纹理坐标
 */
vec2 toTexCoord(vec2 coord, float aspect) {
    // 根据宽高比调整x坐标，保持y坐标不变
    return coord * vec2(1.0 / aspect, 1.0);
}

/**
 * 检查点是否在有效范围内
 * 判断给定点是否在页面的有效显示区域内
 * @param p 待检查的点
 * @param aspect 宽高比
 * @return 是否在范围内
 */
bool isInBounds(vec2 p, float aspect) {
    // 检查x坐标是否在[0, aspect]范围内，y坐标是否在[0, 1]范围内
    return p.x > 0.0 && p.x <= aspect && p.y > 0.0 && p.y <= 1.0;
}

/**
 * 检查点是否在阴影范围内
 * 根据翻页方向判断点是否在扩展的阴影显示区域内
 * @param p 待检查的点
 * @param aspect 宽高比
 * @param direction 翻页方向
 * @return 是否在阴影范围内
 */
bool isInShadowBounds(vec2 p, float aspect, float direction) {
    // 根据翻页方向判断阴影区域
    if (direction == -1.0) {
        // 从右往左翻页时的阴影范围计算
        // x坐标扩展阴影宽度到左侧和右侧
        // y坐标扩展阴影宽度到上下两侧
        return p.x > 0.0 - shadowWidth && p.x <= aspect + shadowWidth &&
        p.y > 0.0 - shadowWidth && p.y <= 1.0 + shadowWidth;
    } else {
        // 从左往右翻页时的阴影范围计算
        // x坐标从阴影宽度开始到右侧扩展
        // y坐标扩展阴影宽度到上下两侧
        return p.x > 0.0 - shadowWidth && p.x <= aspect + shadowWidth &&
        p.y > 0.0 - shadowWidth && p.y <= 1.0 + shadowWidth;
    }
}

/**
 * 核心翻页渲染函数
 * 计算单个采样点的翻页效果颜色
 * @param fragCoord 片段坐标
 * @return 渲染结果颜色
 */
vec4 renderPageCurl(vec2 fragCoord) {
    // 计算屏幕的宽高比
    float aspect = iResolution.x / iResolution.y; // 计算宽高比
    // 将屏幕坐标转换为归一化的纹理坐标
    vec2 uv = fragCoord * vec2(aspect, 1.0) / iResolution.xy; // 归一化纹理坐标

//    vec2 cornerFrom = (currentMouse.w<resolution.y/2)?vec2(aspect, 0.0):vec2(aspect, 1.0);

    // 获取翻页起始角落位置
    // 计算屏幕高度的一半，用于判断鼠标在上半部分还是下半部分
    float halfHeight = iResolution.y / 2.0; // 半屏高度

    // 将鼠标坐标从屏幕空间转换到纹理空间
    vec2 mouse = iMouse.xy * vec2(aspect, 1.0) / iResolution.xy;

    // 获取鼠标方向向量
    // 声明鼠标移动方向向量
    vec2 mouseDir = normalize(abs(iMouse.zw) - iMouse.xy);

    // 获取翻页辅助计算起点
    // 声明翻页效果的计算原点
    vec2 origin;
    // 根据翻页方向计算翻页效果的原点位置
    if (iCurlDirection == -1.0) {
        // 从右往左翻页时，计算原点并限制在有效范围内
        origin = clamp(mouse - mouseDir * mouse.x / mouseDir.x, 0.0, 1.0);
    } else {
        // 从左往右翻页时，计算原点并限制在有效范围内
        origin = clamp(mouse - mouseDir * (mouse.x - aspect) / mouseDir.x, 0.0, 1.0);
    }

    // 计算鼠标位置到原点的距离
    // 计算翻页距离
    float mouseDist;
    // 从右往左翻页时，计算鼠标到原点的距离
    mouseDist = clamp(length(mouse - origin) +
                      (aspect - (abs(iMouse.z) / iResolution.x) * aspect) / mouseDir.x, 0.0, aspect / mouseDir.x);
    // 处理特殊方向情况
    if (mouseDir.x < 0.) {
        mouseDist = distance(mouse, origin);
    }
    // 计算当前UV点在翻页方向上的投影距离
    float proj = dot(uv - origin, mouseDir); // UV点在翻页方向上的投影距离
    // 计算当前点到翻页轴线的距离
    float dist = proj - mouseDist; // 距离
    // 计算翻页轴线上对应的点位置
    vec2 curlAxisLinePoint = uv - dist * mouseDir; // 翻页轴线点

    // 为纹理采样准备共享的纹理坐标
    vec2 texCoord = toTexCoord(uv, aspect);

    // 声明结果颜色
    vec4 result;

    // 计算翻页的圆柱体映射点并选择合适的纹理
    // 判断当前点位于翻页效果的哪个区域
    if (dist > radius) {
        // 背面区域 - 显示背面纹理
        // 从背面纹理采样颜色
        result = texture(iChannel1, texCoord);
        result.rgb *= pow(clamp(dist - radius, 0., 1.) * 1.5, .2); // 距离越远越暗
    } else if (dist >= 0.0) {
        // 弯曲区域 - 翻页过渡区域
        // 计算弯曲角度
        float theta = asin(dist / radius);
        // 计算弯曲后映射到的两个可能位置
        vec2 p2 = curlAxisLinePoint + mouseDir * (pi - theta) * radius;
        vec2 p1 = curlAxisLinePoint + mouseDir * theta * radius;

        // 判断使用哪个映射点（优先使用在有效范围内的点）
        bool useP2 = isInBounds(p2, aspect);
        vec2 samplePoint = useP2 ? p2 : p1;
        // 从正面纹理采样颜色
        result = texture(iChannel0, toTexCoord(samplePoint, aspect));
        result.rgb *= pow(clamp((radius - dist) / radius, 0.0, 1.0), 0.2); // 根据曲率调整亮度

        // 检查是否在阴影范围内
        if (!useP2) {
            // 超出范围，检查是否需要应用阴影效果
            float shadowFactor = 1.0;
            if (isInShadowBounds(p2, aspect, iCurlDirection)) {
                // 计算改进的阴影强度
                shadowFactor = calculateAdvancedShadow(p2, aspect);
            }
            // 应用光照和阴影
            result *= shadowFactor; // 应用阴影强度
        }
    } else {
        // 正面区域 - 显示正面纹理
        // 计算正面区域映射后的位置
        vec2 p = curlAxisLinePoint + mouseDir * (abs(dist) + pi * radius);
        bool isInBoundsP = isInBounds(p, aspect);
        result = isInBoundsP ? texture(iChannel0, toTexCoord(p, aspect)) : texture(iChannel0, texCoord);
        // 判断映射位置是否在有效范围内
        if (!isInBoundsP) {
            float shadowFactor = 1.0;
            if (isInShadowBounds(p, aspect, iCurlDirection)) {
                // 计算改进的阴影强度
                shadowFactor = calculateAdvancedShadow(p, aspect);
            }
            result *= shadowFactor; // 应用阴影强度
        }
    }

    return result;
}

/**
 * 主函数，计算每个像素的颜色（带抗锯齿）
 * 着色器的入口函数，负责计算翻页效果的每个像素颜色
 */
void main() {
    // 获取当前片段的屏幕坐标
    vec2 fragCoord = FlutterFragCoord().xy;

    // 抗锯齿处理：多重采样
    vec4 vs = vec4(0.0);
    int totalSamples = aasamples * aasamples;

    for (int j = 0; j < aasamples; j++) {
        float oy = float(j) * aawidth / max(float(aasamples - 1), 1.0);
        for (int i = 0; i < aasamples; i++) {
            float ox = float(i) * aawidth / max(float(aasamples - 1), 1.0);
            // 对每个子像素位置进行采样
            vs += renderPageCurl(fragCoord + vec2(ox, oy));
        }
    }

    // 平均所有采样结果
    vs = vs / vec4(aasamples * aasamples);

    if (showDebug) {
        // 计算用于调试显示的坐标
        float aspect = iResolution.x / iResolution.y;
        vec2 uv = fragCoord * vec2(aspect, 1.0) / iResolution.xy;
        vec2 mouse = iMouse.xy * vec2(aspect, 1.0) / iResolution.xy;
        vec2 mouseDir = normalize(abs(iMouse.zw) - iMouse.xy);

        // 计算翻页原点
        vec2 origin;
        if (iCurlDirection == -1.0) {
            origin = clamp(mouse - mouseDir * mouse.x / mouseDir.x, 0.0, 1.0);
        } else {
            origin = clamp(mouse - mouseDir * (mouse.x - aspect) / mouseDir.x, 0.0, 1.0);
        }

        // 计算翻页距离和轴线点
        float mouseDist;
        mouseDist = clamp(length(mouse - origin) +
                          (aspect - (abs(iMouse.z) / iResolution.x) * aspect) / mouseDir.x, 0.0, aspect / mouseDir.x);
        if (mouseDir.x < 0.) {
            mouseDist = distance(mouse, origin);
        }
        float proj = dot(uv - origin, mouseDir);
        float dist = proj - mouseDist;
        vec2 curlAxisLinePoint = uv - dist * mouseDir;

        // 调试显示（可选）
        // 画origin点 - 用绿色高亮显示翻页起点
        if (drawPoint(uv, origin)) {
            vs = mix(vs, vec4(0.0, 1.0, 0.0, 1.0), 0.7);
        }

        // 绘制调试用的翻页轴线 - 用粉色高亮显示
        if (drawLine(uv, curlAxisLinePoint, mouse)) {
            vs = mix(vs, vec4(1.0, 0.0, 1.0, 1.0), 0.5);
        }
    }

    // 输出最终颜色
    fragColor = vs;
}