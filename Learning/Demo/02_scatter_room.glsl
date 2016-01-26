//Thanks to light scatter shader by Robert Cupisz 2013

uniform vec2 iResolution;
uniform float iGlobalTime;

uniform float uCameraZ;
uniform float uScatterPower;
uniform float uZRotation;
uniform float uXRotation;
uniform float uFade;

#define INF 1.0e38
#define PI 3.14159
#define SCATTER_STEPS 356

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

//Perlin Noise Function, thanks to Robert Cupisz
float fbm (vec3 p)
{
	mat3 m = mat3( 0.00,  0.80,  0.60,
			  -0.80,  0.36, -0.48,
			  -0.60, -0.48,  0.64 );
	float f;
	f  = 0.5000*noise( p ); p = m*p*2.02;
	f += 0.2500*noise( p ); p = m*p*2.03;
	f += 0.1250*noise( p );
	// f += 0.0625*noise( p );
	return f;
}

float particles (vec3 p)
{
	vec3 pos = p;
	pos.y -= iGlobalTime*0.2;	//particles moving up
	float n = fbm(20.0*pos);
	n = pow(n, 5.0);
	float brightness = noise(10.3*p);
	float threshold = 0.26;
	return smoothstep(threshold, threshold + 0.15, n)*brightness*90.0;
}

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

float window(vec3 roofPos, vec3 dir)
{
	float dist = -roofPos.y/dir.y;

	// An offset, so that shadow rays starting from the roof don't
	// think they're unoccluded
	if (dist < -0.1)
		return INF;
	
	// We've hit the plane. If we've hit the window, but
	// not the beams, return no hit.
	float spread = mix(0.0, 0.81, max(0.0, 1.0-uFade));
	vec2 pos = roofPos.xz + dist*dir.xz;	//go to position of the roof
	vec2 window = abs(pos) - spread;	//abs -> limit spread

	float winDist = 0.055;	//how far away the windows are from each other
	// double beams -> windows: size of window: 0.544, shifted by 0.27
	vec2 beams = winDist - abs(mod(pos, 0.41) - 0.43);
	if (max(max(window.x, window.y), max(beams.x, beams.y)) < 0.0)
		return INF;

	return dist;
}

float wall(float wallDist, float dirY)
{
	float floorHit = -(wallDist/dirY);

	return floorHit < 0.0 ? INF : floorHit;
}

float box(vec3 org, vec3 dir, vec3 size)
{
	// compute intersection of ray with all six bbox planes
	vec3 invR = 1.0 / dir;
	vec3 tbot = invR * (-0.5*size - org);
	vec3 ttop = invR * (0.5*size - org);
	
	// re-order intersections to find smallest and largest on each axis
	vec3 tmin = min (ttop, tbot);
	vec3 tmax = max (ttop, tbot);
	
	// find the largest tmin and the smallest tmax
	vec2 t0 = max (tmin.xx, tmin.yz);
	float near;
	near = max (t0.x, t0.y);
	t0 = min (tmax.xx, tmax.yz);
	float far = min (t0.x, t0.y);

	// check for hit
	return near < far && far > 0.0 ? near : INF;
}

float raycast (vec3 ro, vec3 rd, bool scatter)
{
	//Raycasting with two planes (Floor and roof)
	float dist = INF;

	vec3 roRot = rotate(ro, vec3(uXRotation, 0, uZRotation));
	vec3 rdRot = rotate(rd, vec3(uXRotation, 0, uZRotation));

	vec3 windowPos = vec3(0,-1,0.1);

	//check if hit is at the World Position of RoofPosition
	vec3 roofPos = roRot+windowPos;
	vec3 rayDir = rdRot;
	// dist = min(dist, box(vec3(0,0,-1), rd, vec3(0.2,0.2,0.2)));
	dist = min(dist, window(roofPos, rayDir));
	
	
	// Distance wall to window
	float wallDist = 0.95;
	//depending if it is scatter: if scatter, don't rotate plane, to scatter to ground, if no scatter, raycast to parallel wall
	wallDist = scatter ? ro + wallDist : roRot + wallDist;
	float  dirY = scatter ? rd.y : rdRot.y;
	float floorHit = wall(wallDist, dirY);

	dist = min(dist, floorHit);

	return dist;
}

vec3 inscatter (vec3 ro, vec3 rd, vec3 scatterDir, float hit, vec2 screenPos)
{
	float farPlane = 9.0;
	
	float distAlongView = min(hit, farPlane);	//distance not higher than farPlane
	float oneOverSteps = 1.0/float(SCATTER_STEPS);
	vec3 step = rd*distAlongView*oneOverSteps;	//how long is one step on the scatter ray
	vec3 pos = ro;
	float light = 0.0;
	
	// add noise to the start position to hide banding
	pos += rd*noise(vec3(2.0*screenPos, 0.0))*0.05;

	for(int i = 0; i < SCATTER_STEPS; i++)
	{
		//if hit, it is black, else white, later the mean is builded to have a transparent godray
		float l = raycast(pos, scatterDir, true) == INF ? 1.0 : 0.0;
		light += l;
		//particles only if they are in the godray
		//COMMENTED OUT BECAUSE OF PERFORMANCE
		// light += particles(pos)*l;
		pos += step;
	}

	light *= oneOverSteps * distAlongView;	//the mean(Durchschnitt)
	return light*vec3(uScatterPower);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	float fov = 100.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	vec3 ro = vec3( 0.02, 0.0, uCameraZ);
	vec3 rd = normalize(vec3( p.x, p.y, 1 ));

	// raycast the scene
	float d = raycast(ro,rd, false);
	
	// white window -> no hit
	if (d == INF)
	{
		fragColor = vec4(1.0);
		return;
	}

	vec3 hitPos = ro + d * rd;

	float shadowBias = 1.0e-4;

	vec3 col = vec3(0.0);

	//scatter direction based on the rotation of the window
	float xsDir = uZRotation < 0 ? 1.0 : -1.0;
	float ysDir = 0.6;
	float zsDir = 0;

	if(uZRotation == 0)
	{
		xsDir = 0.0; ysDir = 0.6; zsDir = 1.0;
	}
	if(uXRotation == 90) ysDir = 0.0;

	vec3 scatterDir = vec3(xsDir, ysDir, zsDir);

	col += inscatter(ro, rd, scatterDir, d, fragCoord.xy);
	
	// color correction - Sherlock color palette ;)
	col.r = smoothstep(0.0, 0.5, col.r);
	col.g = smoothstep(0.0, 0.5, col.g - 0.1);
	col.b = smoothstep(-0.3, 1.5, col.b);
	
	fragColor = vec4(col, 1.0);
}

void main()
{
	mainImage(gl_FragColor, gl_FragCoord.xy);
}