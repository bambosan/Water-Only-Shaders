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
#define enabfog
#define saturate(x) clamp(x, 0.0, 1.0)

const int noiseTextureResolution = 256;

uniform sampler2D lightmap;
uniform sampler2D texture;

uniform mat4 gbufferModelView;
uniform vec4 entityColor;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform float far;
uniform int isEyeInWater;

float fogify(float x, float w){
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos){
	float upDot = dot(pos, gbufferModelView[1].xyz);
	return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.2));
}

#if defined(GBUFFERS_SKYBASIC) || defined(GBUFFERS_WATER)
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform vec3 cameraPosition;

uniform float viewHeight;
uniform float viewWidth;
uniform float frameTimeCounter;
uniform float near;
in float starData;
#endif

#ifdef GBUFFERS_WATER
uniform sampler2D depthtex1;
uniform sampler2D gaux1;
uniform sampler2D noisetex;

// trochoidal waves
// https://github.com/robobo1221/robobo1221Shaders/tree/master/shaders/lib/fragment
float trochoidalWave(vec2 coord, float wavelength, float movement, vec2 wavedir, float waveamp, float wavestepness){
	float k = 6.28318531 / wavelength;
	float x = sqrt(19.6 * k) * movement - (k * dot(wavedir, coord));
	float wave = sin(x) * 0.5 + 0.5;
	return waveamp * pow(wave, wavestepness);
}

float trochoidalWave(vec2 coord){
	float wavelength = 10.0;
	float movement = frameTimeCounter * wwspeed;
	float waveamp = 0.07;
	float wavestepness = 0.6;
	vec2 wavedir = vec2(1.0, 0.5);
	float waves = 0.0;
	#define rotate2d(r) mat2(cos(r), -sin(r), sin(r), cos(r))

	for(int i = 0; i < 10; ++i){
		waves += trochoidalWave(coord, wavelength, movement, wavedir, waveamp, wavestepness);
		wavelength *= 0.7;
		waveamp *= 0.62;
		wavestepness *= 1.03;
		wavedir *= rotate2d(0.5);
		movement *= 1.1;
	}
	return -waves;
}

vec3 waterNormal(vec3 position, vec3 worldPos){
	vec2 posxz = position.xz * wwscale;
	
	float height0 = trochoidalWave(posxz);
	float height1 = trochoidalWave(posxz + vec2(wnormaloffset, 0.0));
	float height2 = trochoidalWave(posxz + vec2(0.0, wnormaloffset));

	float xDirection = (height0 - height1);
	float yDirection = (height0 - height2);

	vec3 normalMap = normalize(vec3(xDirection, yDirection, 1.0));
	normalMap = normalMap * wnormalstrength + vec3(0.0, 0.0, 1.0 - wnormalstrength);
	return (normalMap * 0.5 + 0.5);
}

vec3 screenToView(vec3 screenPos){
	vec4 clipPos = gbufferProjectionInverse * vec4(screenPos * 2.0 - 1.0, 1.0);
	return (clipPos.xyz / clipPos.w);
}

vec3 viewToScreen(vec3 viewPos){
	vec4 screenPos = gbufferProjection * vec4(viewPos, 1.0);
	screenPos.xyz /= screenPos.w;
	return (screenPos.xyz * 0.5 + 0.5);
}

bool rayTraceHit(vec3 viewPos, vec3 reflectedPos, vec2 screenPos, out vec3 rtPosHit){

	// https://github.com/Eldeston/Super-Duper-Vanilla/pull/9#issuecomment-1193570208
	if(reflectedPos.z > 0 && reflectedPos.z >= -viewPos.z) return false;
	
	vec3 rayOrigin = vec3(screenPos, gl_FragCoord.z);
	vec3 rayDirection = normalize(viewToScreen(viewPos + reflectedPos) - rayOrigin) / raysstep;
	rayOrigin = rayOrigin + (rayDirection * texture2D(noisetex, gl_FragCoord.xy / noiseTextureResolution).r);

	for(int i = 0; i < raysstep; i++){
		rayOrigin += rayDirection;
		if(saturate(rayOrigin.xy) != rayOrigin.xy) break;
		float sampleDepth = texture2D(depthtex1, rayOrigin.xy).r;

		if(rayOrigin.z > sampleDepth && sampleDepth > 0.56){
			for(int j = 0; j < refinestep; j++){
				rayDirection *= 0.5;
				if(rayOrigin.z > texture2D(depthtex1, rayOrigin.xy).r){
					rayOrigin -= rayDirection;
				} else {
					rayOrigin += rayDirection;
				}
			}
			rtPosHit = rayOrigin;
			return true;
		}
	}
	return false;
}

