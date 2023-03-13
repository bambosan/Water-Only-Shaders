uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

#ifdef GBUFFERS_SKYBASIC
	out float starData;
#else
	#ifndef GBUFFERS_BASIC
		#if defined(GBUFFERS_WATER) || defined(GBUFFERS_HAND_WATER)
			uniform vec3 cameraPosition;
			uniform float frameTimeCounter;
			attribute vec4 at_tangent;
			attribute vec3 mc_Entity;
			out mat3 tbnMatrix;
			out vec4 normal;
			out vec3 worldPos;
		#endif

		out vec2 lmcoord;
		out vec2 texcoord;
	#endif
#endif

out vec4 vcolor;

void main(){
	vec3 worldPos2 = mat3(gbufferModelViewInverse) * (gl_ModelViewMatrix * gl_Vertex).xyz + gbufferModelViewInverse[3].xyz;

    vcolor = gl_Color;

#ifdef GBUFFERS_SKYBASIC
	starData = float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0);
#else
	#ifndef GBUFFERS_BASIC
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

		#if defined(GBUFFERS_WATER) || defined(GBUFFERS_HAND_WATER)
			normal.xyz = normalize(gl_NormalMatrix * gl_Normal);
			normal.a = float(mc_Entity.x == 1) * 0.5;

			vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
			vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
			tbnMatrix = transpose(mat3(tangent, binormal, normal.xyz));

			worldPos = worldPos2;

			if(normal.a > 0.4 && normal.a < 0.6){
				//worldPos2.y += (sin(frameTimeCounter * 3.0 + (worldPos2.x + cameraPosition.x) * 4.0) * 0.05);
			}
		#endif
	#endif
#endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(worldPos2, 1.0);
}