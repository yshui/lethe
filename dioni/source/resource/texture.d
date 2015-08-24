module resource.texture;
import ast.decl, ast.type;
import std.stdio, std.string, std.path, std.array;
import binary.reader: binaryReader;
import binary.common: ByteOrder;
import utils;
import error;

struct rect {
	float x, y, w, h;
	ubyte dir;
}

class TexturePack : Storage {
	string name, fname;
	rect[string] byname;
	rect[] byid;
	int texture_id;
	float w, h;
	@safe this(string filename, string x) {
		fname = filename;
		name = x;
	}
	@trusted void load(string base) {
		auto idxf = File(base.chainPath(fname).array, "r");
		auto r = bufreader(idxf.byChunk(4096));
		auto reader = binaryReader(r, ByteOrder.LittleEndian);
		uint _w, _h, count;
		reader.read!uint(_w);
		reader.read!uint(_h);
		reader.read!uint(count);
		writeln("W: ", _w);
		writeln("H: ", _h);
		byid.length = count;
		w = cast(float)_w;
		h = cast(float)_h;
		foreach(i; 0..count) {
			ubyte nlen;
			ubyte[] nameb;
			string name;

			reader.read!ubyte(nlen);

			name.length = nlen;
			reader.readArray!ubyte(nameb, nlen);

			name = nameb.assumeUTF;
			writeln("Name: ", name);
			reader.read!ubyte(byid[i].dir);

			uint[4] tmp;
			reader.read!(uint[4])(tmp);
			byid[i].x = cast(float)tmp[0]/w;
			byid[i].y = cast(float)tmp[1]/h;
			byid[i].w = cast(float)tmp[2]/w;
			byid[i].h = cast(float)tmp[3]/h;

			byname[name] = byid[i];
		}
	}

override :
	string c_access(AccessType at, out TypeBase ty) const {
		venforce!AccessError(at != AccessType.Write, name, at);
		auto r = rect(0, 0, w, h, 0);
		ty = new Type!TexturePack(this);
		return "";
	}
	string symbol() const { return name; }
	string str() const { return "Texture "~name; }
}
