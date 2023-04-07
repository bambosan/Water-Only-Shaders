#if !defined(GBUFFERS_BASIC) && !defined(GBUFFERS_SKYBASIC)
	#ifdef GBUFFERS_ENTITIES
		uniform vec4 entityColor;
	#endif

	uniform sampler2D lightmap;
	uniform sampler2D tex;

    #define ENABLE_FOG
	#if defined(GBUFFERS_WATER) || defined(GBUFFERS_HAND_WATER)
		#define WATER_WAVE_SCALE 0.6 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
		#define WATER_WAVE_SPEED 0.3 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
		#define WATER_WAVE_STRENGTH 0.2 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
		#define WATER_TRANSPARENCY 0.6 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
		#define WATER_BRIGHTNESS 0.5 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

		#define RAYTRACE_STEP 200 //[200 400 600]
		#define WATER_REFLECTANCE 0.05 //[0.05 0.1 0.15 0.2 0.25 0.3]
        #define ENABLE_REFRACTION
        
		///////////////////////////////////////////////////////////////////////////////////////
		///////////////////////////////////////////////////////////////////////////////////////
		///////////////////////////////////////////////////////////////////////////////////////

		uniform mat4 gbufferProjection;
		uniform mat4 gbufferProjectionInverse;

		uniform vec3 cameraPosition;
		uniform float frameTimeCounter;
		uniform float viewWidth;
		uniform float viewHeight;

		uniform sampler2D depthtex1;
		uniform sampler2D gaux1;

		///////////////////////////////////////////////////////////////////////////////////////
		///////////////////////////////////////////////////////////////////////////////////////
		///////////////////////////////////////////////////////////////////////////////////////

		float luminance(vec3 color){
			return dot(color, vec3(0.2125, 0.7154, 0.0721));
		}

		vec3 screenToView(vec3 sPos){
			vec4 vPos = gbufferProjectionInverse * vec4(sPos * 2.0 - 1.0, 1.0);
			return vPos.xyz / vPos.w;
		}
		
		vec3 viewToScreen(vec3 vPos){
			vec4 clipP = gbufferProjection * vec4(vPos, 1.0);
			vec3 NDC = clipP.xyz / clipP.w;
			return NDC * 0.5 + 0.5;
		}

		///////////////////////////////////////////////////////////////////////////////////////
		///////////////////////////////////////////////////////////////////////////////////////
		///////////////////////////////////////////////////////////////////////////////////////

		// https://github.com/robobo1221/robobo1221Shaders/tree/master/shaders/lib/fragment
		float calcWave(vec2 coord, float wavelength, float movement, vec2 wavedir, float waveamp, float wavestepness){
			float k = 6.28318531 / wavelength;
			float x = sqrt(19.6 * k) * movement - (k * dot(wavedir, coord));
			float wave = sin(x) * 0.5 + 0.5;
			return waveamp * pow(wave, wavestepness);
		}

		#define rot2D(r) mat2(cos(r), -sin(r), sin(r), cos(r))
		float trochoidalWave(vec2 coord){
			vec2 wavedir = vec2(1.0, 0.5);
			float wavelength = 10.0;
			float movement = frameTimeCounter * WATER_WAVE_SPEED;
			float waveamp = WATER_WAVE_STRENGTH;
			float wavestepness = 0.6;
			float waves = 0.0;

			for(int i = 0; i < 10; ++i){
				waves += calcWave(coord, wavelength, movement, wavedir, waveamp, wavestepness);
				wavelength *= 0.7;
				waveamp *= 0.62;
				wavestepness *= 1.03;
				wavedir *= rot2D(0.5);
				movement *= 1.1;
			}
			return waves;
		}
        #undef rot2D
        
		in mat3 TBN;
		in vec4 N;    
	#endif

	in vec3 wPos;
	in vec2 uv0;
	in vec2 uv1;
#endif

in vec4 vColor;

#ifndef GBUFFERS_BASIC
	uniform vec3 upPosition;
	uniform vec3 fogColor;
	uniform vec3 skyColor;
	uniform float far;
    uniform int isEyeInWater;
    
	in vec3 vPos;
#endif

