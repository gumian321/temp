Shader "Cartoon FX/Remaster/Particle Ubershader" {
	Properties {
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Blend Source", Float) = 5
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Blend Destination", Float) = 10
		[KeywordEnumNoPrefix(Alpha Blending, _ALPHABLEND_ON, Alpha Blending Premultiplied, _ALPHAPREMULTIPLY_ON, Multiplicative, _ALPHAMODULATE_ON, Additive, _CFXR_ADDITIVE)] _BlendingType ("Blending Type", Float) = 0
		[ToggleNoKeyword] _ZWrite ("Depth Write", Float) = 0
		[Toggle(_ALPHATEST_ON)] _UseAlphaClip ("Alpha Clipping (Cutout)", Float) = 0
		_Cutoff ("Cutoff Threshold", Range(0.001, 1)) = 0.1
		[Toggle(_FADING_ON)] _UseSP ("Soft Particles", Float) = 0
		_SoftParticlesFadeDistanceNear ("Near Fade", Float) = 0
		_SoftParticlesFadeDistanceFar ("Far Fade", Float) = 1
		[Toggle(_CFXR_EDGE_FADING)] _UseEF ("Edge Fade", Float) = 0
		_EdgeFadePow ("Edge Fade Power", Float) = 1
		[Toggle(_CFXR_DISSOLVE)] _UseDissolve ("Enable Dissolve", Float) = 0
		[NoScaleOffset] _DissolveTex ("Dissolve Texture", 2D) = "gray" {}
		_DissolveSmooth ("Dissolve Smoothing", Range(0.0001, 0.5)) = 0.1
		[ToggleNoKeyword] _InvertDissolveTex ("Invert Dissolve Texture", Float) = 0
		[Toggle(_CFXR_UV_DISTORTION)] _UseUVDistortion ("Enable UV Distortion", Float) = 0
		[NoScaleOffset] _DistortTex ("Distortion Texture", 2D) = "gray" {}
		_DistortScrolling ("Scroll (XY) Tile (ZW)", Vector) = (0,0,1,1)
		[Toggle(_CFXR_UV2_DISTORTION)] _UseUV2Distortion ("Use UV2", Float) = 0
		_Distort ("Distortion Strength", Range(0, 2)) = 0.1
		[ToggleNoKeyword] _FadeAlongU ("Fade along Y", Float) = 0
		[Toggle(_CFXR_UV_DISTORTION_ADD)] _UVDistortionAdd ("Add to base UV", Float) = 0
		[NoScaleOffset] _MainTex ("Texture", 2D) = "white" {}
		[Toggle(_CFXR_SINGLE_CHANNEL)] _SingleChannel ("Single Channel Texture", Float) = 0
		[KeywordEnum(Off,1x,2x)] _CFXR_OVERLAYTEX ("Enable Overlay Texture", Float) = 0
		[KeywordEnum(RGBA,RGB,A)] _CFXR_OVERLAYBLEND ("Overlay Blend Channels", Float) = 0
		[NoScaleOffset] _OverlayTex ("Overlay Texture", 2D) = "white" {}
		_OverlayTex_Scroll ("Overlay Scrolling / Scale", Vector) = (0.1,0.1,1,1)
		[Toggle(_FLIPBOOK_BLENDING)] _UseFB ("Flipbook Blending", Float) = 0
		[Toggle(_CFXR_SECONDCOLOR_LERP)] _UseSecondColor ("Secondary Vertex Color (TEXCOORD2)", Float) = 0
		[NoScaleOffset] _SecondColorTex ("Second Color Map", 2D) = "black" {}
		_SecondColorSmooth ("Second Color Smoothing", Range(0.0001, 0.5)) = 0.2
		[Toggle(_CFXR_FONT_COLORS)] _UseFontColor ("Use Font Colors", Float) = 0
		[Toggle(_CFXR_HDR_BOOST)] _HdrBoost ("Enable HDR Multiplier", Float) = 0
		_HdrMultiply ("HDR Multiplier", Float) = 2
		[KeywordEnumNoPrefix(Off, _, Direct, _CFXR_LIGHTING_DIRECT, Indirect, _CFXR_LIGHTING_INDIRECT, Both, _CFXR_LIGHTING_ALL)] _UseLighting ("Mode", Float) = 0
		_DirectLightingRamp ("Direct Lighting Ramp", Range(0, 1)) = 1
		[Toggle(_NORMALMAP)] _UseNormalMap ("Enable Normal Map", Float) = 0
		[NoScaleOffset] _BumpMap ("Normal Map", 2D) = "bump" {}
		_BumpScale ("Normal Scale", Range(-1, 1)) = 1
		[Toggle(_EMISSION)] _UseEmission ("Enable Emission (TEXCOORD2)", Float) = 0
		[Toggle(_CFXR_LIGHTING_WPOS_OFFSET)] _UseLightingWorldPosOffset ("Enable World Pos. Offset", Float) = 0
		_LightingWorldPosStrength ("Offset Strength", Range(0, 1)) = 0.2
		[Toggle(_CFXR_LIGHTING_BACK)] _UseBackLighting ("Enable Backlighting", Float) = 0
		_DirLightScreenAtten ("Dir. Light Screen Attenuation", Range(0, 5)) = 1
		_BacklightTransmittance ("Backlight Transmittance", Range(0, 2)) = 1
		_IndirectLightingMix ("Indirect Lighting Mix", Range(0, 1)) = 0.5
		_ShadowColor ("Shadow Color", Vector) = (0,0,0,1)
		[KeywordEnum(Off,On,CustomTexture)] _CFXR_DITHERED_SHADOWS ("Dithered Shadows", Float) = 0
		_ShadowStrength ("Shadows Strength Max", Range(0, 1)) = 1
		_DitherCustom ("Dithering 3D Texture", 3D) = "black" {}
	}
	
// Recovery approximation: basic particle texture/color/blending. Original effect source was unavailable.
SubShader {
 Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
 Cull Off ZWrite Off Blend [_SrcBlend] [_DstBlend]
 Pass {
  CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  sampler2D _MainTex; float4 _MainTex_ST; half _HdrMultiply; half _HdrBoost;
  struct appdata { float4 vertex:POSITION; float2 uv:TEXCOORD0; half4 color:COLOR; };
  struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; half4 color:COLOR; };
  v2f vert(appdata v) { v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.uv=v.uv; o.color=v.color; return o; }
  half4 frag(v2f i):SV_Target { half4 color=tex2D(_MainTex,i.uv)*i.color; color.rgb *= lerp(1.0,_HdrMultiply,_HdrBoost); return color; }
  ENDCG
 }
}
}
