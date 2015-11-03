uniform vec2 iResolution;
uniform float iGlobalTime;

struct Material
{
	vec3 color;
	float reflectionCoeff;
};

struct Sphere
{
	float radius;
	vec3 position;
	Material mat;
};

struct Plane
{
	float k;
	vec3 normal;
	Material mat;
};

struct Cam
{
	vec3 origin;
	vec3 direction;
};

struct Light
{
	vec3 position;
	vec3 direction;
};

struct Intersection
{
	bool exists;
	vec3 IP;
	vec3 normal;
	vec3 reflection;
	Material mat;
};

Cam cam;
Light light;
const float eps = 0.001;
const float ambient = 0.2;
const float refInd_air = 1.000293;
const float refInd_water = 1.333;

void init();
float quad(float a);
float lighting(vec3 M, vec3 I);
Intersection intersect(vec3 dir, vec3 orig);
float intersectSphere(vec3 dir, vec3 origin, Sphere s);
float intersectPlane(vec3 dir, vec3 origin, Plane p);
float calcShadow(vec3 IP);

vec3 background(vec3 dir)
{
	light.position = vec3(sin(iGlobalTime + 2.0), 0.6, cos(iGlobalTime + 2.0));
	float sun = max(0.0, dot(dir, normalize(light.position)));
	float sky = max(0.0, dot(dir, vec3(0.0, 1.0, 0.0)));
	float ground = max(0.0, -dot(dir, vec3(0.0, 1.0, 0.0)));
	return 
  (pow(sun, 256.0) + 0.2 * pow(sun, 2.0)) * vec3(2.0, 1.6, 1.0) +
  pow(ground, 0.5) * vec3(0.4, 0.3, 0.2) +
  pow(sky, 1.0) * vec3(0.5, 0.6, 0.7);
}

void main()
{
	init();

	Intersection camI = intersect(cam.direction, cam.origin);
	vec3 col = background(cam.direction);

	if(camI.exists)
	{
		//numerical stable point outside Sphere
		camI.IP += camI.normal*eps;

		col = camI.mat.color * lighting(camI.normal, camI.IP);

		//Shadow Ray
		col *= calcShadow(camI.IP);

		//Refraction
		vec3 refractDir = normalize(refract(cam.direction, camI.normal, refInd_air/refInd_water));
		Intersection refI = intersect(refractDir, camI.IP - 2*eps*camI.normal);
		if(refI.exists)
		{
			refractDir = normalize(refract(refractDir, -refI.normal, refInd_water/refInd_water));
			Intersection refI2 = intersect(refractDir, refI.IP + eps*refI.normal);
			
			vec3 refCol = refI2.mat.color * camI.mat.reflectionCoeff * lighting(refI2.normal, refI2.IP);
			col = refI2.exists ? refCol : background(refractDir);
		}

		//Reflection Ray
		// Intersection reflectionI = intersect(camI.reflection, camI.IP);
		// if(reflectionI.exists)
		// {
		// 	reflectionI.IP += reflectionI.normal * eps;
		// 	vec3 refCol = reflectionI.mat.color * camI.mat.reflectionCoeff * lighting(reflectionI.normal, reflectionI.IP);
		// 	col += reflectionI.exists ? refCol : background(camI.reflection);
			
		// 	//Shadow Ray of Reflection
		// 	//col *= calcShadow(reflectionI.IP);
		// }
	}

	gl_FragColor = vec4(col, 1);
}

float quad(float a)
{
	return a * a;
}

void init()
{
	//shift camera to center, origin(0,0) is now at middle of screen
	float fov = 60.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	cam.origin = vec3(0.0,0.0,0.0);
	cam.direction = normalize(vec3( p.x, p.y, 1 ));

	//light.position = vec3(sin(iGlobalTime),1,cos(iGlobalTime))*5;	//for point light
	// light.direction = -normalize(vec3(1, -1, 1));	//for directional light
}

