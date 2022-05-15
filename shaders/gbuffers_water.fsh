#version 130

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float far, near;
uniform int isEyeInWater;

uniform sampler2D depthtex1;
uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D gaux1;
uniform sampler2D noisetex;

in vec4 vcolor;
in vec4 normal;
in vec3 worldpos;
in vec3 viewpos;
in mat3 tbn;
in vec2 uv0;
in vec2 uv1;

const int noiseTextureResolution = 256;

#define raysstep 100 //[10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 105 110 115 120 125 130 135 140 145 150]
#define refinestep 5 //[5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]
#define wwscale 0.6 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define wwspeed 0.3 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define wnormalstrength 2.5 //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0]
#define wnormaloffset 0.2 //[0.05 0.06 0.07 0.08 0.09 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define watertex
#define wtransparency 0.3 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 1.0]
#define wbrightness 0.6 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 1.0]
#define waterdensity 0.3 //[0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define wreflectance 0.05 //[0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.012 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2]

// trochoidal waves
// https://github.com/robobo1221/robobo1221Shaders/tree/master/shaders/lib/fragment
float calctrocoidalwave(vec2 coord, float wavelength, float movement, vec2 wavedir, float waveamp, float wavestepness){
	float k = 6.28318531 / wavelength;
	float x = sqrt(19.6 * k) * movement - (k * dot(wavedir, coord));
	float wave = sin(x) * 0.5 + 0.5;
	return waveamp * pow(wave, wavestepness);
}

float calctrocoidalwave(vec2 coord){
	float wavelength = 10.0;
	float movement = frameTimeCounter * wwspeed;
	float waveamp = 0.07;
	float wavestepness = 0.6;
	vec2 wavedir = vec2(1.0, 0.5);
	float waves = 0.0;
	#define rotate2d(r) mat2(cos(r), -sin(r), sin(r), cos(r))

	for(int i = 0; i < 10; ++i){
		waves += calctrocoidalwave(coord, wavelength, movement, wavedir, waveamp, wavestepness);
		wavelength *= 0.7;
		waveamp *= 0.62;
		wavestepness *= 1.03;
		wavedir *= rotate2d(0.5);
		movement *= 1.1;
	}
	return -waves;
}

vec3 getwaternormal(vec3 position, vec3 worldpos){
	vec2 posxz = position.xz * wwscale;
	float h0 = calctrocoidalwave(posxz);
	float h1 = calctrocoidalwave(posxz + vec2(wnormaloffset, 0.0));
	float h2 = calctrocoidalwave(posxz + vec2(0.0, wnormaloffset));
	float xd = (h0 - h1), yd = (h0 - h2);

	vec3 normalmap = normalize(vec3(xd, yd, 1.0));
	normalmap = normalmap * wnormalstrength + vec3(0.0, 0.0, 1.0 - wnormalstrength);
	return normalmap * 0.5 + 0.5;
}

vec3 stoviewpos(vec3 screenpos){
	vec4 viewspace = gbufferProjectionInverse * vec4(screenpos * 2.0 - 1.0, 1.0);
	return viewspace.xyz / viewspace.w;
}

vec3 viewtoscreenp(vec3 viewposp){
	vec4 screenspace = gbufferProjection * vec4(viewposp, 1.0);
	screenspace.xyz /= screenspace.w;
	return screenspace.xyz * 0.5 + 0.5;
}

void calcrefraction(vec3 viewposp, inout vec3 viewpos1, vec3 normalm, inout vec2 screenpos){
	vec3 fnormal = clamp(normalize(cross(dFdx(viewposp), dFdy(viewposp))), -1.0, 1.0);
	vec3 refractedv = refract(normalize(viewposp), normalm - fnormal, 0.5) * distance(viewposp, viewpos1);
	refractedv = viewtoscreenp(refractedv + viewposp);
	refractedv.z = texture2D(depthtex1, refractedv.xy).r;

	if(refractedv.z > gl_FragCoord.z){
		screenpos = refractedv.xy;
		viewpos1 = stoviewpos(refractedv);
	}
}

#define saturate(x) clamp(x, 0.0, 1.0)

bool raytrace(vec3 viewposp, vec3 reflectedv, vec2 screenpos, out vec3 rtposhit){
	float raylength = ((viewposp.z + reflectedv.z * far * 1.73205080757) > -near) ? (-near - viewposp.z) / reflectedv.z : far * 1.73205080757;
	reflectedv *= raylength;

	vec3 rayorigin = vec3(screenpos, gl_FragCoord.z);
	vec3 raydirection = normalize(viewtoscreenp(viewposp + reflectedv) - rayorigin) / raysstep;
	rayorigin = rayorigin + raydirection * texture2D(noisetex, gl_FragCoord.xy / 256.0).r;

	for(int i = 0; i < raysstep; i++){
		rayorigin += raydirection;
		if(saturate(rayorigin.xy) != rayorigin.xy) break;
		float sampledepth = texture2D(depthtex1, rayorigin.xy).r;

		if(rayorigin.z > sampledepth && sampledepth > 0.56){
			for(int j = 0; j < refinestep; j++){
				raydirection *= 0.5;
				if(rayorigin.z > texture2D(depthtex1, rayorigin.xy).r) rayorigin -= raydirection; else rayorigin += raydirection;
			}
			rtposhit = rayorigin;
			return true;
		}
	}
	return false;
}

void main(){
	vec4 albedo = texture2D(texture, uv0) * vcolor;
	albedo.rgb *= texture2D(lightmap, uv1).rgb;

	if(normal.a > 0.0 && normal.a < 0.2){
		vec3 position = worldpos + cameraPosition;

		vec3 normalmap = getwaternormal(position, worldpos);
		normalmap = normalmap * 2.0 - 1.0;
		normalmap = normalize(normalmap * tbn);
		vec3 wnormalmap = mat3(gbufferModelViewInverse) * normalmap;

		float zenithsky = smoothstep(0.1, 1.0, reflect(normalize(worldpos), wnormalmap).y);
		vec3 vanillasky = mix(fogColor, skyColor, zenithsky);
		vec4 reflection = vec4(vanillasky, 1.0);

		vec2 screenpos = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
		vec3 reflectedv = reflect(normalize(viewpos), normalmap);
		vec3 rtposhit = vec3(0.0);
		bool raytracehit = raytrace(viewpos, reflectedv, screenpos, rtposhit);
		if(raytracehit) reflection = texture2D(gaux1, rtposhit.xy);

		float vdotn = saturate(dot(normalize(-worldpos), wnormalmap));
		float fresnel = wreflectance + (1.0 - wreflectance) * pow((1.0 - vdotn), 5.0);

		vec3 viewpos1 = stoviewpos(vec3(screenpos, texture2D(depthtex1, screenpos).r));
		calcrefraction(viewpos, viewpos1, normalmap, screenpos);

		vec3 oalbedo = albedo.rgb;
		albedo = texture2D(gaux1, screenpos);

		#ifdef watertex
		albedo.rgb = mix(albedo.rgb, oalbedo * wbrightness, wtransparency);
		#else
		albedo.rgb = mix(albedo.rgb, vcolor.rgb * wbrightness, wtransparency);
		#endif

		if(isEyeInWater < 1) albedo.rgb *= exp(-vcolor.bgr * waterdensity * distance(viewpos1, viewpos));
		albedo = mix(albedo, reflection, fresnel);
	}

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}
