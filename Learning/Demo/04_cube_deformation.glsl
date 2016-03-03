uniform vec2 iResolution;
uniform float iGlobalTime;
uniform float uMengerParam;
uniform float uFade;
uniform float uSplit;

uniform float uXRotation, uZRotation;
uniform float uCameraX, uCameraY, uCameraZ;
uniform float uCameraXRot, uCameraYRot, uCameraZRot;

uniform float uR, uG, uB;

uniform float uBoxXPos, uBoxYPos, uBoxZPos;
uniform sampler2D tex3;
in vec2 uv;

const int maxSteps = 256;
const float pi = 3.14159;
const float ambient = 0.1;
const float brightness = 5.0;
const float epsilon = 0.0001;
const float maxDepth = 60.0;
const float aoSamples = 5.0;
const int menger_iterations = 5;
const vec3 lightCol = vec3(0.8,0.3,0.8);
vec3 lightDir = normalize(vec3(0.5, 0.5, 1.0));

vec3 color = vec3(1.0);

struct Camera
{
	vec3 pos;
	vec3 dir;
} cam;

// Rotation / Translation of a point p with rotation r
vec3 rotate( vec3 p, vec3 r )
{
	r.x *= pi/180.0;
	r.y *= pi/180.0;
	r.z *= pi/180.0;

	mat3 xRot = mat3 (	1,	0,				0,
						0,	cos(r.x),	-sin(r.x),
						0,	sin(r.x),	cos(r.x) );
	mat3 yRot = mat3 ( 	cos(r.y),		0,	sin(r.y),
						0,					1,	0,
						-sin(r.y),		0,	cos(r.y) );
	mat3 zRot = mat3 (	cos(r.z),	-sin(r.z),	0,
						sin(r.z),	cos(r.z),	0,
						0,				0,				1 );
	return xRot * yRot * zRot * p;
}

float distRoundBox(vec3 p, vec3 b, float r)
{
 	return length(max(abs(p)-b,0.0))-r;
}

float Cross(vec3 p)
{
   p = abs(p);
   vec3 d = vec3(max(p.x, p.y),
                 max(p.y, p.z),
                 max(p.z, p.x));
   return min(d.x, min(d.y, d.z)) - (1.0 / 3.0);
}

float CrossRep(vec3 p)
{
   vec3 q = mod(p + 1.0, 2.0) - 1.0;
   return Cross(q);
}

float CrossRepScale(vec3 p, float s)
{
   return CrossRep(p * s) / s;   
}

float distanceField(vec3 p)
{
	float scale = 0.1;
   	float dist = 0.0;
   	for (int i = 0; i < menger_iterations; i++)
   	{
      dist = max(dist, -CrossRepScale(p, scale));
      scale *= 3;
   	}

   	vec3 boxPos = vec3(uBoxXPos, uBoxYPos, uBoxZPos);

   	//mostly have one cube we chase, but at a certain time, it splits into 4 cubes
   	if(uSplit<1.0)
   	{
   		vec3 rotP = rotate(p- boxPos, vec3(uXRotation, 0, uZRotation));
   		float dBox = distRoundBox(rotP, vec3(0.5), 0.25);
	   	dist = min(dist, dBox);
   	}
   	else
   	{
   		float timeZero = iGlobalTime-83.50;
   		float dBox1 = distRoundBox(p - boxPos - vec3(timeZero*10,0,0), vec3(0.5), 0.25);
   		float dBox2 = distRoundBox(p - boxPos + vec3(timeZero*10,0,0), vec3(0.5), 0.25);
   		float dBox3 = distRoundBox(p - boxPos - vec3(0,0,timeZero*10), vec3(0.5), 0.25);
   		float dBox4 = distRoundBox(p - boxPos + vec3(0,0,timeZero*10), vec3(0.5), 0.25);
		dist = min(dist, min(dBox1, min(dBox2, min(dBox3, dBox4))));
	}
   	
   	return dist;
}

vec4 raymarch(vec3 rayOrigin, vec3 rayDir, out int steps)
{
	float totalDist = 0.0;
	for(int j=0; j<maxSteps; j++)
	{
		steps = j;
		vec3 p = rayOrigin + totalDist*rayDir;
		float dist = distanceField(p);
		if(abs(dist)<epsilon)
		{
			return vec4(p, 1.0);
		}
		totalDist += dist;
		if(totalDist>=maxDepth) break;
	}
	return vec4(0);
}

vec3 getNormal(vec3 p)
{
	float h = epsilon;
	return normalize(vec3(
		distanceField(p + vec3(h, 0, 0)) - distanceField(p - vec3(h, 0, 0)),
		distanceField(p + vec3(0, h, 0)) - distanceField(p - vec3(0, h, 0)),
		distanceField(p + vec3(0, 0, h)) - distanceField(p - vec3(0, 0, h))));
}

float shadow(vec3 ro, vec3 rd)
{
	float softshadowFac = 32.0;
	float res = 1.0;
    for( float t=0.01; t<32.0; )
    {
        float h = distanceField(ro + rd*t);
        if( h<epsilon )
            return ambient;
        res = min( res, softshadowFac*h/t );
        t += h;
    }
    return res;
}

float ambientOcclusion(vec3 p, vec3 n)
{
	float res = 0.0;
	float fac = 1.0;
	for(float i=0.0; i<aoSamples; i++)
	{
		float distOut = i*0.3;
		res += fac * (distOut - distanceField(p + n*distOut));
		fac *= 0.5;
	}
	return 1.0 - clamp(res, 0.0, 1.0);
}

vec3 shading(vec3 pos, vec3 rd, vec3 n)
{
	vec3 light = max(ambient*brightness, dot(n, lightDir)) * lightCol;
	light *= shadow(pos, lightDir);
	light += ambientOcclusion(pos, n) * ambient*brightness;
	return light;
}

vec3 ScreenSettings(vec3 inCol, float bright, float saturation, float contrast)
{
	vec3 lumCoeff = vec3( 0.2126, 0.7152, 0.0722 );
	vec3 brightColor = inCol.rgb * bright;
	float intensFactor = dot( brightColor, lumCoeff );
	vec3 intensFactor3 = vec3( intensFactor );
	vec3 saturationColor = mix( intensFactor3, brightColor, saturation );
	vec3 contrastColor = mix( vec3(0.5), saturationColor, contrast );

	return contrastColor;
}

void main()
{
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.pos = vec3(uCameraX,uCameraY,uCameraZ);
	cam.dir = rotate( rotate( rotate( 
				normalize(vec3( p.x, p.y, 1 )),
				vec3(uCameraXRot,0,0)),
				vec3(0,uCameraYRot,0)),
				vec3(0,0,uCameraZRot));

	vec4 res;
	int steps;
	res = raymarch(cam.pos, cam.dir, steps);
	vec3 currentCol = color;

	if(res.a==1.0)
	{
		currentCol = shading(res.xyz, cam.dir, getNormal(res.xyz));
	}
	else
	{
		currentCol = vec3(uR, uG, uB);
	}

	vec3 fogColor = vec3(uR, uG, uB);
	float fogDist = 70.0;
	currentCol = mix(currentCol, fogColor, clamp((steps/fogDist), 0, 1));
	currentCol = ScreenSettings(currentCol, 0.9, 1.2, 1.4);
	currentCol *= pow(texture2D(tex3, uv).r, 1.8);
	currentCol = mix(vec3(uFade), currentCol, 1.0-uFade);
	
	gl_FragColor = vec4(currentCol, 1.0);
}