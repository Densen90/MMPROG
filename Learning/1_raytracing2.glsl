uniform vec2 iResolution;
uniform float iGlobalTime;

struct Sphere
{
	float radius;
	vec3 position;
	vec4 color;
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
	float t;
	vec3 IP;
	vec3 normal;
	vec3 reflection;
	vec3 spherePos;
	vec4 color;
};

Cam cam;
Light light;

void init();
float quad(float a);
float lighting(vec3 M, vec3 I);
Intersection intersect(vec3 dir, vec3 orig);
float calcShadow(vec3 IP);

void main()
{
	init();

	Intersection camI = intersect(cam.direction, cam.origin);
	vec4 col;

	if(camI.exists)
	{
		col = camI.color;

		//Reflection Ray
		Intersection reflectionI = intersect(normalize(camI.reflection), camI.IP);
		col += reflectionI.exists ? reflectionI.color * 0.6 : 0;

		//Shadow Ray of Reflection
		//col *= calcShadow(reflectionI.IP);
		
		//Shadow Ray
		col *= calcShadow(camI.IP);

		//Refraction Ray
		// float n1 = 1.000293; //refract indicies of air
		// float n2 = 1.333;	//refravt inicies of water
		// //Refraction Vector, normalized direction, when first hitting a Sphere
		// float n = (n1/n2);
		// float w = n*dot(camI.normal, -light.direction);
		// float k = sqrt(1 + (w-n)*(w+n));
		// vec3 refRay = (w-k)*camI.normal - n*(-light.direction);

		// float degres = acos(dot((camI.spherePos-camI.IP), refRay) / (length(camI.spherePos-camI.IP) * length(refRay)));
		// vec3 outPoint = 2 * (camI.spherePos-camI.IP) * cos(degres);

		// n = n2/n1;
		// w = n*dot(normalize(outPoint-camI.spherePos), -light.direction);
		// k = sqrt(1 + (w-n)*(w+n));
		// refRay = (w-k)*normalize(outPoint-camI.spherePos) - n*(-light.direction);

		//Intersection refracI = intersect(refRay, outPoint);
		//col += refracI.exists ? refracI.color : 0;
	}
	else
	{
		col = camI.color;
	}

	gl_FragColor = col;
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


	light.position = vec3(0,cos(iGlobalTime),sin(iGlobalTime))*5;	//for point light
	// light.direction = -normalize(vec3(1, -1, 1));	//for directional light
}

float lighting(vec3 normal, vec3 IP)
{
	light.direction = normalize(light.position-IP);	//for point light

	//Lambert Lighting
	float lambert = max(0.2, dot(normal, light.direction));

	//Specular Lighting
	vec3 reflection = normalize(reflect(light.direction, normal));
	vec3 viewDirection = normalize(IP);
	float spec = max(0.2, dot(reflection, viewDirection));
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

	float t = 10000;
	float light = 1;
	for(float x = -0.8; x <= 0.8; x += 0.5)
	{
		for(float y = -0.8; y <= 0.8; y += 0.45)
		{
			for(float z = 1.0; z <= 3.0; z += 0.6)
			{
				s.position = vec3(x, y, z);
				s.color = vec4(mod(x*y*z, 1), mod(x+y*z, 1), z/5, 1);

				vec3 MO = orig-s.position;
				float al1 = -dot(dir, (MO));
				float discriminant = quad(dot(dir, MO)) - quad(length(dir)) * (quad(length(MO)) - quad(s.radius));
				float new_t = -1;

				if(discriminant >= 0.001)
				{
					float t1 = al1 + sqrt( discriminant );
					float t2 = al1 - sqrt( discriminant );
					new_t = t2>0 ? t2 : t1;	//t2 is smaller than t1, just check if t2<0
				}

				if((new_t>0) && (new_t<t))
				{
					t = new_t;

					ret.IP = orig + (t-0.01)*dir;
					ret.normal = normalize(ret.IP-s.position);
					ret.reflection = reflect(dir, ret.normal);
					ret.t = new_t;
					ret.spherePos = s.position;

					light = lighting(ret.normal, ret.IP);
					ret.color = light * s.color;
					ret.exists = true;
				}
			}
		}
	}
	return ret;
}

float calcShadow(vec3 IP)
{
	//Shadow Ray
	//Soft Shadow, look by a light plane, how many is visible
	float dif = 0;
	float visible = 0;
	float total =0;

	//Calculations for Light plane
	vec3 lpNormal = normalize(IP-light.position);
	//these vectors ar orhtogonal to the Normal and span my plane
	vec3 planeXdir = vec3(lpNormal.y, -lpNormal.x, lpNormal.z);
	vec3 planeYdir = vec3(-lpNormal.y, lpNormal.x, lpNormal.z);

	float distToLight = length(IP-light.position);

	for(float i=1-dif; i<=1+dif; i+=0.1)
	{
		for(float j=1-dif; j<=1+dif; j+=0.1)
		{
			//calculate one position for the light on the plane
			vec3 lPos = light.position + i*planeXdir + j*planeYdir;
			vec3 lDir = normalize(lPos - IP);
			Intersection shadowI = intersect(lDir, IP);
			visible += shadowI.exists && shadowI.t<distToLight ? 0 : 1;
			total++;
		}
	}

	return visible/total;
}