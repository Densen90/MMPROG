// Raycasting with lambert and specular light for directional and point light

uniform vec2 iResolution;
uniform float iGlobalTime;

struct Sphere
{
	float radius;
	vec3 position;
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

float quad(float a);
float lighting(vec3 M, vec3 I);
float intersect(Cam c, Sphere s);

void main()
{
	//shift camera to center, origin(0,0) is now at middle of screen
	float fov = 90.0;
	float tanFov = tan(fov / 2.0 * 3.14159 / 180.0) / iResolution.x;
	vec2 p = tanFov * (gl_FragCoord.xy * 2.0 - iResolution.xy);

	Cam cam;
	cam.origin = vec3(0.0,0.0,0.0);
	cam.direction = normalize(vec3( p.x, p.y, 1 ));

	Sphere s;
	s.radius = 0.2;

	float t = 10000;
	float light = 1;
	vec4 color = vec4(1,1,1,1);

	for(float i=1; i<60.0; i+=0.3)
	{
		float deltaMove = i-mod(iGlobalTime, 2*3.14159);
		s.position = vec3(sin(i-1.8), tan(deltaMove), i);

		float new_t = intersect(cam, s);

		if((new_t>0) && (new_t<t))
		{
			t = new_t;

			light = lighting(s.position, t*cam.direction + cam.origin);
			color = light * vec4(i/40, 1-i/40, 0.8, 1);
		}
	}

	gl_FragColor = color;
}

float quad(float a)
{
	return a * a;
}

float lighting(vec3 M, vec3 I)
{
	Light l;
	l.position = vec3(0,0,sin(iGlobalTime*0.5)+1)*5;	//for point light
	l.direction = normalize(l.position-I);	//for point light
	//l.direction = -normalize(vec3(1, -1, 1));	//for directional light

	//Lambert Lighting
	vec3 normal = normalize(I - M);
	float lambert = max(0.2, dot(normal, l.direction));

	//Specular Lighting
	vec3 reflection = normalize(reflect(l.direction, normal));
	vec3 viewDirection = normalize(I);
	float spec = max(0.0, dot(reflection, viewDirection));
	spec = lambert+pow(spec, 32);

	return spec;
}

float intersect(Cam c, Sphere s)
{
	//t = -direction * (origin-center) +- sqrt( (direction*(origin-center))² - length(direction)²*(length(origin-center)²-radius²) )
	vec3 MO = c.origin-s.position;
	float al1 = -dot(c.direction, (MO));
	float discriminant = quad(dot(c.direction, MO)) - quad(length(c.direction)) * (quad(length(MO)) - quad(s.radius));

	if(discriminant < 0.001) return -1000.0;

	float t1 = al1 + sqrt( discriminant );
	float t2 = al1 - sqrt( discriminant );

	float t = 0.0;
	t = t2>0 ? t2 : t1;	//t2 is smaller than t1, just check if t2<0

	return t;
}