void fakeRefraction(vec3 viewPos, inout vec3 viewPos1, vec3 normalMap, inout vec2 screenPos){
	vec3 flatNormal = normalize(cross(dFdx(viewPos), dFdy(viewPos)));
	vec3 refractedPos = refract(normalize(viewPos), normalMap - flatNormal, 0.5) * distance(viewPos, viewPos1);
	refractedPos = viewToScreen(refractedPos + viewPos);
	refractedPos.z = texture2D(depthtex1, refractedPos.xy).r;

	if(refractedPos.z > gl_FragCoord.z){
		screenPos = refractedPos.xy;
		viewPos1 = screenToView(refractedPos);
	}
}
in vec4 normal;
in mat3 tbnMatrix;
#endif

in vec2 lmcoord;
in vec2 texcoord;
in vec3 viewPos;
in vec3 worldPos;
in vec4 glcolor;

void main() {
	vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
	
#ifdef GBUFFERS_SKYBASIC
	if(starData > 0.5){
		color.rgb = glcolor.rgb;
	} else {
		vec4 pos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
		pos = gbufferProjectionInverse * pos;
		color.rgb = calcSkyColor(normalize(pos.xyz));
	}
#else
	color = texture2D(texture, texcoord) * glcolor;
#endif

#ifdef GBUFFERS_ENTITIES
	color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);
#endif

#ifdef GBUFFERS_BASIC
	color = glcolor;
#endif

#if !defined(GBUFFERS_BEACON_BEAM) && !defined(GBUFFERS_CLOUDS) && !defined(GBUFFERS_SKYTEXTURED) && !defined(GBUFFERS_SPIDEREYES) && !defined(GBUFFERS_SKYBASIC)
	color *= texture2D(lightmap, lmcoord);
#endif

#ifdef GBUFFERS_WATER
	if(normal.a > 0.0){
		vec3 position = worldPos + cameraPosition;
		vec3 normalMap = waterNormal(position, worldPos);
			normalMap = normalMap * 2.0 - 1.0;
			normalMap = normalize(normalMap * tbnMatrix);
		vec3 normalMap2 = mat3(gbufferModelViewInverse) * normalMap;
		vec2 screenPos = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
		vec3 reflectedPos = reflect(normalize(viewPos), normalMap);
		vec3 rtPosHit = vec3(0.0);
		
		bool rayTrace = rayTraceHit(viewPos, reflectedPos, screenPos, rtPosHit);
		vec4 reflection = (rayTrace) ? texture2D(gaux1, rtPosHit.xy) : vec4(calcSkyColor(reflect(normalize(worldPos), normalMap2)), 1.0);

		// schlick
		float fresnel = wreflectance + (1.0 - wreflectance) * pow((1.0 - saturate(dot(normalize(-worldPos), normalMap2))), 5.0);

		vec3 swapColor = color.rgb;
		vec3 viewPos1 = screenToView(vec3(screenPos, texture2D(depthtex1, screenPos).r));

		// fake refraction
		fakeRefraction(viewPos, viewPos1, normalMap, screenPos);
		color = texture2D(gaux1, screenPos);

		#ifdef watertex
		color.rgb = mix(color.rgb, swapColor * wbrightness, wtransparency);
		#else
		color.rgb = mix(color.rgb, glcolor.rgb * wbrightness, wtransparency);
		#endif

		// water absorption
		if(isEyeInWater == 0) color.rgb *= exp(-glcolor.bgr * waterdensity * distance(viewPos1, viewPos));
		
		color = mix(color, reflection, fresnel);
	}
#endif

#ifdef enabfog
#if !defined(GBUFFERS_SKYTEXTURED) && !defined(GBUFFERS_SKYBASIC)
	float fogDist = pow(saturate(length(worldPos) / far), 3.0);
	
	#ifdef GBUFFERS_CLOUDS
	fogDist = fogDist * 0.7;
	#endif
	
	if(isEyeInWater == 1) fogDist = fogify(1.0 - fogDist, 0.5);
	color.rgb = mix(color.rgb, calcSkyColor(normalize(viewPos)), fogDist);
#endif
#endif

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}