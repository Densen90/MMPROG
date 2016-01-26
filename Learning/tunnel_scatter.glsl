uniform vec2 iResolution;
uniform float iGlobalTime;

const int maxSteps = 256;
const float epsilon = 0.0001;
const float pi = 3.14159;
const float maxDepth = 60.0;
const float ambient = 0.1;
const float aoSamples = 5.0;
const vec3 lightCol = vec3(1,1,1);
vec3 lightDir = normalize(vec3(1, 1, -1.0));

struct Hit
{
	vec3 col;
} hit;

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

float pointRepetition(float point, float c)
{
	point = mod(point, c) - 0.5*c;
	return point;
}

// twist the object
vec3 opTwist( vec3 p, float amount )
{
    float c = cos(amount*p.y);
    float s = sin(amount*p.y);
    mat2  m = mat2(c,-s,s,c);
    return vec3(m*p.xz,p.y);
}

//give distance to cylinder from a point p with dimensions h
float distCylinder( vec3 p, vec2 h )
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - h;
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float distRoundBox(vec3 p, vec3 b, float r)
{
 	return length(max(abs(p)-b,0.0))-r;
}

// substracts two distances / objects
float opSubstract( float d1, float d2 )
{
    return max(-d1,d2);
}

float distTwistedBox(vec3 p, vec3 pos, vec3 scale, float speed)
{
	vec3 twistP = opTwist(rotate(p-pos, vec3(90,0,0)), iGlobalTime);
	twistP = rotate(twistP, vec3(0,0,iGlobalTime*speed));
	float box = distRoundBox(twistP, scale, 0.04);

	// dist = distCyl2;
	float dist = box;

   	return dist;
}

float distanceField(vec3 p)
{
	float dist = distTwistedBox(p,vec3(0,-0.2,5.0), vec3(0.6, 0.6, 2.0), 100);
	float dist2 = distTwistedBox(p,vec3(0,-0.2,5.0), vec3(0.4, 0.4, 2.1), 100);
	return opSubstract(dist2, dist);
}

// marching along the ray at step sizes, 
// and checking whether or not the surface is within a given threshold
vec4 raymarch(vec3 rayOrigin, vec3 rayDir, out int steps)
{
	float totalDist = 0.0;
	for(int j=0; j<maxSteps; j++)
	{
		steps = j;
		vec3 p = rayOrigin + totalDist*rayDir;
		float dist = distanceField(p);
		if(abs(dist)<epsilon)	//if it is near the surface, return an intersection
		{
			return vec4(p, 1.0);
		}
		totalDist += dist;
		if(totalDist>=maxDepth) break;
	}
	return vec4(0);
}

// Approximates the (normalized) gradient of the distance function at the given point.
// If p is near a surface, the function will approximate the surface normal.
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

//calculate ambient occlusion
float ambientOcclusion(vec3 p, vec3 n)
{
	float res = 0.0;
	float fac = 1.0;
	for(float i=0.0; i<aoSamples; i++)
	{
		float distOut = i*0.3;	//go on normal ray AOSAMPLES times with factor 0.3
		res += fac * (distOut - distanceField(p + n*distOut));	//look for every step, how far the nearest object is
		fac *= 0.5;	//for every step taken on the normal ray, the fac decreases, so the shadow gets brighter
	}
	return 1.0 - clamp(res, 0.0, 1.0);
}

vec3 shading(vec3 pos, vec3 rd, vec3 n)
{
	vec3 light = max(ambient, dot(n, lightDir)) * lightCol;	//lambert light with light Color
	// light *= shadow(pos, lightDir);
	light += ambientOcclusion(pos, n) * ambient;
	return light;
}

void main()
{
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.pos = vec3(0,0,iGlobalTime);
	cam.dir = normalize(vec3( p.x, p.y, 1 ));

	vec4 res;
	int steps;
	res = raymarch(cam.pos, cam.dir, steps);
	vec3 col = vec3(0); //save the color, the global color changes in shading (shadow & AO)

	if(res.a==1.0)
	{
		col = shading(res.xyz, cam.dir, getNormal(res.xyz));
	}
	// else	//background
	// {
	// 	col = vec3(0);
	// }

	//fog
	vec3 fogColor = vec3(0);
	// fogColor = vec3(0.1, 0.6, 0.4);
	float fogDist = 70.0;
	col = mix(col, fogColor, clamp((steps/fogDist), 0, 1));

	gl_FragColor = vec4(col, 1.0);
}