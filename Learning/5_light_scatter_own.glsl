uniform vec2 iResolution;
uniform float iGlobalTime;

#define PI 3.14159
#define MAXSTEPS 256
#define EPSILON 0.001
#define AMBIENT 0.2
#define MAXDEPTH 100.0
#define INSCATTER_STEPS 48.0
#define SCENETRACEDEPTH 12.0

struct Ray
{
	vec3 orig;
	vec3 dir;
} cam;

struct Light
{
	vec3 orig;
	vec3 dir;
} light;

float hash (float n)
{
	return fract(sin(n)*43758.5453);
}

float noise (in vec3 x)
{
	vec3 p = floor(x);
	vec3 f = fract(x);

	f = f*f*(3.0-2.0*f);

	float n = p.x + p.y*57.0 + 113.0*p.z;

	float res = mix(mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
						mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y),
					mix(mix( hash(n+113.0), hash(n+114.0),f.x),
						mix( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
	return res;
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

	float dSphere1 = distSphere(p -  vec3(0.5,  0.5, 2.0), 0.25);
	dSphere1 = min(dSphere1, distSphere(p -  vec3(0.5,  -0.5, 2.0), 0.25));
	dSphere1 = min(dSphere1, distSphere(p -  vec3(-0.5,  -0.5, 2.0), 0.25));

	return dSphere1;
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
bool raymarch(vec3 rayOrigin, vec3 rayDir, out vec3 hitPos, out vec3 hitNormal)
{
	float totalDist = 0.0;
	hitPos = rayOrigin;
	for(int j=0; j<MAXSTEPS; j++)
	{
		vec3 p = rayOrigin + totalDist*rayDir;
		float dist = distanceField(p);
		if(abs(dist)<EPSILON)	//if it is near the surface, return an intersection
		{
			hitPos = p;
			hitNormal = getNormal(p);
			return true;
		}
		totalDist += dist;
		if(totalDist>=MAXDEPTH) break;
	}
	return false;
}

vec3 inscatter( in Ray rayEye, in vec4 light, in vec3 screenPos)
{
	vec3 rayEeyeNDir = normalize( rayEye.dir );
	
	float scatter = 0.0;	//how much the scatter is
	float invStepSize = 1.0 / INSCATTER_STEPS;	//one step on the ray for scattering
	
	vec3 hitPos, hitNrm;
	vec3 p = rayEye.orig;
	vec3 dp = rayEeyeNDir * invStepSize * SCENETRACEDEPTH;
	
	// apply random offset to minimize banding artifacts.
	// p += dp * noise( screenPos ) * 1.5;
	
	for ( int i = 0; i < INSCATTER_STEPS; ++i )
	{
		p += dp;
		
		Ray lightRay;
		lightRay.orig = p;
		lightRay.dir = light.xyz - p;
		float dist2Lgt = length( lightRay.dir );
		lightRay.dir /= 8.0;
		
		float sum = 0.0;
		if ( !raymarch( lightRay.orig, lightRay.dir, hitPos, hitNrm ) )
		{
			// a simple falloff function base on distance to light
			float falloff = 1.0 - pow( clamp( dist2Lgt / light.w, 0.0, 1.0 ), 0.125 );
			sum += falloff;
			
			// float smoke = noise( 1.25 * ( p + vec3( iGlobalTime * 0.5, 0.0, 0.0 ) ) ) * 0.375;
			// sum += smoke * falloff;
		}
		
		scatter += sum;
	}
	
	scatter *= invStepSize; // normalize the scattering value
	scatter *= 8.0; // make it brighter
	
	return vec3( scatter );
}

void main()
{
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.orig = vec3( 0.0, 0.0, 0.0 );
	cam.dir = normalize(vec3( p.x, p.y, 1 ));
	vec4 light = vec4( 		//xyz: pos, w: strength
					0.0 + sin( iGlobalTime * 0.5 ) * 2.0, 
					0.0 + cos( iGlobalTime * 0.5 ) * 2.0, 
					3.0, 
					8.0 );

	vec3 hitPos, hitNormal;
	vec3 res = vec3(0.0);
	if(raymarch(cam.orig, cam.dir, hitPos, hitNormal))
	{
		res.rgb = vec3(0.125);
	}

	res.rgb += inscatter(cam, light, vec3( gl_FragCoord.xy, 0.0 ));

	// color correction - Sherlock color palette
	res.r = smoothstep( 0.0, 1.0, res.r );
	res.g = smoothstep( 0.0, 1.0, res.g - 0.1 );
	res.b = smoothstep(-0.3, 1.3, res.b );

	gl_FragColor = vec4(res.xyz, 1.0);
}