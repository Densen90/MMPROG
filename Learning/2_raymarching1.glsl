uniform vec2 iResolution;
uniform float iGlobalTime;

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

struct Intersection
{
	vec3 IP;
	vec3 normal;
	float minDist;
	float steps;
};

Light light;
Cam cam;
Intersection intersect;

bool raymarch(vec3 O, vec3 D);
float lighting(vec3 N, vec3 IP);
vec3 getNormal(vec3 P);
vec3 rotate( vec3 p, vec3 r );
float si(float x);

void main()
{
	//shift camera to center, origin(0,0) is now at middle of screen
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.orig = vec3(0,-0.3,iGlobalTime);
	cam.dir = normalize(vec3( p.x, p.y, 1 ));

	cam.dir = rotate(cam.dir,vec3(mod(iGlobalTime*15, 360), mod(iGlobalTime*10, 360), mod(iGlobalTime*25, 360)));

	// light.orig = vec3(0, sin(iGlobalTime), cos(iGlobalTime));
	light.orig = cam.orig;
	vec3 col;
	
	if(raymarch(cam.orig, cam.dir))
	{

		vec3 col1 = vec3(0.2,0.4,0.7);
		vec3 col2 = vec3(0.7,0.2,0.2);
		col = mix(col1, col2, max(0, si( mod(iGlobalTime*5, 6)-3 )));
		col *= lighting(intersect.normal, intersect.IP);

		//reflection
		0	
	}

	//fog
	vec3 fogColor = vec3(0.1);
	float fogDist = 50;
	col = mix(col, fogColor, intersect.steps/fogDist);

	gl_FragColor = vec4(col, 1.0);
}

float si(float x)
{
	return sin(x)/(x);
}

// give the distance from point p to a sphere surface at origin
float distSphere(vec3 p, float rad)
{
	return length(p) - rad;
}

// give the distance from point p to a box surface with dimensions b
float distBox(vec3 p, vec3 b)
{
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) +
         length(max(d,0.0));
}

// give the distance to a torus from a point p and dimension t
float distTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

// give the distance to a plane from a point p and normal n, shifted by y
float distPlane( vec3 p, vec3 n, float y )
{
  // n must be normalized
  return dot(p,n.xyz) + y;
}

// repetition for a point p with 
// factor c = (distance between spheres)
// t = the restriction
vec3 pointRepetition(vec3 p, vec3 c, vec3 t)
{
	vec3 v = mod(p, c) - 0.5 * c;
	// bool farPlane = (p.x > cam.orig.x+t.x) || (p.x < cam.orig.x-t.x) || (p.y > cam.orig.y+t.y) || (p.z > cam.orig.z+t.z);
	// bool nearPlane = (p.z < cam.orig.z+0.3);
	// v *= farPlane || nearPlane ? 0 : 1;
	return v;
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

// twist the object
vec3 opTwist( vec3 p, float amount )
{
    float c = cos(amount*p.y);
    float s = sin(amount*p.y);
    mat2  m = mat2(c,-s,s,c);
    return vec3(m*p.xz,p.y);
}

//get rotation matrix for angle
mat3 RotationMatrix(float angleX, float angleY, float angleZ)
{
	angleX = angleX*PI/180.0;
	angleY = angleY*PI/180.0;
	angleZ = angleZ*PI/180.0;

	mat3 xRot = mat3 (	1,	0,			0,
						0,	cos(angleX),	-sin(angleX),
						0,	sin(angleX),	cos(angleX) );
	mat3 yRot = mat3 ( 	cos(angleY),		0,	sin(angleY),
						0,				1,	0,
						-sin(angleY),	0,	cos(angleY) );
	mat3 zRot = mat3 (	cos(angleZ),	-sin(angleZ),	0,
						sin(angleZ),	cos(angleZ),		0,
						0,			0,				1 );
	return xRot * yRot * zRot;
}

// Rotation / Translation of a point p with rotation r
vec3 rotate( vec3 p, vec3 r )
{
    return RotationMatrix(r.x, r.y, r.z)*p;
}

//Returns the closest distance to a surface from p in our scene, 
//we can step this far, without overshooting
float distanceField(vec3 p)
{
	// float d0 = distSphere(p - vec3(-0.8, -0.17, 0), 0.2);
	// float d1 = distBox(p - vec3(0.8, -0.17, 0), vec3(0.2, 0.2, 0.2));

	// d0 = opUnion(d0,d1);
	// d1 = distTorus(p - vec3(0, -0.17, 0), vec2(0.2,0.2));
	// float d3 = opSubstract(d0,d1);

	// vec3 point = rotate( p - vec3(-0.5, -0.17, 0), xRotationMatrix(mod(iGlobalTime*40,180)));
	// point = opTwist(point, 20);
	// float d0 = distTorus(point, vec2(0.3,0.1));

	// vec3 point2 = rotate( p - vec3(0.5, -0.17, 0), xRotationMatrix(mod(iGlobalTime*40,180)));
	// float d1 = distTorus(point2, vec2(0.3,0.1));

	// return opUnion(d0,d1);

	float dPlane = distPlane(p, normalize(vec3(0,1,0)), 0.5);

	vec3 point = pointRepetition(p, vec3(0.6, 0.5, 1.5), vec3(3,2,10));
	// float dSphere = length(point)>0 ? distSphere(point, 0.15) : bigNumber;
	float dBox = distBox(rotate(point, vec3(mod(iGlobalTime*70, 180), 0, 0)), vec3(0.15, 0.05, 0.15));
	float dTorus = distTorus(rotate(point, vec3(0, 0, mod(iGlobalTime*70, 180))), vec2(0.2, 0.03));

	return opUnion(dBox,dTorus);
}

// marching along the ray at step sizes, 
// and checking whether or not the surface is within a given threshold
bool raymarch(vec3 rayOrigin, vec3 rayDir)
{
	float totalDist = 0.0;
	intersect.minDist = 1;
	for(int j=0; j<maxSteps; j++)
	{
		vec3 p = rayOrigin + totalDist*rayDir;
		float dist = distanceField(p);
		intersect.minDist = dist < intersect.minDist ? dist : intersect.minDist;
		if(dist<epsilon)	//if it is near the surface, return an intersection
		{
			intersect.IP = rayOrigin + totalDist*rayDir;
			intersect.normal = getNormal(rayOrigin + totalDist*rayDir);
			return true;
		}
		intersect.steps++;
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
	float spec = 0; // max(ambient, dot(reflection, viewDirection));
	spec = lambert+pow(spec, 20);

	return spec;
}

// calculate the background color
vec3 background(vec3 dir)
{
	// light.orig = vec3(sin(iGlobalTime + 2.0), 0.6, cos(iGlobalTime + 2.0));

	float sun = max(0.0, dot(dir, normalize(light.orig)));
	float sky = max(0.0, dot(dir, vec3(0.0, 1.0, 0.0)));
	float ground = max(0.0, -dot(dir, vec3(0.0, 1.0, 0.0)));
	return 
  (pow(sun, 256.0) + 0.2 * pow(sun, 2.0)) * vec3(2.0, 1.6, 1.0) +
  pow(ground, 0.5) * vec3(0.4, 0.3, 0.2) +
  pow(sky, 1.0) * vec3(0.5, 0.6, 0.7);
}