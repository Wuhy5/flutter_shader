#include <flutter/runtime_effect.glsl>

// 定义渲染分辨率uniform变量
uniform vec2 iResolution;
// 定义鼠标位置和状态uniform变量
// 鼠标位置和状态 xy: 鼠标位置, zw: 鼠标起始点击位置
uniform vec4 iMouse;
// 定义正面纹理采样器
uniform sampler2D iChannel0;
// 定义背面纹理采样器
uniform sampler2D iChannel1;
// 定义翻页方向控制变量 1.0 表示从左向右翻页，-1.0 表示从右向左翻页
uniform float iCurlDirection;

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

// 抗锯齿模式选择
// 0: 无抗锯齿, 1: 优化MSAA, 2: 原始MSAA
const int aaMode = 0;

// 原始MAAA抗锯齿参数
// 抗锯齿采样数（2x2 = 4个采样点）
// 越高的值会增加抗锯齿效果，但也会增加计算开销
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
 * 检查origin点是否在4个对角
 * 判断origin点是否位于屏幕的4个角落区域
 * @param origin origin点坐标
 * @param aspect 宽高比
 * @return 是否在对角区域
 */
bool isOriginInCorner(vec2 origin, float aspect) {
    const float cornerThreshold = 0.1; // 角落区域的阈值
    
    // 检查是否在左上角
    if (origin.x <= cornerThreshold && origin.y <= cornerThreshold) return true;
    // 检查是否在右上角
    if (origin.x >= aspect - cornerThreshold && origin.y <= cornerThreshold) return true;
    // 检查是否在左下角
    if (origin.x <= cornerThreshold && origin.y >= 1.0 - cornerThreshold) return true;
    // 检查是否在右下角
    if (origin.x >= aspect - cornerThreshold && origin.y >= 1.0 - cornerThreshold) return true;
    
    return false;
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
 * 计算阴影强度
 * 计算给定目标点处的阴影强度
 * @param targetPoint 目标点
 * @param aspect 宽高比
 * @return 阴影强度
 */
float calShadow(vec2 targetPoint, float aspect) {
    if (iCurlDirection == -1.0) {
        if (targetPoint.y >= 1.0) {
            return max(pow(clamp((targetPoint.y - 1.0) / shadowWidth, 0.0, 0.9), 0.2), pow(clamp((targetPoint.x - aspect) / shadowWidth, 0.0, 0.9), 0.2));
        } else {
            return max(pow(clamp((0.0 - targetPoint.y) / shadowWidth, 0.0, 0.9), 0.2), pow(clamp((targetPoint.x - aspect) / shadowWidth, 0.0, 0.9), 0.2));
        }
    } else {
        if (targetPoint.y >= 1.0) {
            return max(pow(clamp((targetPoint.y - 1.0) / shadowWidth, 0.0, 0.9), 0.2), pow(clamp((-targetPoint.x) / shadowWidth, 0.0, 0.9), 0.2));
        } else {
            return max(pow(clamp((0.0 - targetPoint.y) / shadowWidth, 0.0, 0.9), 0.2), pow(clamp((-targetPoint.x) / shadowWidth, 0.0, 0.9), 0.2));
        }
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

    // 获取翻页起始角落位置
    // 计算屏幕高度的一半，用于判断鼠标在上半部分还是下半部分
    float halfHeight = iResolution.y / 2.0; // 半屏高度

    // 将鼠标坐标从屏幕空间转换到纹理空间
    vec2 mouse = iMouse.xy * vec2(aspect, 1.0) / iResolution.xy;

    // 获取鼠标方向向量
    // 声明鼠标移动方向向量
    vec2 mouseDir = normalize(abs(iMouse.zw) - iMouse.xy);

    // 声明翻页效果的计算原点
    vec2 origin;
    if (iCurlDirection == -1.0) {
        // 从右向左翻页，origin在x=0边界
        float t = -mouse.x / mouseDir.x;
        origin = mouse + t * mouseDir;
        origin.x = 0.0; // 确保x坐标在左边界
        origin.y = clamp(origin.y, 0.0, 1.0); // 仅限制y坐标
    } else {
        // 从左向右翻页，origin在x=aspect边界
        float t = (aspect - mouse.x) / mouseDir.x;
        origin = mouse + t * mouseDir;
        origin.x = aspect; // 确保x坐标在右边界
        origin.y = clamp(origin.y, 0.0, 1.0); // 仅限制y坐标
    }

    // 只有当origin点在4个对角时，才应用鼠标位置约束
    if (isOriginInCorner(origin, aspect)) {
        vec2 cornerFrom = (iMouse.w < iResolution.y / 2.0) ? vec2(aspect, 0.0) : vec2(aspect, 1.0);
        
        // 鼠标位置跟左上角的距离大于aspect，才会发生翻页范围大于屏幕
        if (distance(mouse.xy, vec2(0.0, cornerFrom.y)) > aspect) {
            // 修复规则，结合两个部分：
            // 1. 如果触摸点位置位于左上角向右下角60度的直线上，那么将触摸点改为半径aspect的那个弧线跟60度直线的交点
            // 2. 如果不在上述60度的直线上，那么取当前触摸点跟60度直线的距离，与半径aspect的弧度的距离，这两者取较小值
            // 3. 获取到第二步的数值后，以当前触摸点跟左上角的直线与半径aspect的弧线的交点为基准，根据获取到的值进行一定的偏移

            vec2 startPoint = vec2(0.0, cornerFrom.y == 0.0 ? 0.0 : 1.0);
            vec2 vector = normalize(vec2(0.5, 0.5 * tan(pi / 3.0)));

            vec2 targetMouse = mouse.xy;

            vec2 v = targetMouse - startPoint;
            float proj_length = dot(v, vector);
            vec2 targetMouse_proj = startPoint + proj_length * vector;

            // 距离基准直线的距离
            float base_line_distance = length(targetMouse_proj - targetMouse);
            // 当前触摸点距离弧线距离
            float arc_distance = distance(targetMouse, startPoint) - aspect;
            // 取小值
            float actual_distance = min(abs(base_line_distance), abs(arc_distance));

            // 当前触摸点对应在弧线上的映射点
            vec2 currentMouse_arc_proj = startPoint + normalize(mouse - startPoint) * aspect;

            vec2 newPoint_arc_proj = pointOnCircle(startPoint, currentMouse_arc_proj, aspect, actual_distance / 2.0, mouse.y <= tan(pi / 3.0) * mouse.x);

            // 根据最新计算结果，修正鼠标参数
            mouse = newPoint_arc_proj;
        }
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
        result = texture(iChannel1, texCoord);
        result.rgb *= pow(clamp(dist - radius, 0., 1.) * 1.5, 0.1); // 距离越远变暗效果更强，防止泛白
    } else if (dist >= 0.0) {
        // 弯曲区域 - 翻页过渡区域
        float theta = asin(dist / radius);
        vec2 p2 = curlAxisLinePoint + mouseDir * (pi - theta) * radius;
        vec2 p1 = curlAxisLinePoint + mouseDir * theta * radius;

        if (isInBounds(p2, aspect)) {
            result = texture(iChannel0, toTexCoord(p2, aspect));
            result.rgb *= pow(clamp((radius - dist) / radius, 0.0, 1.0), 0.2); // 应用弯曲区域的亮度调整
        } else {
            // p2 不在界内，使用 p1 采样
            result = texture(iChannel0, toTexCoord(p1, aspect));
            // 检查 p2 是否在阴影投射范围内
            if ((p2.x <= aspect + shadowWidth && p2.x >= 0.0 - shadowWidth && p2.y <= 1.0 + shadowWidth && p2.y >= 0.0 - shadowWidth)) {
                float shadowFactor = calShadow(p2, aspect);
                result.rgb *= shadowFactor;
            }
        }
    } else {
        // 正面区域 - 显示正面纹理
        vec2 p = curlAxisLinePoint + mouseDir * (abs(dist) + pi * radius);
        if (isInBounds(p, aspect)) {
            result = texture(iChannel0, toTexCoord(p, aspect));
        } else {
            // p 不在界内，采样原始 uv (texCoord)
            result = texture(iChannel0, texCoord);
            // 检查 p 是否在阴影投射范围内
            if (p.x <= aspect + shadowWidth && p.x >= 0.0 - shadowWidth && p.y <= 1.0 + shadowWidth && p.y >= 0.0 - shadowWidth) {
                float shadowFactor = calShadow(p, aspect);
                result.rgb *= shadowFactor;
            }
        }
    }

    return result;
}

/**
 * 优化的多重采样抗锯齿
 * 使用预定义的采样模式，而不是规则网格
 * @param fragCoord 片段坐标
 * @return 抗锯齿后的颜色
 */
vec4 optimizedMSAA(vec2 fragCoord) {
    // 4x MSAA 采样点（Rotated Grid）- 使用SkSL兼容的方式
    vec4 result = vec4(0.0);

    // 直接计算每个采样点，避免数组初始化
    result += renderPageCurl(fragCoord + vec2(-0.375, -0.125)); // 左上
    result += renderPageCurl(fragCoord + vec2(0.125, -0.375));  // 右上
    result += renderPageCurl(fragCoord + vec2(-0.125, 0.375));  // 左下
    result += renderPageCurl(fragCoord + vec2(0.375, 0.125));   // 右下

    return result * 0.25; // 平均
}

/**
 * 主函数，计算每个像素的颜色（带抗锯齿）
 * 着色器的入口函数，负责计算翻页效果的每个像素颜色
 */
void main() {
    // 获取当前片段的屏幕坐标
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 texelSize = 1.0 / iResolution.xy;
    vec4 vs;

    // 根据模式选择抗锯齿方法
    if (aaMode == 0) {
        // 无抗锯齿
        vs = renderPageCurl(fragCoord);
    } else if (aaMode == 1) {
        // 优化的MSAA - 性能中等
        vs = optimizedMSAA(fragCoord);
    } else {
        // 原始MSAA方法
        vs = vec4(0.0);
        for (int j = 0; j < aasamples; j++) {
            float oy = float(j) * aawidth / max(float(aasamples - 1), 1.0);
            for (int i = 0; i < aasamples; i++) {
                float ox = float(i) * aawidth / max(float(aasamples - 1), 1.0);
                vs += renderPageCurl(fragCoord + vec2(ox, oy));
            }
        }
        vs = vs / vec4(aasamples * aasamples);
    }

    if (showDebug) {
        // 计算用于调试显示的坐标
        float aspect = iResolution.x / iResolution.y;
        vec2 normalization = vec2(aspect, 1.0) / iResolution.xy;
        vec2 uv = fragCoord * normalization;
        vec2 mouse = iMouse.xy * normalization;
        vec2 mouseStart = iMouse.zw * normalization;
        vec2 mouseDir = normalize(abs(iMouse.zw) - iMouse.xy);

        // 声明翻页效果的计算原点
        vec2 origin;
        if (iCurlDirection == -1.0) {
            // 从右向左翻页，origin在x=0边界
            float t = -mouse.x / mouseDir.x;
            origin = mouse + t * mouseDir;
            origin.x = 0.0; // 确保x坐标在左边界
            origin.y = clamp(origin.y, 0.0, 1.0); // 仅限制y坐标
        } else {
            // 从左向右翻页，origin在x=aspect边界
            float t = (aspect - mouse.x) / mouseDir.x;
            origin = mouse + t * mouseDir;
            origin.x = aspect; // 确保x坐标在右边界
            origin.y = clamp(origin.y, 0.0, 1.0); // 仅限制y坐标
        }

        // 只有当origin点在4个对角时，才应用鼠标位置约束
        if (isOriginInCorner(origin, aspect)) {
            vec2 cornerFrom = (iMouse.w < iResolution.y / 2.0) ? vec2(aspect, 0.0) : vec2(aspect, 1.0);
            
            if (distance(mouse.xy, vec2(0.0, cornerFrom.y)) > aspect) {
                vec2 startPoint = vec2(0.0, cornerFrom.y == 0.0 ? 0.0 : 1.0);
                vec2 vector = normalize(vec2(0.5, 0.5 * tan(pi / 3.0)));

                vec2 targetMouse = mouse.xy;

                vec2 v = targetMouse - startPoint;
                float proj_length = dot(v, vector);
                vec2 targetMouse_proj = startPoint + proj_length * vector;

                float base_line_distance = length(targetMouse_proj - targetMouse);
                float arc_distance = distance(targetMouse, startPoint) - aspect;
                float actual_distance = min(abs(base_line_distance), abs(arc_distance));

                vec2 currentMouse_arc_proj = startPoint + normalize(mouse - startPoint) * aspect;
                vec2 newPoint_arc_proj = pointOnCircle(startPoint, currentMouse_arc_proj, aspect, actual_distance / 2.0, mouse.y <= tan(pi / 3.0) * mouse.x);

                mouse = newPoint_arc_proj;
            }
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

        // 画origin点 - 用绿色高亮显示翻页起点，如果在对角则用蓝色
        if (drawPoint(uv, origin)) {
            if (isOriginInCorner(origin, aspect)) {
                vs = mix(vs, vec4(0.0, 0.0, 1.0, 1.0), 0.7); // 蓝色表示在对角
            } else {
                vs = mix(vs, vec4(0.0, 1.0, 0.0, 1.0), 0.7); // 绿色表示不在对角
            }
        }

        // 画curlAxisLinePoint点
        if (drawPoint(uv, curlAxisLinePoint)) {
            vs = mix(vs, vec4(1.0, 0.0, 0.0, 1.0), 0.7);
        }

        // 画鼠标线起点到当前点
        if (drawLine(uv, mouseStart, mouse)) {
            vs = mix(vs, vec4(1.0, 0.0, 0.0, 1.0), 0.7);
        }

        // 当origin在对角时，绘制限制圆
        if (isOriginInCorner(origin, aspect)) {
            vec2 cornerFrom = (iMouse.w < iResolution.y / 2.0) ? vec2(aspect, 0.0) : vec2(aspect, 1.0);
            vec2 startPoint = vec2(0.0, cornerFrom.y == 0.0 ? 0.0 : 1.0);
            
            // 绘制限制圆（半径为aspect）
            if (drawTrackCircle(uv, startPoint, aspect, aspect)) {
                vs = mix(vs, vec4(1.0, 1.0, 0.0, 1.0), 0.5); // 黄色圆圈表示限制范围
            }
            
            // 绘制60度基准线
            vec2 vector = normalize(vec2(0.5, 0.5 * tan(pi / 3.0)));
            vec2 lineEnd = startPoint + vector * aspect;
            if (drawLine(uv, startPoint, lineEnd)) {
                vs = mix(vs, vec4(0.0, 1.0, 1.0, 1.0), 0.6); // 青色线表示60度基准线
            }
        }
    }

    // 输出最终颜色
    fragColor = vs;
}