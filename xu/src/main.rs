#![allow(dead_code)]
extern crate image;
extern crate docopt;
extern crate rustc_serialize;
extern crate byteorder;
use byteorder::{ LittleEndian, WriteBytesExt };
use docopt::Docopt;
use std::fs::File;
use std::path::Path;
use std::io::{ BufReader, BufRead, BufWriter, Cursor, Write };
use texture_packer::{ TexturePacker, SubTexture };
use packer::guillotine::Guillotine;
mod packer;
mod rect;
mod texture_packer;
static USAGE: &'static str = "
Naval Fate.

Usage:
	xu -b BASE -i INDEX <w> <h> INPUT OUTPUT
	xu --help

Options:
	-h --help   Show this screen.
	-b BASE     Directory to search for textures
	-i INDEX    Path to the output index file
";

#[derive(Debug, RustcDecodable)]
#[allow(non_snake_case)]
struct Args {
	flag_b: String,
	flag_i: String,
	arg_INPUT: String,
	arg_OUTPUT: String,
	arg_w: u32,
	arg_h: u32,
}

fn main() {
	let args: Args = Docopt::new(USAGE)
	                        .and_then(|d| d.decode())
	                        .unwrap_or_else(|e| e.exit());
	let f = File::open(&args.arg_INPUT).unwrap();
	let idxf = File::create(&args.flag_i).unwrap();
	let reader = BufReader::new(f);
	let mut iw = BufWriter::new(idxf);
	let mut pak = TexturePacker::<Guillotine, image::Rgba<u8>>::new(args.arg_w, args.arg_h, 5);
	let base = Path::new(&args.flag_b);
	let mut ib = Cursor::new(Vec::new());
	let mut count = 0;

	iw.write_u32::<LittleEndian>(args.arg_w).unwrap();
	iw.write_u32::<LittleEndian>(args.arg_h).unwrap();

	//Read from input
	for (i, _name) in reader.lines().enumerate() {
		//Try to open texture
		let name = _name.unwrap();
		let n : Vec<&str> = name.split(":").collect();
		let nlen = n[0].len();
		assert!(nlen < 256, "Name '{}' is too long", n[0]);
		assert!(nlen > 0, "Name for {} is empty", n[1]);
		match image::open(base.join(n[1])) {
			Ok(img) => {
				let err = "Failed to allocate for ".to_string();
				let res = pak.insert(&img).expect(&(err+n[1]));
				let (dir, rect) = match res {
					SubTexture::R0(_r) => (0u8, _r),
					SubTexture::R90(_r) => (1u8, _r)
				};
				//Format:
				//<name_len:8><name><top left><w><h>
				ib.write_u8(nlen as u8).unwrap();
				ib.write_all(n[0].as_ref()).unwrap();
				ib.write_u8(dir).unwrap();
				ib.write_u32::<LittleEndian>(rect.x).unwrap();
				ib.write_u32::<LittleEndian>(rect.y).unwrap();
				ib.write_u32::<LittleEndian>(rect.w).unwrap();
				ib.write_u32::<LittleEndian>(rect.h).unwrap();
				println!("{}, {}: {:?}", i, n[0], res);
			},
			Err(e) => println!("Failed to load image {:?}", e)
		}
		count+=1;
	}

	iw.write_u32::<LittleEndian>(count).unwrap();
	iw.write_all(&ib.into_inner()).unwrap();

	pak.save(args.arg_OUTPUT).unwrap();
}
