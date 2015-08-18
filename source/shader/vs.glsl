in vec2 translate;
in vec2 position;
in float angle;
in vec2 texture_coord;
in float alpha;
uniform float w, h;

out vec2 v_tex;
out float a;

#define M_PI 3.1415926535897932384626433832795

mat4 rotate2d(float angle) {
	return
	mat4( cos( angle ), -sin( angle ), 0.0, 0.0,
	      sin( angle ),  cos( angle ), 0.0, 0.0,
	      0.0,           0.0,          1.0, 0.0,
	      0.0,           0.0,          0.0, 1.0 );
}
void main() {
	float rad = angle/180*M_PI;
	vec4 pos4 = vec4(position.x, position.y, 0.0, 1.0)*rotate2d(rad);
	pos4 += vec4(translate.x, translate.y, 0.0, 0.0);
	pos4.x = pos4.x/w*2.0-1.0;
	pos4.y = pos4.y/h*2.0-1.0;
	gl_Position = pos4;
	//gl_Position = vec4(0.0, 0.0, 0.0, 0.0);
	v_tex = texture_coord;
	a = alpha;
}
