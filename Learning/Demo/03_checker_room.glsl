uniform vec2 iResolution;
uniform float iGlobalTime;
uniform float uFade;
uniform sampler2D tex0;
uniform sampler2D tex1;
in vec2 uv;

const float moveSpeed = 2.5;
const int maxSteps = 256;
const float pi = 3.14159;
const float ambient = 0.1;
const float brightness = 3.0;
const float epsilon = 0.0001;
const float maxDepth = 60.0;
const float aoSamples = 5.0;
const vec3 diffuse = vec3(1, 1, 1);
const vec3 lightCol = vec3(1,1,1);
const vec3 lightDir = normalize(vec3(0.5, 0.5, 1.0));
const vec3 lightDir2 = normalize(vec3(-0.5, 0.5, 1.0));

vec3 color = vec3(1.0);

struct Camera
{
	vec3 pos;
	vec3 dir;
} cam;

// give the distance to a plane from a point p and normal n, shifted by y
float distPlane( vec3 p, vec3 n, float y )
{
	// n must be normalized
	return dot(p,n) - y;
}

// give the distance from point p to a sphere surface at origin
float distSphere(vec3 p, float rad)
{
	return length(p) - rad;
}

float distBox(vec3 point, vec3 center, vec3 b )
{
  return length(max(abs(point - center) - b, vec3(0.0)));
}

vec3 pointRepetition(vec3 point, vec3 c)
{
	point.x = mod(point.x, c.x) - 0.5*c.x;
	point.z = mod(point.z, c.z) - 0.5*c.z;
	return point;
}

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

float distanceField(vec3 p)
{
	vec3 point = p;
	float expansion = 4.5;
	vec3 repPoint = pointRepetition(p, vec3(expansion, 0.0, expansion));
	vec3 repPoint2 = pointRepetition(p-vec3(0,0,expansion/2.0), vec3(expansion, 0.0, expansion));
	vec3 repPointSphere = pointRepetition(p-vec3(cos(iGlobalTime*moveSpeed*0.5)*expansion/4.0,0,0), vec3(expansion, 0, expansion));
	vec3 repPointSphere2 = pointRepetition(p-vec3(sin(iGlobalTime*moveSpeed*0.5)*expansion/4.0,0,expansion/2.0), vec3(expansion, 0, expansion));

	vec3 boxDimension1 = vec3(expansion/4.0, (0.5*(cos(iGlobalTime*moveSpeed+repPoint.x)+1.0)), (0.5*(cos(iGlobalTime*moveSpeed+repPoint.y)+1.0)));
	vec3 boxDimension2 = vec3(expansion/4.0, (0.5*(sin(iGlobalTime*moveSpeed+repPoint.x)+1.0)), (0.5*(sin(iGlobalTime*moveSpeed+repPoint.y)+1.0)));
	vec3 spherePos = vec3(repPointSphere.x, repPoint.y-(0.5*(cos(iGlobalTime*moveSpeed+repPoint.x)+1.0))+0.3, repPointSphere.z);
	vec3 spherePos2 = vec3(repPointSphere2.x, repPoint2.y-(0.5*(sin(iGlobalTime*moveSpeed+repPoint2.x)+1.0))+0.3, repPointSphere2.z);

	float plane = distPlane(point, normalize(vec3(0, 1, 0)), -0.5);
	float boxes = distBox(repPoint, vec3(0, -0.5, 0), boxDimension1);
	float boxes2 = distBox(repPoint2, vec3(0, -0.5, 0), boxDimension2);
	float spheres = distSphere(spherePos, 0.2);
	float spheres2 = distSphere(spherePos2, 0.2);

	float ret = min(plane, min(boxes, min(boxes2,min(spheres, spheres2))));

	if(ret==plane) color = vec3(1.0);
	else if(ret==boxes) color = vec3(0.8, 0.5, 0.6);
	else if(ret==boxes2) color = vec3(0.5, 0.4, 0.8);
	else if(ret==spheres) color = vec3(0.5, 0.7, 0.4);
	else if(ret==spheres2) color = vec3(0.8, 0.8, 0.3);

	return ret;
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
	float h = 0.0001;
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

//calculatte the color, the shadow, the lighting for a position
vec3 shading(vec3 pos, vec3 rd, vec3 n)
{
	vec3 lDir = pos.x > 0 ? lightDir : lightDir2;	//little trick to simulate two lights -> choose which light source depending on position
	vec3 light = max(ambient*brightness, dot(n, lDir)) * lightCol;	//lambert light with light Color
	light *= shadow(pos, lDir);	//add shadow

	light += ambientOcclusion(pos, n) * ambient*brightness;
	// light *= texture2D(tex0, pos.xz/5.0);
	return light;
}

void main()
{
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.pos = vec3(0,0,iGlobalTime*moveSpeed*2);
	cam.dir = rotate(normalize(vec3( p.x, p.y, 1 )), vec3(0, 0, 0));

	vec4 res;
	int steps;
	res = raymarch(cam.pos, cam.dir, steps);
	vec3 currentCol = color; //save the color, the global color changes in shading (shadow & AO)

	if(res.a==1.0 || uFade>0.9)
	{
		currentCol *= clamp(shading(res.xyz, cam.dir, getNormal(res.xyz)), 0.0, 1.0);
	}
	else
	{
		currentCol = vec3(1);
	}

	//fog
	vec3 fogColor = vec3(1);
	float fogDist = 200.0;
	currentCol = mix(currentCol, fogColor, clamp((steps/fogDist)+uFade, 0, 1));

	gl_FragColor = vec4(currentCol, 1.0);
}