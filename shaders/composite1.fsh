#version 130
/* RENDERTARGETS: 2 */

uniform sampler2D colortex2;
in vec2 texcoord;

// implemented on https://www.shadertoy.com/view/ldKBzG
// feel free to use it
const vec2 offset[25] = vec2[25](
	vec2(-2,-2), vec2(-1,-2), vec2(0,-2), vec2(1,-2), vec2(2,-2),
	vec2(-2,-1), vec2(-1,-1), vec2(0,-1), vec2(1,-1), vec2(2,-1),
	vec2(-2,0), vec2(-1,0), vec2(0,0), vec2(1,0), vec2(2,0),
	vec2(-2,1), vec2(-1,1), vec2(0,1), vec2(1,1), vec2(2,1),
	vec2(-2,2), vec2(-1,2), vec2(0,2), vec2(1,2), vec2(2,2)
);
  
const float kernel[25] = float[25](
	1.0/256.0, 1.0/64.0, 3.0/128.0, 1.0/64.0, 1.0/256.0,
	1.0/64.0, 1.0/16.0, 3.0/32.0, 1.0/16.0, 1.0/64.0,
	3.0/128.0, 3.0/32.0, 9.0/64.0, 3.0/32.0, 3.0/128.0,
	1.0/64.0, 1.0/16.0, 3.0/32.0, 1.0/16.0, 1.0/64.0,
	1.0/256.0, 1.0/64.0, 3.0/128.0, 1.0/64.0, 1.0/256.0
);

void main(){
	gl_FragData[0].rgb = vec3(0.0);
	float sumWeight = 0.0;

	for(int i = 0; i < 25; i++){
		vec3 sampColor = texelFetch(colortex2, ivec2(gl_FragCoord.xy + offset[i]), 0).rgb;
		vec3 diff = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0).rgb - sampColor;
		float weight = min(exp(-max(dot(diff, diff), 0.0) / 1.0), 1.0);
		
		gl_FragData[0].rgb += sampColor * weight * kernel[i];
		sumWeight += weight * kernel[i];
    }
	gl_FragData[0].rgb /= sumWeight;
}
