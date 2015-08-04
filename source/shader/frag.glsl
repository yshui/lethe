in vec2 v_tex;
in float a;

out vec4 color;

uniform sampler2D tex;

void main() {
	vec4 tmp = texture(tex, v_tex);
	color = vec4(tmp.x, tmp.y, tmp.z, a);
}