/* DRAWBUFFERS:0 */
void main(){
#ifdef GBUFFERS_BASIC
	gl_FragData[0] = vColor;
#else
	float zSky = clamp(dot(normalize(vPos), normalize(upPosition)), 0.0, 1.0);
    vec3 skyFog = mix(fogColor, skyColor, zSky);
#endif

#if !defined(GBUFFERS_BASIC) && !defined(GBUFFERS_SKYBASIC)
		vec4 albedo = texture(tex, uv0) * vColor;

	#ifdef GBUFFERS_ENTITIES
		albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
	#endif

	#if !defined(GBUFFERS_CLOUDS) && !defined(GBUFFERS_SKYTEXTURED) && !defined(GBUFFERS_SPIDEREYES)
		albedo.rgb *= texture(lightmap, uv1).rgb;
	#endif

	#if defined(GBUFFERS_WATER) || defined(GBUFFERS_HAND_WATER)
		vec3 normal = N.xyz;

		if(N.a > 0.4 && N.a < 0.6){
			vec3 tmp = albedo.rgb;
            
			vec2 posXZ = wPos.xz + cameraPosition.xz;
			float h0 = trochoidalWave(posXZ);
			float h1 = trochoidalWave(posXZ + vec2(0.2, 0.0));
			float h2 = trochoidalWave(posXZ + vec2(0.0, 0.2));
			vec3 wNormal = normalize(vec3(h0 - h1, h0 - h2, 1.0)) * 0.5 + 0.5;
			normal = wNormal * 2.0 - 1.0;
			normal = normalize(normal * TBN);

			///////////////////////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////////////////////

            #ifdef ENABLE_REFRACTION
                vec2 sPos = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
                vec3 vPos1 = screenToView(vec3(sPos, texture(depthtex1, sPos).r));
                vec3 raPos = refract(normalize(vPos), normal - N.xyz, 0.5) * distance(vPos, vPos1);
                    raPos = viewToScreen(raPos + vPos);
                albedo = texture(gaux1, raPos.xy);
            #endif
            
			///////////////////////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////////////////////

			float gray = luminance(tmp * tmp);
				tmp += sqrt(gray * gray * 2.0);
			albedo.rgb = mix(albedo.rgb, tmp * WATER_BRIGHTNESS, WATER_TRANSPARENCY);

			///////////////////////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////////////////////

			vec3 rePos = reflect(normalize(vPos), normal);
			vec3 rayO = viewToScreen(vPos);
			vec3 rayD = viewToScreen(vPos + rePos);
				rayD = normalize(rayD - rayO);
				rayO += rayD * max(1.0 / viewWidth, 1.0 / viewHeight);
				rayD /= RAYTRACE_STEP;

			vec3 refl = mix(fogColor, skyColor, clamp(dot(rePos, normalize(upPosition)), 0.0, 1.0));
			for(int i = 0; i < RAYTRACE_STEP
				&& rePos.z < 0.0
				&& rayO.x > 0.0 && rayO.y > 0.0
				&& rayO.x < 1.0 && rayO.y < 1.0;
			i++, rayO += rayD){
				if(rayO.z > texture(depthtex1, rayO.xy).r && abs(rayO.z - texture(depthtex1, rayO.xy).r) <= rayD.z * 16.0){
					refl = texture(gaux1, rayO.xy).rgb;
					break;
				}
			}

			float fresnel = WATER_REFLECTANCE + (1.0 - WATER_REFLECTANCE) * pow((1.0 - clamp(dot(normalize(-vPos), normal), 0.0, 1.0)), 5.0);
			albedo = mix(albedo, vec4(refl, 1.0), fresnel);
		}
	#endif

	#ifdef ENABLE_FOG
		#ifndef GBUFFERS_SKYTEXTURED
            float farDist = far;
            #ifdef GBUFFERS_CLOUDS
                farDist = farDist * 2.0;
            #endif
			float fogDist = clamp(length(wPos) / farDist, 0.0, 1.0);
                fogDist = (isEyeInWater == 1) ? fogDist : pow(fogDist, 3.0);
			albedo.rgb = mix(albedo.rgb, skyFog, fogDist);
		#endif
	#endif
    
	gl_FragData[0] = albedo;
#endif

#ifdef GBUFFERS_SKYBASIC
	gl_FragData[0] = vec4(skyFog, 1.0);
#endif
}