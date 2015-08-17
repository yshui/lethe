module resource.texture;
import ast.decl, ast.type;
import std.stdio, std.string;
import binary.reader: binaryReader;
import binary.common: ByteOrder;
import utils;

struct rect {
	float x, y, w, h;
	ubyte dir;
}

class TexturePack : Storage {
	string name, fname;
	rect[string] byname;
	rect[] byid;
	int texture_id;
	this(string filename, string x,int id) {
		auto idxf = File(filename, "r");
		auto r = bufreader(idxf.byChunk(4096));
		auto reader = binaryReader(r, ByteOrder.LittleEndian);
		uint _w, _h, count;
		float w, h;
		reader.read!uint(_w);
		reader.read!uint(_h);
		reader.read!uint(count);
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
			reader.read!ubyte(byid[i].dir);

			uint[4] tmp;
			reader.read!(uint[4])(tmp);
			byid[i].x = cast(float)tmp[0]/w;
			byid[i].y = cast(float)tmp[1]/h;
			byid[i].w = cast(float)tmp[2]/w;
			byid[i].h = cast(float)tmp[3]/h;

			byname[name] = byid[i];
		}
		name = x;
		fname = filename;
		texture_id = id;
	}

override :
	string c_access(AccessType at, out TypeBase ty) const {
		assert(at != AccessType.Write);
		ty = new TextureType;
		return "("~to!string(texture_id)~")";
	}
	string symbol() const { return name; }
	string str() const { return "Texture "~name; }
}
