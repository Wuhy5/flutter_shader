/*
"Page Turning" by Emmanuel Keller aka Tambako - December 2015
License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
Contact: tamby@tambako.ch
*/

// 数学常量
const float pi = 3.14159;
const float twopi = 6.28319;

// 页面曲率参数
const float e0 = 0.018;       // 基础曲率系数
const float ppow = 2.0;       // 曲率函数的指数

// 背景颜色混合参数
const float bcolorMix = 0.67; // 背景颜色混合比例
const float maxBcolVal = 0.4; // 背景颜色最大值

// 光照参数
const float diffint = 1.2;    // 漫反射强度
const float ambientt = 0.1;   // 顶部环境光
const float ambientb = 0.4;   // 底部环境光

// 高光参数
const vec2 specpos = vec2(0.85, -0.2); // 高光位置
const float specpow = 5.;     // 高光指数
const float specwidth = 0.4;  // 高光宽度
const float specint = 0.6;    // 高光强度

// 阴影参数
const vec2 shadowoffset = vec2(0.07, -0.04); // 阴影偏移
const float shadowsmoothness = 0.012;         // 阴影平滑度
const float shadowint = 0.25;                 // 阴影强度

// 抗锯齿参数
const float aawidth = 0.7;    // 抗锯齿采样范围
const int aasamples = 3;      // 抗锯齿采样数

// 调试开关
const bool showpoints = false; // 是否显示控制点
const bool colors = false;     // 是否使用纯色代替纹理
const bool anim = true;        // 是否启用自动动画

// 简单随机数生成器
float random(float co) {
    return fract(sin(co*12.989) * 43758.545);
}

// 获取页面背景颜色（随时间变化）
vec4 getPagebackColor() {
    float cn;
    // 根据时间或鼠标状态决定颜色索引
    if (iMouse.x==0. && iMouse.y==0. && anim)
    cn = floor(iTime/3.5);
    else
    cn = 1.0;

    vec4 pagebackColor;
    // 为RGB通道生成不同的随机颜色值
    pagebackColor.r = maxBcolVal*random(cn + 263.714);
    pagebackColor.g = maxBcolVal*random(cn*4. - 151.894);
    pagebackColor.b = maxBcolVal*random(cn*7. + 87.548);
    pagebackColor.a = 1.0;
    return pagebackColor;
}

// 2D向量旋转函数
vec2 rotateVec(vec2 vect, float angle) {
    float xr = vect.x*cos(angle) + vect.y*sin(angle);
    float yr = vect.x*sin(angle) - vect.y*cos(angle);
    return vec2(xr, yr);
}

// 页面曲率函数（定义页面弯曲形状）
float pageFunction(float x, float e) {
    return pow(pow(x, ppow) - e, 1./ppow);
}

// 页面曲率函数的导数（用于光照计算）
float pageFunctionDer(float x, float e) {
    return pow(x, ppow - 1.)/pow(pow(x, ppow) - e, (ppow - 1.)/ppow);
}

