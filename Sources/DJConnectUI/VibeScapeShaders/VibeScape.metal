#include <metal_stdlib>
using namespace metal;

[[ stitchable ]] float2 horizonWave(float2 position, float4 bounds, float phase) {
    float2 uv = (position - bounds.xy) / max(bounds.zw, float2(1.0));
    float ribbonBand = smoothstep(0.20, 0.43, uv.y) * (1.0 - smoothstep(0.58, 0.78, uv.y));
    float wave = sin(uv.x * 12.56637 - phase + uv.y * 4.0);
    return position + float2(0.0, 5.0 * ribbonBand * wave);
}

// Compiled procedural geometry only. No bitmap, video, live audio or runtime code.
struct SceneUniforms {
    float4 composition, paletteMotion, shape, secondary, accent, style;
};
struct Uniforms {
    float4 resolutionTime, weights, phases, neutral;
    SceneUniforms home, radio, club, festival;
    float4 touch0, touch1, touch2, touch3;
};
struct VertexOut { float4 position [[position]]; float2 uv; };
vertex VertexOut vibeScapeVertex(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    return { float4(p * 2 - 1, 0, 1), p };
}
static float3 rotX(float3 p, float a) { float c=cos(a),s=sin(a); return float3(p.x,c*p.y-s*p.z,s*p.y+c*p.z); }
static float3 rotY(float3 p, float a) { float c=cos(a),s=sin(a); return float3(c*p.x+s*p.z,p.y,-s*p.x+c*p.z); }
static float3 rotZ(float3 p, float a) { float c=cos(a),s=sin(a); return float3(c*p.x-s*p.y,s*p.x+c*p.y,p.z); }
static float smoothUnion(float a,float b,float k) {
    float h=clamp(0.5+0.5*(b-a)/k,0.0,1.0);return mix(b,a,h)-k*h*(1-h);
}
static float screenImpulse(float2 point,float4 touch) {
    if(touch.w<0.5)return 0;
    float r=length(point-touch.xy),onset=touch.w>1.0?0.08:0.16;
    return -0.075*touch.w*exp(-r*r/0.045)*smoothstep(0.0,onset,touch.z)*exp(-touch.z*1.8)*(1-smoothstep(2.0,2.6,touch.z));
}
static float combinedImpulse(float2 p,constant Uniforms &g) {
    float v=screenImpulse(p,g.touch0)+screenImpulse(p,g.touch1)+screenImpulse(p,g.touch2)+screenImpulse(p,g.touch3);
    float limit=0.10*max(1.0,max(max(g.touch0.w,g.touch1.w),max(g.touch2.w,g.touch3.w)));
    return limit*tanh(v/limit);
}
static float3 primary(constant SceneUniforms &u) { return pow(u.paletteMotion.xyz,float3(2.2)); }
static float3 secondary(constant SceneUniforms &u) { return pow(u.secondary.xyz,float3(2.2)); }
static float3 accent(constant SceneUniforms &u) { return pow(u.accent.xyz,float3(2.2)); }
static float3 studio(float3 r,constant SceneUniforms &u) {
    float sharp=mix(85.0,18.0,u.shape.y);
    float l=max(dot(r,normalize(float3(-0.8,0.25,0.6))),0.0);
    float rr=max(dot(r,normalize(float3(0.8,-0.15,0.6))),0.0);
    float top=max(dot(r,normalize(float3(0.1,0.95,0.15))),0.0);
    float3 col=secondary(u)*0.014;
    col+=primary(u)*(pow(l,sharp)*8.0+pow(l,6.0)*0.5);
    col+=secondary(u)*(pow(rr,sharp*0.7)*7.0+pow(rr,5.0)*0.3);
    col+=accent(u)*(pow(top,sharp*0.5)*6.0+pow(top,8.0)*0.35);
    col+=primary(u)*exp(-pow(r.x+0.45*r.y-0.12,2.0)*150.0)*4;
    col+=secondary(u)*exp(-pow(r.x-0.55*r.y+0.22,2.0)*180.0)*3.2;
    return col+float3(0.7,0.8,1)*pow(max(dot(r,normalize(float3(-0.25,0.5,0.8))),0.0),sharp*2)*0.25;
}
static float3 homeBackdrop(float2 uv,constant SceneUniforms &u,constant Uniforms &g,float t) {
    float3 col=mix(secondary(u),primary(u),0.25)*0.003;
    float sweep=-0.34+(0.21*sin(uv.x*2.6+t*0.24)+0.10*sin(uv.x*5-t*0.17))*u.style.w+0.55*combinedImpulse(uv,g);
    float lane=(uv.y-sweep)*(20+2*u.style.z),spacing=abs(fract(lane)-0.5),width=max(22/g.resolutionTime.y,0.025);
    float envelope=exp(-pow((uv.y-sweep)/0.34,4.0));
    float3 ribbon=mix(primary(u),secondary(u),smoothstep(-0.65,0.55,uv.x));
    ribbon=mix(ribbon,accent(u),0.4+0.35*sin(uv.x*2.8+t*0.20));
    float waves=smoothstep(0.15,0.55,u.composition.z);
    col+=ribbon*(exp(-spacing*spacing/(width*width))*1.5+exp(-spacing*spacing/0.035)*0.16)*envelope*waves;
    return col+accent(u)*0.035*exp(-dot(uv-float2(-0.5,-0.9),uv-float2(-0.5,-0.9))*3)
        +primary(u)*0.035*exp(-dot(uv-float2(0.5,0.8),uv-float2(0.5,0.8))*4);
}
static float homeField(float3 p,constant SceneUniforms &u,constant Uniforms &g,float t) {
    float3 original=p;float4 c=u.composition;
    p+=u.shape.z*0.20*sin(p.yzx*(1.8+u.shape.w)+float3(t*0.7,t*0.5,t*0.6));
    float shift=(c.x-0.5)*0.65,group=smoothstep(0.15,0.8,c.y)*(0.75+0.25*u.style.x);
    float a=length((p-float3(-0.42+shift,0.88+sin(t*0.35)*0.12*u.style.w,0))*float3(1,mix(0.72,1.0,c.w),1))-0.72;
    float b=length(p-float3(0.06+shift+group*0.45,0.51-group*0.25,0.08+cos(t*0.43)*0.12*u.style.w))-(0.5+c.y*0.10);
    float drip=length((p-float3(0.20+shift,0.10+sin(t*0.46)*0.08,0.04))*float3(1,0.85,1))-(0.23+c.z*0.10);
    float liquid=smoothUnion(smoothUnion(a,b,mix(0.5,0.16,group)),drip,0.36);
    float lower=length(p-float3(-0.95,-2.05+sin(t*0.20)*0.12,0.25))-1.20;
    float upper=length(p-float3(1.38,1.78,-0.30))-0.96;
    liquid=min(liquid,min(lower,upper));
    float bubble=length(p-float3(0.70+sin(t*0.54+c.w*6)*0.10,1.17,0.40))-0.13;
    float bubble2=length(p-float3(0.73,-1.06+cos(t*0.48)*0.12,0.55))-(0.19+c.w*0.06);
    float bubble3=length(p-float3(-0.80+cos(t*0.40)*0.08,-0.10,0.45))-0.09;
    float eye=4.1+u.shape.x*0.3;
    float dent=combinedImpulse(original.xy*(2.6/1.05)/max(0.5,eye-original.z),g);
    return min(liquid,min(bubble,min(bubble2,bubble3)))+dent;
}
static float cylinder(float3 p,float r,float h) {
    float2 d=abs(float2(length(p.xz),p.y))-float2(r,h);
    return min(max(d.x,d.y),0.0)+length(max(d,0.0));
}
static float hoop(float3 p,float r,float tube,float arc) {
    float d=length(float2(length(p.xz)-r,p.y))-tube;
    return max(d,(abs(atan2(p.z,p.x))-arc)*r*0.7);
}
static float radioField(float3 p,constant SceneUniforms &u,constant Uniforms &g,float t) {
    float4 c=u.composition;float ex=u.style.w,evo=u.style.x;
    p=rotZ(p,(c.z-0.5)*1.4);
    p.x*=mix(0.82,1.20,c.y);p.y*=mix(0.78,1.22,c.w);
    float torque=combinedImpulse(float2(-0.2,0.3),g)*1.4;
    p=rotY(p,(c.x-0.5)*0.35+sin(t*0.12)*0.12*u.style.y);
    float3 q=rotZ(rotX(p-float3(-0.95+0.75*c.x,0.85-1.2*c.y,0.12),0.4+0.3*sin(t*0.31)*ex),-0.28+c.y*0.4+torque);
    q.y-=(0.06+0.20*u.shape.z)*(q.x*q.x-0.35*q.z*q.z);
    float d=cylinder(q,0.43+c.z*0.40,0.035)-0.012;
    q=rotZ(rotX(p-float3(0.25+0.70*c.x,-0.75+0.85*c.z,-0.18),0.65+0.22*cos(t*0.27)*ex),0.5-t*0.10);
    q.y-=(0.06+0.20*u.shape.z)*(q.z*q.z+0.25*q.x*q.x);
    d=min(d,cylinder(q,0.44+c.y*0.40,0.026)-0.012);
    q=rotZ(rotX(p-float3(-0.15+0.3*c.z,0.70+0.4*c.x,-0.45),0.45+0.15*sin(t*0.22)*ex),-0.4+t*0.08);
    q.y-=(0.04+0.14*u.shape.z)*q.x*q.x;
    d=min(d,cylinder(q,0.30+c.z*0.28,0.022)-0.008);
    q=rotZ(rotX(p-float3(-0.06,0.10,-0.12),0.65+t*0.09+0.18*sin(t*0.21)*evo),0.35+0.25*sin(t*0.18));
    d=min(d,hoop(q,1.05+c.w*0.36,0.028,2.35+c.y*0.55));
    q=rotX(rotZ(p-float3(0.12,-0.1,0.18),-0.55-t*0.11+0.14*sin(t*0.19)*evo),0.85+0.25*cos(t*0.20));
    d=min(d,hoop(q,1.02,0.028,2.85));
    q=rotZ(p-float3(-0.23,-1.05,-0.20),0.12+0.14*sin(t*0.2)*ex);
    d=min(d,hoop(rotX(q,0.30),0.80,0.022,2.55));
    q=rotZ(rotX(p-float3(0.45,0.24,-0.35),0.55),0.7+sin(t*0.17)*0.4*ex);
    d=min(d,cylinder(q,0.016,1.10));
    d=min(d,length(p-float3(0.95,0.86+0.10*sin(t*0.27),0.40))-0.16);
    return min(d,length(p-float3(-0.44,-0.77,0.28))-0.09);
}
static float box(float3 p,float3 b) { float3 q=abs(p)-b;return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0); }
static float boxEdge(float3 p,float3 b) {
    float3 q=abs(abs(p)-b);return min(max(q.x,q.y),min(max(q.x,q.z),max(q.y,q.z)));
}
static float frameBox(float3 p,float3 b,float width) {
    return max(box(p,b),-box(p,float3(b.xy-width,b.z+0.1)));
}
static float2 clubField(float3 p,constant SceneUniforms &u,float t) {
    float4 c=u.composition;float ex=u.style.w;
    p=rotY(p,0.12*sin(t*0.14)*u.style.y+(c.w-0.5)*0.85);
    float3 qa=rotY(p-float3(-1.0+0.40*c.z+sin(t*0.15)*0.12*ex,-0.52+c.x*0.80,0.15),0.08+c.x*0.16);
    float3 ba=float3(0.23+0.15*c.x,0.65+c.y*0.75,0.36);
    float d=box(qa,ba),edge=boxEdge(qa,ba);
    float3 qb=rotY(p-float3(0.50+c.y*0.65+cos(t*0.17)*0.16*ex,-0.80+c.z*0.6,-0.10-c.x*0.9),-0.2);
    float3 bb=float3(0.34,0.55+c.x*0.4,0.28);
    float candidate=box(qb,bb);if(candidate<d){d=candidate;edge=boxEdge(qb,bb);}
    float3 qc=rotZ(p-float3(-0.50+c.x,0.14,-0.95-c.w),0.06*sin(t*0.18)*ex);
    float3 bc=float3(0.75+c.z*0.50,0.80+c.y*0.55,0.065);
    candidate=frameBox(qc,bc,0.065);if(candidate<d){d=candidate;edge=min(boxEdge(qc,bc),boxEdge(qc,float3(bc.xy-0.065,bc.z)));}
    float3 qd=rotZ(rotY(p-float3(-0.85+c.y*1.7,-0.35+c.w*1.1,-1.7-c.z*1.0),0.15+c.x*0.25),0.05+c.z*0.70+0.08*cos(t*0.16)*u.style.x);
    float3 bd=float3(0.60+c.x*0.3,0.85,0.065);
    candidate=frameBox(qd,bd,0.045);if(candidate<d){d=candidate;edge=min(boxEdge(qd,bd),boxEdge(qd,float3(bd.xy-0.045,bd.z)));}
    float3 qe=rotZ(rotY(p-float3(-0.20,1.33,-0.6),0.25),0.15*sin(t*0.14));
    float3 be=float3(1.25,0.075,0.22);
    candidate=box(qe,be);if(candidate<d){d=candidate;edge=boxEdge(qe,be);}
    float3 qf=rotZ(rotX(p-float3(1.35,0.78,-1.0),0.20),0.3+c.z*0.3+sin(t*0.16)*0.10*ex);
    candidate=frameBox(qf,float3(0.45,0.55,0.05),0.035);
    if(candidate<d){d=candidate;edge=min(boxEdge(qf,float3(0.45,0.55,0.05)),boxEdge(qf,float3(0.415,0.515,0.05)));}
    // A suspended lattice occupies different space as the composition evolves.
    for(int j=0;j<3;++j){
        float3 qg=rotZ(rotY(p-float3(-0.85+0.5*float(j),0.65,-1.5),0.30),0.25+c.x*0.7+0.22*u.shape.z);
        float3 bg=float3(0.022,0.45+c.w*0.35,0.045);
        candidate=box(qg,bg);if(candidate<d){d=candidate;edge=boxEdge(qg,bg);}
    }
    return p.y+1.32<d?float2(p.y+1.32,100):float2(d,edge);
}
static float field(float3 p,constant SceneUniforms &u,constant Uniforms &g,float t,uint family) {
    if(family==0)return homeField(p,u,g,t);
    if(family==1)return radioField(p,u,g,t);
    return clubField(p,u,t).x;
}
static float3 renderSolid(float2 uv,constant SceneUniforms &u,constant Uniforms &g,float t,uint family) {
    float aspect=g.resolutionTime.x/g.resolutionTime.y;
    float fit=family==0?0:max(0.0,0.75/aspect-1.0)*1.6;
    float3 eye=float3(0,0,(family==0?4.1+u.shape.x*0.3:family==1?3.35+u.shape.x*0.55:3.20+u.shape.x*0.60)+fit);
    float3 ray=normalize(float3(uv*1.05,-2.6));
    float distance=0,d=0;int steps=g.resolutionTime.w>0.5?(family==0?88:72):48;
    for(int i=0;i<steps;++i){d=field(eye+ray*distance,u,g,t,family);if(d<0.0025||distance>10)break;distance+=max(d*(family==0?0.6:0.78),0.001);}
    float3 col=family==0?homeBackdrop(uv,u,g,t):mix(secondary(u),primary(u),0.5)*0.003;
    if(family==2){float floorLine=exp(-pow(uv.y+0.72,2.0)*300);col+=mix(primary(u),accent(u),0.5)*floorLine*0.12;}
    if(d<0.006&&distance<10){
        float3 p=eye+ray*distance;const float e=0.002;
        float3 n=normalize(float3(field(p+float3(e,0,0),u,g,t,family)-field(p-float3(e,0,0),u,g,t,family),field(p+float3(0,e,0),u,g,t,family)-field(p-float3(0,e,0),u,g,t,family),field(p+float3(0,0,e),u,g,t,family)-field(p-float3(0,0,e),u,g,t,family)));
        float fresnel=pow(1-max(dot(n,-ray),0.0),3.0);
        if(family==0){col=studio(reflect(ray,n),u)*0.90+homeBackdrop(uv+n.xy*0.13,u,g,t)*0.20;col+=pow(mix(u.paletteMotion.xyz,u.accent.xyz,smoothstep(-1.0,1.0,n.y)),float3(2.2))*fresnel*0.30+u.secondary.xyz*0.008;}
        else if(family==1){
            float diffuse=max(dot(n,normalize(float3(-0.5,0.8,0.6))),0.0);
            float brush=0.94+0.06*sin(p.y*110+p.z*45);
            float3 reflected=reflect(ray,n);
            float softbox=pow(max(dot(reflected,normalize(float3(-0.35,0.85,0.40))),0.0),10.0)*4.0
                        +pow(max(dot(reflected,normalize(float3(0.65,-0.35,0.65))),0.0),16.0)*3.5;
            col=(studio(reflected,u)*0.85+float3(0.95,0.96,1.0)*softbox)*brush;
            col+=mix(float3(0.4),primary(u),0.15)*(0.025+diffuse*0.10);
            // Broad neutral studio bands reveal the curved satin plate faces.
            col+=float3(0.82,0.86,0.90)*exp(-pow(reflected.y-0.20,2.0)*12.0)*0.65;
            col+=mix(primary(u),accent(u),0.5)*pow(fresnel,2.0)*0.12;
            col*=0.82+0.18*smoothstep(0.0,0.6,field(p+n*0.18,u,g,t,family));
        }else{
            float ed=clubField(p,u,t).y;
            float rim=exp(-ed*90.0);
            col=studio(reflect(ray,n),u)*0.035+secondary(u)*0.002;
            col+=mix(primary(u),accent(u),0.5+0.45*sin(p.y*1.3+p.z*0.8))*rim*2.2;
            col+=primary(u)*pow(fresnel,2.0)*0.035;
            if(p.y< -1.30){
                float3 reflected=reflect(ray,n);float span=0;
                for(int k=0;k<32;++k){float sample=clubField(p+n*0.012+reflected*span,u,t).x;if(sample<0.003||span>8)break;span+=max(sample*0.8,0.002);}
                if(span<8){float3 rp=p+n*0.012+reflected*span;float re=clubField(rp,u,t).y;col+=mix(primary(u),accent(u),0.5+0.4*sin(rp.y+rp.z))*exp(-re*65.0)*0.35;}
                col+=mix(primary(u),secondary(u),0.5)*0.004;
            }
        }
    }
    // Shared local contact response: controlled light over rigid materials.
    // It never bends architecture into liquid or persists as a scene patch.
    if(family>0)col+=mix(primary(u),accent(u),0.5)*abs(combinedImpulse(uv,g))*3.5;
    col*=0.68+0.32*exp(-dot(uv,uv)*0.23);
    return pow(max(col/(col+0.65),float3(0)),float3(1.0/2.2));
}
fragment float4 vibeScapeFragment(VertexOut in [[stage_in]],constant Uniforms &g [[buffer(0)]]) {
    float2 uv=(in.uv*2-1)*float2(g.resolutionTime.x/g.resolutionTime.y,1);
    float neutral=max(0.0,1-dot(g.weights,float4(1)));
    float3 col=g.neutral.xyz*0.025*neutral;
    if(g.weights.x>0.0005)col+=renderSolid(uv,g.home,g,g.phases.x,0)*g.weights.x;
    if(g.weights.y>0.0005)col+=renderSolid(uv,g.radio,g,g.phases.y,1)*g.weights.y;
    if(g.weights.z>0.0005)col+=renderSolid(uv,g.club,g,g.phases.z,2)*g.weights.z;
    if(g.weights.w>0.0005)col+=mix(g.festival.paletteMotion.xyz,g.festival.secondary.xyz,0.5)*0.008*g.weights.w;
    return float4(col,1);
}
struct BloomOut {
    float4 position [[position]];
    float size [[point_size]];
    float4 color;
};
vertex BloomOut vibeScapeBloomVertex(uint vertexID [[vertex_id]],constant Uniforms &g [[buffer(0)]]) {
    // Reduced sampling spans the same complete sculpture, rather than dropping
    // its last strands or changing the user's chosen complexity.
    uint id=g.resolutionTime.w>0.5?vertexID:uint(float(vertexID)*(12288.0/7680.0));
    constant SceneUniforms &u=g.festival;
    uint strand=id/256;float index=float(id%256)/256.0;
    float t=g.phases.w,seed=u.composition.x*6.2831853;
    float angle=6.2831853*fract(index+t*0.016*(strand%2==0?1.0:-1.0));
    float f=float(strand),offset=f*0.1308997+seed;
    float bloom=0.5+0.5*sin(3*angle+offset*0.6+t*0.08);
    float radius=0.42+(0.48+0.50*bloom)*u.style.w;
    float3 p=float3(cos(angle)*radius,sin(angle)*radius,0.32*sin(2*angle+offset+t*0.11));
    p.z+=(0.10+0.22*u.shape.z)*sin(3*angle-t*0.09+offset)*u.style.x;
    p=rotZ(rotY(rotX(p,0.25+0.22*sin(offset)),offset*0.35+sin(t*0.13)*0.12*u.style.y),offset*0.6);
    float column=smoothstep(0.25,0.85,u.composition.x);
    float3 spiral=float3(cos(angle*2+offset)*(0.35+0.3*bloom)*u.style.w,
        (index-0.5)*2.6, sin(angle*2+offset)*(0.35+0.3*bloom));
    spiral=rotZ(spiral,(u.composition.z-0.5)*1.5);
    p=mix(p,spiral,column);
    p.y+=0.12*sin(angle+offset+t*0.17)*u.style.w;
    p=rotY(p,t*0.06+0.15*sin(t*0.1)*u.style.y);
    float aspect=g.resolutionTime.x/g.resolutionTime.y;
    float eye=3.65+u.shape.x*0.65+max(0.0,u.style.w-1.0)*1.5+max(0.0,0.75/aspect-1)*1.8;
    float depth=max(1.0,eye-p.z),scale=2.6/depth;
    float contact=abs(combinedImpulse(p.xy*scale,g));
    p.xy+=float2(sin(angle+offset),cos(angle+offset))*contact*0.18;
    float3 color=mix(u.paletteMotion.xyz,u.secondary.xyz,0.5+0.5*sin(angle+offset));
    color=mix(color,u.accent.xyz,0.25+0.20*cos(offset+angle*2));
    // Main strands remain coherent at every bias; extra woven detail fades in.
    float detail=strand<24?1.0:smoothstep(0.52,1.65,u.style.z)*0.72;
    float glint=(id%37==0)?1.0:0.0;
    float ends=smoothstep(0.0,0.04,index)*(1-smoothstep(0.96,1.0,index));
    float alpha=(0.85+glint*0.30+contact*1.2)*detail*(0.65+0.35*scale)*g.weights.w*ends;
    float pixelScale=clamp(g.resolutionTime.y/640.0,0.6,2.0);
    float size=(glint>0.5?11.0:4.0+2.0*u.shape.y)*pixelScale*(0.7+0.3*scale)*(1+contact*1.5);
    return {float4(p.x*scale/aspect,p.y*scale,depth/12,1),size,float4(color,alpha)};
}
fragment float4 vibeScapeBloomFragment(BloomOut in [[stage_in]],float2 pc [[point_coord]]) {
    float2 q=pc*2-1;float falloff=exp(-dot(q,q)*4.5);
    return float4(in.color.rgb*in.color.a*falloff,0);
}
