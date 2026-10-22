#include <metal_stdlib>
using namespace metal;

// Compiled native field: no bitmap, movie, model shader code or audio analysis.
struct Uniforms {
    float4 resolutionTime;
    float4 composition;
    float4 paletteMotion;
    float4 shape;
    float4 secondary;
    float4 accent;
    float4 touch0;
    float4 touch1;
    float4 touch2;
    float4 touch3;
};
struct VertexOut { float4 position [[position]]; float2 uv; };
vertex VertexOut vibeScapeVertex(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    return {float4(p * 2.0 - 1.0, 0, 1), p};
}
static float smoothUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b-a)/k, 0.0, 1.0);
    return mix(b,a,h) - k*h*(1.0-h);
}
static float screenImpulse(float2 point, float4 touch) {
    if (touch.w < 0.5) return 0;
    float radius = length(point-touch.xy);
    float falloff = exp(-radius*radius/0.025);
    return 0.20*falloff*sin(touch.z*12.0-radius*9.0)*exp(-touch.z*2.6);
}
static float impulse(float3 p, float4 touch, constant Uniforms &u) {
    float eyeZ = 4.1+u.shape.x*0.3;
    float2 projected = p.xy*(2.6/1.05)/max(0.5,eyeZ-p.z);
    return screenImpulse(projected,touch);
}
static float field(float3 p, constant Uniforms &u) {
    float3 original = p;
    float t = u.resolutionTime.z;
    float4 c = u.composition;
    float strength = u.shape.z;
    p += strength * 0.20 * sin(p.yzx * (1.8 + u.shape.w) + float3(t*0.7,t*0.5,t*0.6));
    float shift = (c.x-0.5)*0.55;
    float a = length(p-float3(-0.42+shift,0.88+sin(t*0.35)*0.12,0.0))-0.72;
    float b = length(p-float3(0.06+shift,0.51,0.08+cos(t*0.43)*0.12))-(0.50+c.y*0.10);
    float drip = length((p-float3(0.20+shift,0.10+sin(t*0.46)*0.08,0.04))*float3(1,0.85,1)) - (0.23+c.z*0.10);
    float liquid = smoothUnion(smoothUnion(a,b,0.40),drip,0.36);
    // Cropped foreground pools make this a full canvas, not an isolated knot.
    float lower = length(p-float3(-0.95,-2.05+sin(t*0.20)*0.12,0.25))-1.20;
    float upper = length(p-float3(1.38,1.78,-0.30))-0.96;
    liquid = min(liquid,min(lower,upper));
    float bubble = length(p-float3(0.70+sin(t*0.54+c.w*6)*0.10,1.17,0.40))-0.13;
    float bubble2 = length(p-float3(0.73,-1.06+cos(t*0.48)*0.12,0.55))-(0.19+c.w*0.06);
    float bubble3 = length(p-float3(-0.80+cos(t*0.40)*0.08,-0.10,0.45))-0.09;
    float surface = min(liquid,min(bubble,min(bubble2,bubble3)));
    return surface + impulse(original,u.touch0,u) + impulse(original,u.touch1,u)
                   + impulse(original,u.touch2,u) + impulse(original,u.touch3,u);
}
static float3 backdrop(float2 uv, constant Uniforms &u) {
    float t = u.resolutionTime.z;
    float3 primary = pow(u.paletteMotion.xyz,float3(2.2));
    float3 secondary = pow(u.secondary.xyz,float3(2.2));
    float3 accent = pow(u.accent.xyz,float3(2.2));
    float3 col = mix(secondary,primary,0.25)*0.003;
    float sweep = -0.34 + 0.21*sin(uv.x*2.6+t*0.24) + 0.10*sin(uv.x*5.0-t*0.17);
    sweep += 0.55*(screenImpulse(uv,u.touch0)+screenImpulse(uv,u.touch1)
                 +screenImpulse(uv,u.touch2)+screenImpulse(uv,u.touch3));
    float lane = (uv.y-sweep)*22.0;
    float spacing = abs(fract(lane)-0.5);
    float width = max(22.0/u.resolutionTime.y,0.025);
    float core = exp(-spacing*spacing/(width*width));
    float glow = exp(-spacing*spacing/0.035);
    float envelope = exp(-pow((uv.y-sweep)/0.34,4.0));
    float3 ribbon = mix(primary,secondary,smoothstep(-0.65,0.55,uv.x));
    ribbon = mix(ribbon,accent,0.4+0.35*sin(uv.x*2.8+t*0.20));
    col += ribbon*(core*1.5+glow*0.16)*envelope;
    float2 lower = uv-float2(-0.5,-0.9);
    float2 upper = uv-float2(0.5,0.8);
    col += accent*0.035*exp(-dot(lower,lower)*3.0);
    col += primary*0.035*exp(-dot(upper,upper)*4.0);
    return col;
}
static float3 environment(float3 r, constant Uniforms &u) {
    float3 primary = pow(u.paletteMotion.xyz,float3(2.2));
    float3 secondary = pow(u.secondary.xyz,float3(2.2));
    float3 accent = pow(u.accent.xyz,float3(2.2));
    float sharp = mix(85.0,18.0,u.shape.y);
    float left = max(dot(r,normalize(float3(-0.8,0.25,0.6))),0.0);
    float right = max(dot(r,normalize(float3(0.8,-0.15,0.6))),0.0);
    float top = max(dot(r,normalize(float3(0.1,0.95,0.15))),0.0);
    float3 col = secondary*0.014;
    col += primary*(pow(left,sharp)*8.0+pow(left,6.0)*0.5);
    col += secondary*(pow(right,sharp*0.7)*7.0+pow(right,5.0)*0.3);
    col += accent*(pow(top,sharp*0.5)*6.0+pow(top,8.0)*0.35);
    float strip = exp(-pow(r.x+0.45*r.y-0.12,2.0)*150.0);
    float strip2 = exp(-pow(r.x-0.55*r.y+0.22,2.0)*180.0);
    col += primary*strip*4.0 + secondary*strip2*3.2;
    col += float3(0.7,0.8,1.0)*pow(max(dot(r,normalize(float3(-0.25,0.5,0.8))),0.0),sharp*2.0)*0.25;
    return col;
}
fragment float4 vibeScapeFragment(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 uv = (in.uv*2.0-1.0)*float2(u.resolutionTime.x/u.resolutionTime.y,1.0);
    float3 eye = float3(0,0,4.1+u.shape.x*0.3);
    float3 ray = normalize(float3(uv*1.05,-2.6));
    float d = 0; float distance = 0;
    int steps = u.resolutionTime.w > 0.5 ? 88 : 52;
    for (int i=0;i<steps;++i) {
        d=field(eye+ray*distance,u);
        if (d<0.0025 || distance>8.0) break;
        distance += max(d*0.60,0.001);
    }
    float3 color = backdrop(uv,u);
    if (d<0.006 && distance<8.0) {
        float3 p=eye+ray*distance;
        const float e=0.002;
        float3 n=normalize(float3(field(p+float3(e,0,0),u)-field(p-float3(e,0,0),u),
                                 field(p+float3(0,e,0),u)-field(p-float3(0,e,0),u),
                                 field(p+float3(0,0,e),u)-field(p-float3(0,0,e),u)));
        float fresnel=pow(1.0-max(dot(n,-ray),0.0),3.0);
        float3 reflection=environment(reflect(ray,n),u);
        float3 refracted=backdrop(uv+n.xy*0.13,u);
        color=reflection*0.90+refracted*0.20;
        color+=pow(mix(u.paletteMotion.xyz,u.accent.xyz,smoothstep(-1.0,1.0,n.y)),float3(2.2))*fresnel*0.30;
        color+=u.secondary.xyz*0.008;
    }
    color *= 0.65+0.35*exp(-dot(uv,uv)*0.25);
    color=color/(color+0.65);
    return float4(pow(max(color,float3(0)),float3(1.0/2.2)),1);
}
