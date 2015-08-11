module resource.texture;
import ast.decl;
import std.stdio, std.string;
import binary.reader: binaryReader;
import binary.common: ByteOrder;
import utils;

struct rect {
	float x, y, w, h;
	ubyte dir;
}

class TexturePack : Decl {
	string name;
	rect[string] byname;
	rect[] byid;
	this(string filename) {
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
	}

override :
	string symbol() const { return name; }
}
