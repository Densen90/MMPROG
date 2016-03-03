uniform vec2 iResolution;
uniform float iGlobalTime;
uniform float uMengerParam;
uniform float uFade;

uniform float uCameraZ;
uniform float uCameraXRot, uCameraYRot, uCameraZRot;
uniform float uR, uG, uB;

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

vec3 pointXZRepetition(vec3 point, vec3 c)
{
	point.x = mod(point.x, c.x) - 0.5*c.x;
	point.z = mod(point.z, c.z) - 0.5*c.z;
	return point;
}

vec3 pointYZRepetition(vec3 point, vec3 c)
{
	point.y = mod(point.y, c.y) - 0.5*c.y;
	point.z = mod(point.z, c.z) - 0.5*c.z;
	return point;
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

   	//only have the many little cubes at a certain time
   	if(uFade<1.09) return dist;

   	float boxesHorizUp1 = distRoundBox(pointXZRepetition(p-vec3(iGlobalTime*5,2.2,-5.5), vec3(2.1, 0, 20)), vec3(0.2), 0.01);
   	float boxesHorizUp2 = distRoundBox(pointXZRepetition(p-vec3(-iGlobalTime*3,2.2,-1.3), vec3(1.3, 0, 20)), vec3(0.2), 0.01);
   	float boxesHorizUp3 = distRoundBox(pointXZRepetition(p-vec3(iGlobalTime*7,2.2,3.3), vec3(1.7, 0, 20)), vec3(0.2), 0.01);
   	
   	dist = min(dist, min(boxesHorizUp1, min(boxesHorizUp2, boxesHorizUp3)));
   	
   	float boxesHorizDown1 = distRoundBox(pointXZRepetition(p-vec3(-iGlobalTime*2,-2.2,-3.5), vec3(1.5, 0, 20)), vec3(0.2), 0.01);
   	float boxesHorizDown2 = distRoundBox(pointXZRepetition(p-vec3(iGlobalTime*8,-2.2,1.3), vec3(2.4, 0, 20)), vec3(0.2), 0.01);
   	float boxesHorizDown3 = distRoundBox(pointXZRepetition(p-vec3(-iGlobalTime*5,-2.2,5.3), vec3(1.3, 0, 20)), vec3(0.2), 0.01);
   	
   	dist = min(dist, min(boxesHorizDown1, min(boxesHorizDown2, boxesHorizDown3)));
   	
   	float boxesVertLeft1 = distRoundBox(pointYZRepetition(p-vec3(-2.2,iGlobalTime*6,-3.5), vec3(0, 2.0, 20)), vec3(0.2), 0.01);
   	float boxesVertLeft2 = distRoundBox(pointYZRepetition(p-vec3(-2.2,-iGlobalTime*2,1.3), vec3(0, 1.5, 20)), vec3(0.2), 0.01);
   	float boxesVertLeft3 = distRoundBox(pointYZRepetition(p-vec3(-2.2,iGlobalTime*4,5.3), vec3(0, 1.7, 20)), vec3(0.2), 0.01);
   	
   	dist = min(dist, min(boxesVertLeft1, min(boxesVertLeft2, boxesVertLeft3)));
   	
   	float boxesVertRight1 = distRoundBox(pointYZRepetition(p-vec3(2.2,-iGlobalTime*3,-5.5), vec3(0, 1.8, 20)), vec3(0.2), 0.01);
   	float boxesVertRight2 = distRoundBox(pointYZRepetition(p-vec3(2.2,iGlobalTime*8,-1.3), vec3(0, 1.2, 20)), vec3(0.2), 0.01);
   	float boxesVertRight3 = distRoundBox(pointYZRepetition(p-vec3(2.2,-iGlobalTime*5,3.3), vec3(0, 2.2, 20)), vec3(0.2), 0.01);
   	
   	dist = min(dist, min(boxesVertRight1, min(boxesVertRight2, boxesVertRight3)));

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

	cam.pos = vec3(0,0,uCameraZ);
	cam.dir = rotate( normalize(vec3( p.x, p.y, 1 )), vec3(uCameraXRot, uCameraYRot, uCameraZRot));

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
	currentCol = ScreenSettings(currentCol, 0.9, 1.2, 1.2);
	currentCol *= pow(texture2D(tex3, uv).r, 1.8);

	gl_FragColor = vec4(currentCol, 1.0);
}