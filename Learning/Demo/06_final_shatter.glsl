uniform vec2 iResolution;
uniform float iGlobalTime;
uniform float uHeight;
uniform float uFade;
uniform float uSplit;
uniform float uRadius;
uniform float uBeatValue;
uniform float uBoxYPos, uBoxZPos;
uniform float uXRotation;
uniform float uCameraXRot;
uniform float uCameraY, uCameraZ;
uniform sampler2D tex3;
in vec2 uv;

const float moveSpeed = 4.5;
const int maxSteps = 512;
const float pi = 3.14159;
const float ambient = 0.1;
const float brightness = 3.0;
const float epsilon = 0.0001;
const float maxDepth = 60.0;
const float aoSamples = 5.0;
const vec3 diffuse = vec3(1, 1, 1);
const vec3 lightCol = vec3(1,1,1);
const vec3 lightDir = normalize(vec3(0.5, 0.5, -1.0));
const vec3 lightDir2 = normalize(vec3(-0.5, 0.5, -1.0));

vec3 color = vec3(1.0);

int hitRefractionBox = 0;

struct Camera
{
	vec3 pos;
	vec3 dir;
} cam;

float distPlane( vec3 p, vec3 n, float y )
{
	return dot(p,n) - y;
}

float distSphere(vec3 p, float rad)
{
	return length(p) - rad;
}

float distBox(vec3 point, vec3 center, vec3 b )
{
  return length(max(abs(point - center) - b, vec3(0.0)));
}

float distRoundBox(vec3 p, vec3 b, float r)
{
 	return length(max(abs(p)-b,0.0))-r;
}

vec3 pointRepetition(vec3 point, vec3 c)
{
	point.x = mod(point.x, c.x) - 0.5*c.x;
	point.z = mod(point.z, c.z) - 0.5*c.z;
	return point;
}

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

float opUnionRound(float a, float b, float r) {
	vec2 u = max(vec2(r - a,r - b), vec2(0));
	return max(r, min (a, b)) - length(u);
}

float distanceField(vec3 p)
{
	hitRefractionBox = 0;
	float beatValue1 = uBeatValue;
	float beatValue2 = abs(1.7-uBeatValue);

	float expansion = 4.5;
	vec3 repPoint = pointRepetition(p, vec3(expansion, 0.0, expansion));
	vec3 repPoint2 = pointRepetition(p-vec3(0,0,expansion/2.0), vec3(expansion, 0.0, expansion));
	vec3 repPointSphere = pointRepetition(p-vec3(cos(iGlobalTime*moveSpeed*0.5)*expansion/4.0 * beatValue1,0,0), vec3(expansion, 0, expansion));
	vec3 repPointSphere2 = pointRepetition(p-vec3(sin(iGlobalTime*moveSpeed*0.5)*expansion/4.0 * beatValue1,0,expansion/2.0), vec3(expansion, 0, expansion));

	vec3 boxDimension1 = uHeight*vec3(expansion/4.0 * beatValue1, beatValue1, (0.5*(cos(iGlobalTime*moveSpeed+repPoint.y)+1.0+0.1)));
	vec3 boxDimension2 = uHeight*vec3(expansion/4.0 * beatValue1, beatValue2, (0.5*(sin(iGlobalTime*moveSpeed+repPoint.y)+1.0+0.1)));
	
	vec3 spherePos = vec3(repPointSphere.x-(1.6-beatValue1)*0.25, repPoint.y-beatValue1+0.11, repPointSphere.z);
	vec3 spherePos2 = vec3(repPointSphere2.x, repPoint2.y-beatValue2+0.3+1.48*(1-uHeight), repPointSphere2.z);

	float plane = distPlane(p, normalize(vec3(0, 1, 0)), -0.5);

	float boxes = distRoundBox(repPoint-vec3((1.6-beatValue1)*0.25, -0.5, 0), boxDimension1, 0.01);
	float boxes2 = distRoundBox(repPoint2-vec3(0, -0.5, 0), boxDimension2, 0.01);

	float spheres = distSphere(spherePos, uRadius);
	float spheres2 = distSphere(spherePos2, uRadius);

	vec3 refboxpos = rotate(p-vec3(cam.pos.x,uBoxYPos,uBoxZPos), vec3(uXRotation,0,0));

	float refBox = distRoundBox(refboxpos, uSplit* vec3(0.15, 0.15, 0.15), 0.15);

	plane = opUnionRound(plane, boxes, 0.3*uHeight);
	plane = opUnionRound(plane, boxes2, 0.3*uHeight);

	float pitBox = distBox(p-vec3(0,-0.6,301.3), vec3(0), vec3(30,2,50));

	plane = max(plane, pitBox);

	float ret = min(refBox, max(min(plane, min(spheres, spheres2)), pitBox));

	if(ret==plane) color = vec3(1.0);
	else if(ret==boxes) color = vec3(0.5*(sin(beatValue1)+1.0), 0.6, 0.5*(cos(beatValue1)+1.0));
	else if(ret==boxes2) color = vec3(0.5*(sin(beatValue1)+1.0), 0.72, 0.5*(cos(beatValue1)+1.0));
	else if(ret==spheres || ret==pitBox) color = vec3(0.5*(sin(beatValue1*2.0)+1.0), 0.6, 0.5*(cos(beatValue1*2.0)+1.0));
	else if(ret==spheres2 || ret==pitBox) color = vec3(0.5*(sin(beatValue1*2.0)+1.0), 0.72, 0.5*(cos(beatValue1*2.0)+1.0));
	else if(ret==refBox)
	{
		hitRefractionBox = 1;
		color = vec3(0);
	}

	return ret;
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
	
	light.r = smoothstep(0.0, 0.5, light.r);
	light.g = smoothstep(0.0, 0.5, light.g - 0.1);
	light.b = smoothstep(-0.3, 1.5, light.b);


	if(pos.x < 1.0) light *= shadow(pos, lightDir2);
	if(pos.x > -1.0) light *= shadow(pos, lightDir);
	light += ambientOcclusion(pos, n) * ambient*brightness;
	return light;
}

