#![allow(dead_code)]
extern crate image;
extern crate docopt;
extern crate rustc_serialize;
extern crate byteorder;
use byteorder::{ LittleEndian, WriteBytesExt };
use docopt::Docopt;
use std::fs::File;
use std::path::Path;
use std::io::{ BufReader, BufRead, BufWriter };
use texture_packer::TexturePacker;
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
	arg_INPUT: String,
	arg_OUTPUT: String,
	arg_INDEX: String,
	arg_w: u32,
	arg_h: u32,
}

fn main() {
	let args: Args = Docopt::new(USAGE)
	                        .and_then(|d| d.decode())
	                        .unwrap_or_else(|e| e.exit());
	let f = File::open(&args.arg_INPUT).unwrap();
	let idxf = File::create(&args.arg_INDEX).unwrap();
	let reader = BufReader::new(f);
	let mut iw = BufWriter::new(idxf);
	let mut pak = TexturePacker::<Guillotine, image::Rgba<u8>>::new(args.arg_w, args.arg_h, 5);
	let base = Path::new(&args.flag_b);

	iw.write_u32::<LittleEndian>(args.arg_w).unwrap();
	iw.write_u32::<LittleEndian>(args.arg_h).unwrap();

	//Read from input
	for (i, _name) in reader.lines().enumerate() {
		//Try to open texture
		let name = _name.unwrap();
		let n : Vec<&str> = name.split(":").collect();
		match image::open(base.join(n[1])) {
			Ok(img) => {
				let res = pak.insert(&img);
				if let Some(r) = res {
					println!("{}, {}: {:?}", i, n[0], r);
				} else {
					println!("Failed to allocate for {}", n[1]);
				}
			},
			Err(e) => println!("Failed to load image {:?}", e)
		}
	}

	pak.save(args.arg_OUTPUT).unwrap();
}
