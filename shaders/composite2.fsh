#version 130
/* RENDERTARGETS: 0 */

#define WATER_REFLECTANCE 0.05 //[0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.012 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2]

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
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
	float f = dot(fenc,fenc);
	float g = sqrt(1.0 - f / 4.0);
	return vec3(fenc * g, 1.0 - f / 2.0);
}

in vec2 texcoord;

void main(){
	gl_FragData[0].rgb = texture(colortex0, texcoord).rgb;
	vec3 gdata = texture(colortex1, texcoord).rgb;

	vec3 screenPos0 = vec3(texcoord, texture(depthtex0, texcoord).r);
	vec3 screenPos1 = vec3(texcoord, texture(depthtex1, texcoord).r);

	vec3 viewPos0 = screenToView(screenPos0);
	vec3 viewPos1 = screenToView(screenPos1);
	vec3 normalMap = decodeNormal(gdata.rg);

	if(gdata.b > 0.4 && gdata.b < 0.6){
		vec3 refractedPos = refract(normalize(viewPos0), normalMap - normalize(cross(dFdx(viewPos0), dFdy(viewPos0))), 0.5) * distance(viewPos0, viewPos1);
			refractedPos = viewToScreen(refractedPos + viewPos0);
		if(texture(depthtex1, refractedPos.xy).r > texture(depthtex0, refractedPos.xy).r){
			gl_FragData[0].rgb = texture(colortex0, refractedPos.xy).rgb;
		}

		vec3 reflectedPos = reflect(normalize(viewPos0), normalMap);
		vec3 reflection = texture(colortex2, texcoord).rgb;
		float fresnel = WATER_REFLECTANCE + (1.0 - WATER_REFLECTANCE) * pow((1.0 - clamp(dot(normalize(-viewPos0), normalMap), 0.0, 1.0)), 5.0);
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, reflection, fresnel);
	}
}