vec3 bg(float aspect, vec2 uv, float size, float angle) {
    float powF = -10.0;
    vec2 xy;
    xy[0] = uv[0] - 0.5;
    xy[1] = uv[1] - 0.5;
    xy[1] /= aspect;
    xy[0] -= 0.5*sin(angle);
    xy[1] += 0.5*cos(angle);
    xy *= 20.0 * size;
    
    
    float pow1 = pow(abs(xy[0] * sin(angle) + xy[1] * cos(angle)),powF);
    float pow2 = pow(abs(xy[1] * sin(angle) - xy[0] * cos(angle)),powF);

    float outColor = clamp(
        pow1+pow2
        , 0.0, 1.0);

    return vec3(outColor);
}

//thanks to "0x17de" Shader "ColorfulCubes" from ShaderToy
vec3 background(vec3 bgColor)
{
	vec3 outColor = bgColor * sin(uv.x) * cos(uv.y);
	float speed = iGlobalTime / 4.0;
	float aspect = iResolution.x / iResolution.y;

	outColor /= 1.0-bg(aspect, uv, 8.0,  speed + pi);
	outColor /= 1.0-bg(aspect, uv, 4.0,  speed - pi/2.0);
	outColor /= 1.0-bg(aspect, uv, 2.0,  speed);
	outColor /= 1.0-bg(aspect, uv, 1.3,  speed + pi/2.0);

	outColor = clamp(outColor, vec3(0), vec3(0.9,0.8,0.8));

	return outColor;
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
	float fov = 90.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.pos = vec3(0,uCameraY,uCameraZ);
	cam.dir = rotate(normalize(vec3( p.x, p.y, 1 )), vec3(uCameraXRot, 0, 0));

	vec4 res;
	int steps;
	res = raymarch(cam.pos, cam.dir, steps);
	vec3 currentCol = color;

	if(res.a==1.0)
	{
		if(hitRefractionBox==0)
		{		
			currentCol *= clamp(shading(res.xyz, cam.dir, getNormal(res.xyz)), 0.0, 1.0);
		}
		else
		{

			float st;
			
			vec3 n = getNormal(res.xyz);

			vec3 reflection = normalize(reflect(lightDir, n));
			vec3 viewDirection = normalize(res.xyz);
			float spec = max(ambient, dot(reflection, viewDirection));
			currentCol += pow(spec, 30);

			reflection = normalize(reflect(lightDir2, n));
			spec = max(ambient, dot(reflection, viewDirection));
			currentCol += pow(spec, 30);

			vec3 refractDir = normalize(refract(cam.dir, n, 1.0/1.3));
			res = raymarch(res.xyz - 0.01*n, refractDir, st);
			n = -getNormal(res.xyz);
			refractDir = normalize(refract(refractDir, n, 1.3/1.0));
			res = raymarch(res.xyz - 0.01*n, refractDir, st);
			currentCol += res.a==1.0 ? shading(res.xyz, refractDir, n) : background(vec3(0.7, 0.7, 0.6));
		}
	}
	else
	{
		currentCol = background(vec3(0.8, 0.7, 0.5));
	}

	vec3 fogColor = vec3(1.0);
	float fogDist = 200.0;
	currentCol *= pow(texture2D(tex3, uv).r, 2);
	currentCol = mix(currentCol, fogColor, clamp((steps/fogDist), 0, 1));
	currentCol = mix(vec3(0), currentCol, clamp(uFade,0,1));
	currentCol = ScreenSettings(currentCol, 0.9, 1.2, 1.2);
	

	

	gl_FragColor = vec4(currentCol, 1.0);
}