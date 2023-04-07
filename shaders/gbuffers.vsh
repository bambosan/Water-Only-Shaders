#if !defined(GBUFFERS_BASIC) && !defined(GBUFFERS_SKYBASIC)
	uniform mat4 gbufferModelViewInverse;
	attribute vec3 mc_Entity;

	#if defined(GBUFFERS_WATER) || defined(GBUFFERS_HAND_WATER)
		attribute vec4 at_tangent;

		uniform vec3 cameraPosition;
		uniform float frameTimeCounter;

		out mat3 TBN;
		out vec4 N;
	#endif

	out vec3 wPos;
	out vec2 uv0;
	out vec2 uv1;
#endif

out vec4 vColor;

#ifndef GBUFFERS_BASIC
	out vec3 vPos;
#endif

void main(){

#ifndef GBUFFERS_BASIC
	vPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
#endif

    vColor = gl_Color;

#if !defined(GBUFFERS_BASIC) && !defined(GBUFFERS_SKYBASIC)
	uv0 = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	uv1  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	wPos = mat3(gbufferModelViewInverse) * vPos + gbufferModelViewInverse[3].xyz;

	#if defined(GBUFFERS_WATER) || defined(GBUFFERS_HAND_WATER)
		vec3 T = normalize(gl_NormalMatrix * at_tangent.xyz);
		vec3 B = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
		N.xyz = normalize(gl_NormalMatrix * gl_Normal);
		TBN = transpose(mat3(T, B, N.xyz));	
		N.a = 0.0;
        if(mc_Entity.x == 1) N.a = 0.5;
        if(mc_Entity.x == 2) N.a = 0.7;
	#endif
#endif

	gl_Position = ftransform();
}