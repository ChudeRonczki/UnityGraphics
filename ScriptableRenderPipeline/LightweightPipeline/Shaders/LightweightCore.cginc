#ifndef LIGHTWEIGHT_PIPELINE_CORE_INCLUDED
#define LIGHTWEIGHT_PIPELINE_CORE_INCLUDED

#include "UnityCG.cginc"

#if defined(UNITY_COLORSPACE_GAMMA)
    #define LIGHTWEIGHT_GAMMA_TO_LINEAR(gammaColor) gammaColor * gammaColor
    #define LIGHTWEIGHT_LINEAR_TO_GAMMA(linColor) sqrt(color)
#else
    #define LIGHTWEIGHT_GAMMA_TO_LINEAR(color) color
    #define LIGHTWEIGHT_LINEAR_TO_GAMMA(color) color
#endif

half _Pow4(half x)
{
    return x * x * x * x;
}

half _LerpOneTo(half b, half t)
{
    half oneMinusT = 1 - t;
    return oneMinusT + b * t;
}

half3 SafeNormalize(half3 inVec)
{
    half dp3 = max(1.e-4h, dot(inVec, inVec));
    return inVec * rsqrt(dp3);
}

half3 EvaluateSHPerVertex(half3 normalWS)
{
#if defined(EVALUATE_SH_VERTEX)
    return max(half3(0, 0, 0), ShadeSH9(half4(normalWS, 1.0)));
#elif defined(EVALUATE_SH_MIXED)
    // no max since this is only L2 contribution
    return SHEvalLinearL2(half4(normalWS, 1.0));
#endif

    // Fully per-pixel. Nothing to compute.
    return half3(0.0, 0.0, 0.0);
}

half3 EvaluateSHPerPixel(half3 normalWS)
{
    return max(half3(0, 0, 0), ShadeSH9(half4(normalWS, 1.0)));
}

half3 EvaluateSHPerPixel(half3 normalWS, half3 L2Term)
{
#ifdef EVALUATE_SH_MIXED
    return = max(half3(0, 0, 0), L2Term + SHEvalLinearL0L1(half4(normalWS, 1.0)));
#endif

    // Default: Evaluate SH fully per-pixel
    return max(half3(0, 0, 0), ShadeSH9(half4(normalWS, 1.0)));
}

half3 SampleLightmap(float2 lightmapUV, half3 normalWS)
{
    half4 encodedBakedColor = UNITY_SAMPLE_TEX2D(unity_Lightmap, lightmapUV);
    half3 bakedColor = DecodeLightmap(encodedBakedColor);

#if DIRLIGHTMAP_COMBINED
    half4 bakedDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, lightmapUV);
    bakedColor += DecodeDirectionalLightmap(bakedColor, bakedDirection, normalWS);
#endif

    return bakedColor;
}

void OutputTangentToWorld(half4 vertexTangent, half3 vertexNormal, out half3 tangentWS, out half3 binormalWS, out half3 normalWS)
{
    half sign = vertexTangent.w * unity_WorldTransformParams.w;
    normalWS = normalize(UnityObjectToWorldNormal(vertexNormal));
    tangentWS = normalize(mul((half3x3)unity_ObjectToWorld, vertexTangent.xyz));
    binormalWS = cross(normalWS, tangentWS) * sign;
}

half3 TangentToWorldNormal(half3 normalTangent, half3 tangent, half3 binormal, half3 normal)
{
    half3x3 tangentToWorld = half3x3(tangent, binormal, normal);
    return normalize(mul(normalTangent, tangentToWorld));
}

float ComputeFogFactor(float z)
{
    float clipZ_01 = UNITY_Z_0_FAR_FROM_CLIPSPACE(z);

#if defined(FOG_LINEAR)
    // factor = (end-z)/(end-start) = z * (-1/(end-start)) + (end/(end-start))
    float fogFactor = saturate(clipZ_01 * unity_FogParams.z + unity_FogParams.w);
    return half(fogFactor);
#elif defined(FOG_EXP)
    // factor = exp(-density*z)
    float unityFogFactor = unity_FogParams.y * clipZ_01;
    return half(saturate(exp2(-unityFogFactor)));
#elif defined(FOG_EXP2)
    // factor = exp(-(density*z)^2)
    float unityFogFactor = unity_FogParams.x * clipZ_01;
    return half(saturate(exp2(-unityFogFactor*unityFogFactor)));
#else
    return 0.0h;
#endif
}

void ApplyFog(inout half3 color, half fogFactor)
{
#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    color = lerp(unity_FogColor, color, fogFactor);
#endif
}

half4 OutputColor(half3 color, half alpha)
{
    return half4(LIGHTWEIGHT_LINEAR_TO_GAMMA(color), alpha);
}
#endif
