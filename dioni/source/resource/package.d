module resource;
import std.path;

Decl[] load_resource(string filename, string name) {
	final switch(filename.extension) {
		case ".idx":
			//Texture index
			if (name is null)
				name = filename[0..filename.indexOf('.')];
			return new Texture(filename, name);
		case ".dn":
			//Dioni source file
			assert(false);
	}
}
