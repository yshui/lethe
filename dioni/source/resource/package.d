module resource;
import std.path, std.string;
import ast.decl;
public import resource.texture;
@safe :
Decl[] load_resource(string filename, string name) {
	final switch(filename.extension) {
		case ".idx":
			//Texture index
			if (name is null)
				name = filename[0..filename.indexOf('.')];
			return [new TexturePack(filename, name)];
		case ".dn":
			//Dioni source file
			assert(false);
	}
}
