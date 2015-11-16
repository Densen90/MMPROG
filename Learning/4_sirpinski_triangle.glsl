uniform vec2 iResolution;
uniform float iGlobalTime;
uniform sampler2D tex;
in vec2 uv;

#define PI 3.14159
#define MAXSTEPS 256
#define EPSILON 0.001
#define AMBIENT 0.2
#define MAXDEPTH 100.0
#define SHADOWDEPTH 32.0
#define SOFTSHADOWFAC 32.0
#define FRACTALITERATIONS 32
#define AOSAMPLES 5.0

const vec3 lightDir = normalize(vec3(-1,0.8,-1));
const vec3 lightCol = vec3(0.7, 0.5, 0.8);
const vec3 diffuse = vec3(1, 1, 1);

struct Camera
{
	vec3 pos;
	vec3 dir;
} cam;

// Rotation / Translation of a point p with rotation r
vec3 rotate( vec3 p, vec3 r )
{
	r.x *= PI/180.0;
	r.y *= PI/180.0;
	r.z *= PI/180.0;

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

// give the distance to a plane from a point p and normal n, shifted by y
float distPlane( vec3 p, vec3 n, float y )
{
	// n must be normalized
	return dot(p-vec3(0,y,0),n);
}

// Formula for fractal from http://blog.hvidtfeldts.net/index.php/2011/08/distance-estimated-3d-fractals-iii-folding-space/
float distFrac(vec3 p)
{
	const float scale = 1.8;
	const float offset = 2.0;

	for(int n=0; n< FRACTALITERATIONS; n++)
	{
		p.xy = (p.x+p.y < 0.0) ? -p.yx : p.xy;
		p.xz = (p.x+p.z < 0.0) ? -p.zx : p.xz;
		p.zy = (p.z+p.y < 0.0) ? -p.yz : p.zy;

		p = scale*p-offset*(scale-1.0);
	}
 
	return length(p) * pow(scale, -float(FRACTALITERATIONS));
}

// return positive values when outside and negative values inside,
// --> distance of the nearest surface.
float distanceField(vec3 p)
{
	//Rotate scene around y-axis
	vec3 rotP = rotate(p, vec3(0, mod(iGlobalTime*20, 360),0));
	rotP = rotate(rotP-vec3(0,-0.6,0), vec3(0, 45,55));
	

	float dPlane = distPlane(p, vec3(0,1,0), -2.0);
	float dFrac = distFrac(rotP);
	return min(dFrac, dPlane);
}

// marching along the ray at step sizes, 
// and checking whether or not the surface is within a given threshold
vec4 raymarch(vec3 rayOrigin, vec3 rayDir)
{
	float totalDist = 0.0;
	for(int j=0; j<MAXSTEPS; j++)
	{
		vec3 p = rayOrigin + totalDist*rayDir;
		float dist = distanceField(p);
		if(abs(dist)<EPSILON)	//if it is near the surface, return an intersection
		{
			return vec4(p, 1.0);
		}
		totalDist += dist;
		if(totalDist>=MAXDEPTH) break;
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

// calculate shadow, ro=origin, rd=dir
// look for nearest point when raymarching, factor k gives smoothnes, 2=smooth, 128=hard
// dl is distance to light, so only return if distance is smaller
float shadow(vec3 ro, vec3 rd, float k)
{
	float res = 1.0;
    for( float t=EPSILON; t<SHADOWDEPTH; )
    {
        float h = distanceField(ro + rd*t);
        if( h<EPSILON )
            return AMBIENT;
        res = min( res, k*h/t );
        t += h;
    }
    return res;
}

//calculate ambient occlusion
float ambientOcclusion(vec3 p, vec3 n)
{
	float res = 0.0;
	float fac = 1.0;
	for(float i=0.0; i<AOSAMPLES; i++)
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
	vec3 light = max(AMBIENT, dot(n, lightDir)) * lightCol;	//lambert light with light Color
	light *= diffuse;	//diffuse lighting, area lit lighting
	light *= shadow(pos, lightDir, SOFTSHADOWFAC);	//add shadow
	light += ambientOcclusion(pos, n) * AMBIENT;
	return light;
}

void main()
{
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.pos = vec3(0,3,-6);
	cam.dir = rotate(normalize(vec3( p.x, p.y, 1 )), vec3(-25, 0, 0));

	vec4 res;

	res = raymarch(cam.pos, cam.dir);
	res.xyz = (res.a==1.0) ? clamp(shading(res.xyz, cam.dir, getNormal(res.xyz)), 0.0, 1.0) : vec3(0);

	gl_FragColor = vec4(res.xyz, 1.0);
}