// 核心函数：计算页面翻转效果
vec4 turnPage(vec2 fragCoord) {
    // 坐标归一化处理
    vec2 uv = fragCoord.xy / iResolution.yy;
    float ratio = iResolution.x/iResolution.y;

    // 确定翻页控制点（鼠标或自动动画）
    vec2 mpoint;
    bool firstcycle;
    vec4 Mouse2 = iMouse;

    // 自动动画模式
    if (iMouse.x==0. && iMouse.y==0. && anim) {
        firstcycle = mod(iTime/3.5, 2.)<1.; // 判断当前翻页周期
        // 计算自动移动的控制点轨迹
        mpoint = vec2(mod(iTime/3.5, 1.)*iResolution.x*2.0,
        pow(mod(iTime/3.5, 1.), 2.5)*iResolution.y/1.2 +
        8.*smoothstep(0., 0.07, mod(iTime/3.5, 1.)));
    }
    // 鼠标控制模式
    else {
        mpoint = Mouse2.xy;
        firstcycle = true;
    }

    // 计算中间点和距离
    vec2 midmpoint = mpoint*0.5;
    float mdist = distance(fragCoord, mpoint);
    // 计算曲率参数（基于距离）
    float e = e0*pow(mdist/iResolution.y, 2.) +
    0.02*e0*smoothstep(0., 0.12, mdist/iResolution.y);

    // 计算旋转角度（基于控制点位置）
    float angle = -atan(mpoint.x/mpoint.y) + pi*0.5;

    // 坐标系统转换
    vec2 uv2 = uv;
    vec2 uvr = rotateVec(uv2 - midmpoint/iResolution.yy, angle);

    // 应用页面曲率函数
    float pagefunc = pageFunction(uvr.x, e);
    vec2 uvr2 = vec2(pagefunc, uvr.y);
    vec2 uvr3 = rotateVec(uvr2, -angle) - vec2(1., -1.)*midmpoint/iResolution.yy;

    // 计算翻页的背面坐标
    vec2 uvr2b = vec2(-pagefunc, uvr.y);
    vec2 uvr3b = rotateVec(uvr2b, -angle) - vec2(1., -1.)*midmpoint/iResolution.yy;

    vec4 i;
    // 判断像素位置是否在翻页区域
    if (uvr.x>0. && uvr3b.y>0.) {
        // 计算页面边界校正
        vec2 uvcorr = vec2(ratio, 1.);
        vec2 uvrcorr = rotateVec(uvcorr - midmpoint/iResolution.yy, angle);
        float pagefunccorr = pageFunction(uvrcorr.x, e);
        vec2 uvrcorr2 = vec2(-pagefunccorr, uvrcorr.y);
        vec2 uvrcorr3 = rotateVec(uvrcorr2, -angle) - vec2(1., -1.)*midmpoint/iResolution.yy;

        // 计算光照强度因子
        float pagefuncder = pageFunctionDer(uvr.x, e);
        float intfac = 1. - diffint*(1. - 1./pagefuncder);

        // 翻页顶部区域处理
        if(uvr3.x>=0. || uvr3.y<=0.) {
            // 阴影计算
            float mdists = distance(fragCoord, mpoint)*0.7 - 55.;
            float es = e0*pow(mdists/iResolution.y, 2.) +
            0.02*e0*smoothstep(0., 0.08, mdist/iResolution.y);
            vec2 uvrs = rotateVec(uv2 - midmpoint/iResolution.yy - shadowoffset, angle);
            float pagefuncs = pageFunction(uvrs.x + 0.015, es - 0.001);
            vec2 uvr2s = vec2(pagefuncs, uvrs.y);
            vec2 uvr3s = rotateVec(uvr2s, -angle) - vec2(1., -1.)*midmpoint/iResolution.yy;
            float shadow = 1. - (1. - smoothstep(-shadowsmoothness, shadowsmoothness, uvr3s.x))*
            (1. - smoothstep(shadowsmoothness, -shadowsmoothness, uvr3s.y));

            // 最终光照计算
            float difft = intfac*(1. - ambientt) + ambientt;
            difft = difft*(shadow*shadowint + 1. - shadowint)/2. +
            mix(1. - shadowint, difft, shadow)/2.;

            // 根据翻页周期选择纹理
            if (firstcycle)
            i = difft*(colors?vec4(1.,0.3,0.3,1.):texture(iChannel0, mod((uvr3b - uvrcorr3)/vec2(-ratio,1.),1.));
        else
        i = difft*(colors?vec4(1.,0.3,0.3,1.):texture(iChannel1, mod((uvr3b - uvrcorr3)/vec2(-ratio,1.),1.));
        }
        // 翻页底部区域处理
        else {
            // 基础光照
            float diffb = intfac*(1. - ambientb) + ambientb;
            // 高光计算
            float spec = pow(smoothstep(specpos.x - 0.35, specpos.x, intfac)*
                             smoothstep(specpos.x + 0.35, specpos.x, intfac), specpow);
            spec *= specint * pow(1. - pow(clamp(abs(uvr.y - specpos.y), 0., specwidth*2.), 2.)/specwidth, specpow);

            // 根据翻页周期选择纹理
            if (firstcycle)
            i = diffb*(colors?vec4(0.3,1.0,0.3,1.):mix(texture(iChannel0, mod((uvr3 - uvrcorr3)/vec2(-ratio,1.),1.)),
                                                       getPagebackColor(), bcolorMix));
            else
            i = diffb*(colors?vec4(0.3,1.0,0.3,1.):mix(texture(iChannel1, mod((uvr3 - uvrcorr3)/vec2(-ratio,1.),1.)),
                                                       getPagebackColor(), bcolorMix));
            // 添加高光效果
            i = mix(i, vec4(1.0), spec);
        }
    }
    // 非翻页区域（背景）
    else {
        // 创建微妙的背景曲率
        vec2 mpointbg = vec2(0.2, 0.01);
        vec2 midmpointbg = mpointbg*0.5;
        float mdistbg = distance(fragCoord, mpointbg);
        float ebg = e0*pow(mdistbg/iResolution.y, 2.) +
        0.01*e0*smoothstep(0., 0.12, mdistbg/iResolution.y);
        float anglebg = 0.001;
        vec2 uvrbg = rotateVec(uv - midmpointbg/iResolution.yy, anglebg);

        // 计算背景曲率
        float pagefuncbg;
        if (uvrbg.x<0.15)
        pagefuncbg = uvrbg.x;
        else
        pagefuncbg = mix(uvrbg.x, pageFunction(uvrbg.x, ebg),
                         smoothstep(mpoint.x/iResolution.x + 0.1, mpoint.x/iResolution.x, uvrbg.x));

        // 背景坐标变换
        vec2 uvr2bbg = vec2(-pagefuncbg, uvrbg.y);
        vec2 uvr3bbg = rotateVec(uvr2bbg, -anglebg) - vec2(1., -1.)*midmpointbg/iResolution.yy;
        vec2 uvcorrbg = vec2(ratio, 1.);
        vec2 uvrcorrbg = rotateVec(uvcorrbg - midmpointbg/iResolution.yy, anglebg);
        float pagefunccorrbg = pageFunction(uvrcorrbg.x, ebg);
        vec2 uvrcorr2bg = vec2(-pagefunccorrbg, uvrcorrbg.y);
        vec2 uvrcorr3bg = rotateVec(uvrcorr2bg, -anglebg) - vec2(1., -1.)*midmpointbg/iResolution.yy;
        float pagefuncderbg = pageFunctionDer(uvrbg.x, ebg);
        float intfacbg = 1. - diffint*(1. - 1./pagefuncderbg);
        float difftbg = intfacbg*(1. - ambientt) + ambientt;

        // 根据翻页周期选择背景纹理
        if (firstcycle)
        i = colors?difftbg*vec4(0.3,0.3,1.,1.):texture(iChannel1, mod((uvr3bbg - uvrcorr3bg)/vec2(-ratio,1.),1.));
        else
        i = colors?difftbg*vec4(0.3,0.3,1.,1.):texture(iChannel0, mod((uvr3bbg - uvrcorr3bg)/vec2(-ratio,1.),1.));

        // 添加背景阴影
        float bgshadow = 1. + shadowint*smoothstep(-0.08+shadowsmoothness*4., -0.08, uvr3b.y) - shadowint;
        if (uvr3b.y<0.)
        i *= bgshadow;
    }
    return i;
}

// 主渲染函数
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // 抗锯齿处理：多重采样
    vec4 vs = vec4(0.);
    for (int j=0; j<aasamples; j++) {
        float oy = float(j)*aawidth/max(float(aasamples-1), 1.);
        for (int i=0; i<aasamples; i++) {
            float ox = float(i)*aawidth/max(float(aasamples-1), 1.);
            vs += turnPage(fragCoord + vec2(ox, oy));
        }
    }
    vec4 i = vs/vec4(aasamples*aasamples);

    // 调试点显示（开发用）
    vec4 ocol;
    if (showpoints) {
        float ratio = iResolution.x/iResolution.y;
        vec2 mpoint = iMouse.xy;
        vec2 midmpoint = iMouse.xy*0.5;
        float mdist = distance(fragCoord, mpoint);
        float midmdist = distance(fragCoord, midmpoint);

        ocol = mix(i, vec4(1.,0.,0.,1.), smoothstep(6.,4., mdist)); // 红点：控制点
        ocol = mix(ocol, vec4(1.,1.,0.,1.), smoothstep(6.,4., midmdist)); // 黄点：中点
    } else {
        ocol = i;
    }

    fragColor = ocol;
}