float lighting(vec3 normal, vec3 IP)
{
	light.direction = normalize(light.position-IP);	//for point light

	//Lambert Lighting
	float lambert = max(ambient, dot(normal, light.direction));

	//Specular Lighting
	vec3 reflection = normalize(reflect(light.direction, normal));
	vec3 viewDirection = normalize(IP);
	float spec = 0; // max(ambient, dot(reflection, viewDirection));
	spec = lambert+pow(spec, 20);

	return spec;
}

Intersection intersect(vec3 dir, vec3 orig)
{
	//t = -direction * (origin-center) +- sqrt( (direction*(origin-center))² - length(direction)²*(length(origin-center)²-radius²) )
	Intersection ret;
	ret.exists = false;

	Sphere s;
	s.radius = 0.15;
	//s.position = vec3(0, -0.17, 2);
	//s.mat.color = vec4(0.5, 0.2, 0.8, 1);
	s.mat.reflectionCoeff = 1.4;

	float t = 10000;

	for(float i=-0.15; i<=0.15; i+=0.3)
	{
		s.position = vec3(i*2, -0.17, 2);
		s.mat.color = vec3(0.5+i*3, 0.2+i*3, 0.8+i*3);

		float new_t = intersectSphere(dir, orig, s);

		if((new_t>0) && (new_t<t))
		{
			t = new_t;
			ret.IP = orig + t*dir;
			ret.normal = normalize(ret.IP-s.position);
			ret.reflection = normalize(reflect(dir, ret.normal));

			ret.mat = s.mat;
			ret.exists = true;
		}
	}

	Plane p;
	p.k = 0.325;
	p.normal = normalize(vec3(0,1,0));
	p.mat.reflectionCoeff = 0.0;

	float new_t = intersectPlane(dir, orig, p);

	if((new_t>0) && (new_t<t))
	{
		t = new_t;
		ret.IP = orig + t*dir;
		p.mat.color = vec3(0.8, 0.4, 0.3);
		ret.normal = p.normal;
		ret.reflection = normalize(reflect(dir, ret.normal));

		ret.mat = p.mat;
		ret.exists = true;
	}

	return ret;
}

float intersectSphere(vec3 dir, vec3 origin, Sphere s)
{
	vec3 MO = origin-s.position;
	float al1 = -dot(dir, (MO));
	float discriminant = quad(dot(dir, MO)) - quad(length(dir)) * (quad(length(MO)) - quad(s.radius));
	float t = -1;

	if(discriminant >= eps)
	{
		float t1 = al1 + sqrt( discriminant );
		float t2 = al1 - sqrt( discriminant );
		t = t2>0 ? t2 : t1;	//t2 is smaller than t1, just check if t2<0
	}
	return t;
}

float intersectPlane(vec3 dir, vec3 origin, Plane p)
{
	float t = -1;

	float al1 = -p.k - dot(p.normal, origin);
	float al2 = dot(p.normal, dir);
	if(al2!=0)
	{
		t = al1/al2;
	}

	return t;
}

float calcShadow(vec3 IP)
{
	//Shadow Ray
	//Soft Shadow, look by a light plane, how many is visible
	float dif = 1;
	float steps = 0.1;
	float visible = 0;
	float total =0;

	//Calculations for Light plane
	vec3 lpNormal = normalize(IP-light.position);
	//these vectors ar orhtogonal to the Normal and span my plane
	vec3 planeXdir = vec3(lpNormal.y, -lpNormal.x, lpNormal.z);
	vec3 planeYdir = vec3(-lpNormal.y, lpNormal.x, lpNormal.z);

	float distToLight = length(IP-light.position);

	for(float i=1-dif; i<=1+dif; i+=steps)
	{
		for(float j=1-dif; j<=1+dif; j+=steps)
		{
			//calculate one position for the light on the plane
			vec3 lPos = light.position + i*planeXdir + j*planeYdir;
			vec3 lDir = normalize(lPos - IP);
			Intersection shadowI = intersect(lDir, IP);
			visible += shadowI.exists && length(shadowI.IP-IP)<distToLight ? 0 : 1;
			total++;
		}
	}

	return max(ambient, visible/total);
}