uniform vec2 iResolution;
uniform float iGlobalTime;
uniform sampler2D tex;
in vec2 uv;

const int maxSteps = 200;	// slow if the step size is small, and inaccurate if the step size is large
const float epsilon = 0.0001;
const float ambient = 0.2;
const float PI = 3.14159;
const float bigNumber = 10000;

struct Cam
{
	vec3 orig;
	vec3 dir;
};

struct Light
{
	vec3 orig;
	vec3 dir;
};

struct Material
{
	vec3 col;
	float refCoef;
};

struct Intersection
{
	vec3 IP;
	vec3 normal;
	Material mat;
};

Light light;
Cam cam;
Intersection intersect;
Material matWhite;
float elapsedTime = 0.0;

void materialInit();
bool raymarch(vec3 O, vec3 D);
float shadow(vec3 O, vec3 D, float k, float dl);
float ambientOcclusion(vec3 O, vec3 D);
float lighting(vec3 N, vec3 IP);
vec3 getNormal(vec3 P);
vec3 rotate( vec3 p, vec3 r );

void main()
{
	materialInit();
	//shift camera to center, origin(0,0) is now at middle of screen
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.orig = vec3(0,-0.3,-2.5);
	cam.dir = normalize(vec3( p.x, p.y, 1 ));

	light.orig = vec3(0.8, 0.7, -3);

	vec3 col = vec3(0.0);
	float steps = maxSteps;
	
	if(raymarch(cam.orig, cam.dir))
	{
		Intersection firstIntersect = intersect;
		col = firstIntersect.mat.col;
		// col *= lighting(firstIntersect.normal, firstIntersect.IP);
		float refCoef = firstIntersect.mat.refCoef;

		//shadow
		vec3 shadowRay = normalize(light.orig-firstIntersect.IP);
		// col *= shadow(firstIntersect.IP+0.01*firstIntersect.normal, shadowRay, 2.0, distance(firstIntersect.IP, light.orig));
	
		//ambientOcclusion
		float ao = ambientOcclusion(firstIntersect.IP, firstIntersect.normal);
		// col *= ao;
	}
	
	gl_FragColor = vec4(col, 1.0);
}

void materialInit()
{
	matWhite.col = vec3(1.0);
	matWhite.refCoef = 0.0;
}

float si(float x)
{
	return x==0.0 ? 0.0 : sin(x)/x;
}

// unions two distances / objects
float opUnion( float d1, float d2 )
{
    return min(d1,d2);
}

// substracts two distances / objects
float opSubstract( float d1, float d2 )
{
    return max(-d1,d2);
}

// intersects two distances / objects
float opIntersect( float d1, float d2 )
{
    return max(d1,d2);
}

//get rotation matrix for angle
mat3 RotationMatrix(float angleX, float angleY, float angleZ)
{
	angleX = angleX*PI/180.0;
	angleY = angleY*PI/180.0;
	angleZ = angleZ*PI/180.0;

	mat3 xRot = mat3 (	1,	0,				0,
						0,	cos(angleX),	-sin(angleX),
						0,	sin(angleX),	cos(angleX) );
	mat3 yRot = mat3 ( 	cos(angleY),		0,	sin(angleY),
						0,					1,	0,
						-sin(angleY),		0,	cos(angleY) );
	mat3 zRot = mat3 (	cos(angleZ),	-sin(angleZ),	0,
						sin(angleZ),	cos(angleZ),	0,
						0,				0,				1 );
	return xRot * yRot * zRot;
}

// Rotation / Translation of a point p with rotation r
vec3 rotate( vec3 p, vec3 r )
{
    return RotationMatrix(r.x, r.y, r.z)*p;
}

float distSphere(vec3 p, float rad)
{
	return length(p) - rad;
}

float distTriPrism( vec3 p, vec2 h )
{
    vec3 q = abs(p);
    return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}

//Returns the closest distance to a surface from p in our scene, 
//we can step this far, without overshooting
float distanceField(vec3 p)
{
	float ret;
	float rot = sin(iGlobalTime)*360;
	vec3 pos = rotate(p-vec3(0, 0, 3.0), vec3(0,0,rot));
	float dist1 = distTriPrism(pos, vec2(0.6));
	float dist2 = distSphere(pos, 0.6);
	ret = opUnion(dist1, dist2);
	ret = clamp(mix(dist1, dist2, sin(iGlobalTime)), 0.0, 1.0);

	pos = rotate(p-vec3(0, 0, 3.0), vec3(0,0,rot+180));
	dist1 = distTriPrism(pos, vec2(0.4));
	dist2 = distSphere(pos, 0.6);
	float tmp = clamp(mix(dist1, dist2, sin(iGlobalTime)), 0.0, 1.0);

	ret = opUnion(ret, tmp);

	intersect.mat = matWhite;

	return ret;
}

// marching along the ray at step sizes, 
// and checking whether or not the surface is within a given threshold
bool raymarch(vec3 rayOrigin, vec3 rayDir)
{
	float totalDist = 0.0;
	for(int j=0; j<maxSteps; j++)
	{
		vec3 p = rayOrigin + totalDist*rayDir;
		float dist = distanceField(p);
		if(dist<epsilon)	//if it is near the surface, return an intersection
		{
			intersect.IP = rayOrigin + totalDist*rayDir;
			intersect.normal = getNormal(rayOrigin + totalDist*rayDir);
			return true;
		}
		totalDist += dist;
	}

	return false;
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

//Calculates the lambert and specular light, for a given IntersectionPoint
float lighting(vec3 normal, vec3 IP)
{
	light.dir = normalize(light.orig-IP);	//for point light

	//Lambert Lighting
	float lambert = max(ambient, dot(normal, light.dir));

	//Specular Lighting
	vec3 reflection = normalize(reflect(light.dir, normal));
	vec3 viewDirection = normalize(IP);
	float spec = max(ambient, dot(reflection, viewDirection));
	spec = lambert+pow(spec, 20);

	return spec;
}

// calculate shadow, ro=origin, rd=dir
// look for nearest point when raymarching, factor k gives smoothnes, 2=smooth, 128=hard
// dl is distance to light, so only return if distance is smaller
float shadow(vec3 ro, vec3 rd, float k, float dl)
{
	float res = 1.0;
    for( float t=0; t < 100.0; )
    {
        float h = distanceField(ro + rd*t);
        if( h<epsilon )
            return ambient;
        // res = min( res, k*h/t );
        t += h;
        if(t>=dl) return res;
    }
    return res;
}

float ambientOcclusion(vec3 ro, vec3 rd)
{
	float step = 0.01;
	float ao = distanceField(ro + step*rd);
	float res = ao/step;	//if ao, distance to nearest object is smaller than the step
					//point is in a narrow place, if bigger, ao is bigger, o ambient ambient Occlusion
	return clamp(res, 0.8, 1.0);
}