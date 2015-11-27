uniform vec2 iResolution;
uniform float iGlobalTime;
uniform sampler2D tex;
uniform sampler2D tex2;
in vec2 uv;

#define PI 3.14159
#define MAXSTEPS 256
#define EPSILON 0.001
#define AMBIENT 0.2
#define MAXDEPTH 100.0
#define SHADOWDEPTH 32.0
#define SOFTSHADOWFAC 10.0

const vec3 lightDir = normalize(vec3(-1.0,0.8,-1.0));

struct Camera
{
	vec3 pos;
	vec3 dir;
} cam;

// give the distance to a plane from a point p and normal n, shifted by y
float distPlane( vec3 p, vec3 n, float y )
{
	// n must be normalized
	return dot(p-vec3(0,y,0),n);
}

// give the distance from point p to a sphere surface at origin
float distSphere(vec3 p, float rad)
{
	return length(p) - rad;
}

// return positive values when outside and negative values inside,
// --> distance of the nearest surface.
float distanceField(vec3 p)
{
	float dSphere = distSphere(p - vec3(0, -0.3, 5), 0.5);
	float dPlane = distPlane(p, vec3(0,1,0), -1);
	return min(dSphere, dPlane);
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
	return vec4(0.0);
}

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

//calculatte the color, the shadow, the lighting for a position
vec3 shading(vec3 pos, vec3 rd, vec3 n)
{
	vec3 col = vec3(0.5, 0.6, 0.9);
	vec3 light = max(AMBIENT, dot(n, lightDir)) * col;	//lambert light with light Color
	// light *= diffuse;	//diffuse lighting, area lit lighting
	light *= shadow(pos + EPSILON*n, lightDir, SOFTSHADOWFAC);	//add shadow
	// light += ambientOcclusion(pos, n) * AMBIENT;

	return light;
}

void main()
{
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.pos = vec3(0,0,0);
	cam.dir = normalize(vec3( p.x, p.y, 1 ));

	vec4 res = raymarch(cam.pos, cam.dir);

	res.xyz = (res.a==1.0) ? clamp(shading(res.xyz, cam.dir, getNormal(res.xyz)), 0.0, 1.0) : vec3(0);

	gl_FragColor = vec4(res.xyz, 1.0);
}