#version 130
/* RENDERTARGETS: 2 */
/*
const int colortex0Format = RGB8;
const int colortex1Format = RGB16;
const int colortex2Format = RGB8;
*/

const int noiseTextureResolution = 256;

#define RAYTRACE_STEP 200 //[50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float viewWidth;
uniform float viewHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

vec3 screenToView(vec3 screenPos){
	vec4 clipPos = gbufferProjectionInverse * vec4(screenPos * 2.0 - 1.0, 1.0);
	return (clipPos.xyz / clipPos.w);
}

vec3 viewToScreen(vec3 viewPos){
	vec4 screenPos = gbufferProjection * vec4(viewPos, 1.0);
		screenPos.xyz /= screenPos.w;
	return (screenPos.xyz * 0.5 + 0.5);
}

// https://aras-p.info/texts/CompactNormalStorage.html
vec3 decodeNormal(vec2 enc){
	vec2 fenc = enc * 4.0 - 2.0;
	float f = dot(fenc, fenc);
	float g = sqrt(1.0 - f / 4.0);
	return vec3(fenc * g, 1.0 - f / 2.0);
}

bool linearTrace(vec3 viewPos, vec3 reflectedPos, out vec2 hitCoord){
	vec3 rayOrigin = viewToScreen(viewPos);
	vec3 rayDirection = viewToScreen(viewPos + reflectedPos);
		rayDirection = normalize(rayDirection - rayOrigin) / RAYTRACE_STEP;
		rayOrigin += (rayDirection * texture(noisetex, gl_FragCoord.xy / noiseTextureResolution).r);

	float prevDepth = texture(depthtex0, rayOrigin.xy).r;
	for(int i = 0; i < RAYTRACE_STEP
		&& rayOrigin.z > 0.0
		&& rayOrigin.x >= 0.0 && rayOrigin.y >= 0.0
		&& rayOrigin.x <= 1.0 && rayOrigin.y <= 1.0;
	i++){
		float currDepth = texture(depthtex0, rayOrigin.xy).r;
		if(rayOrigin.z > currDepth && prevDepth < currDepth){
			hitCoord = rayOrigin.xy;
			return true;
		}
		rayOrigin += rayDirection;
	}
	return false;
}

in vec2 texcoord;

void main(){
	vec3 screenPos0 = vec3(texcoord, texture(depthtex0, texcoord).r);
	vec3 screenPos1 = vec3(texcoord, texture(depthtex1, texcoord).r);

	vec3 viewPos0 = screenToView(screenPos0);
	vec3 viewPos1 = screenToView(screenPos1);

	vec3 gdata = texture(colortex1, texcoord).rgb;
	vec3 normalMap = decodeNormal(gdata.rg);
	
	vec2 hitCoord = vec2(0.0);
	vec3 reflectedPos = reflect(normalize(viewPos0), normalMap);

	gl_FragData[0].rgb = mix(skyColor, fogColor, exp(-clamp(dot(reflectedPos, gbufferModelView[1].xyz), 0.0, 1.0) * 2.0));
	if(linearTrace(viewPos0, reflectedPos, hitCoord)){
		gl_FragData[0].rgb = texture(colortex0, hitCoord).rgb;
	}
}
