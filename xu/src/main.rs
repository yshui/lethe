#![allow(dead_code)]
extern crate image;
extern crate docopt;
extern crate rustc_serialize;
use docopt::Docopt;
use std::fs::File;
use std::path::Path;
use std::io::{ BufReader, BufRead };
use texture_packer::TexturePacker;
use packer::guillotine::Guillotine;
mod packer;
mod rect;
mod texture_packer;
static USAGE: &'static str = "
Naval Fate.

Usage:
	xu -b BASE <w> <h> INPUT OUTPUT
	xu --help

Options:
	-h --help   Show this screen.
	-b BASE     Directory to search for textures
";

#[derive(Debug, RustcDecodable)]
#[allow(non_snake_case)]
struct Args {
	flag_b: String,
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
	let reader = BufReader::new(f);
	let mut pak = TexturePacker::<Guillotine, image::Rgba<u8>>::new(args.arg_w, args.arg_h, 5);
	let base = Path::new(&args.flag_b);

	//Read from input
	for (i, _name) in reader.lines().enumerate() {
		//Try to open texture
		let name = _name.unwrap();
		match image::open(base.join(&name)) {
			Ok(img) => {
				let res = pak.insert(&img);
				if let Some(r) = res {
					println!("{:?}", r);
				} else {
					println!("Failed to allocate for {}", name);
				}
			},
			Err(e) => println!("Failed to load image {:?}", e)
		}
	}

	pak.save(args.arg_OUTPUT).unwrap();
}
