use packer::Packer;
use image::Pixel;
use image::GenericImage;
use image::ImageBuffer;
use image::imageops::{ rotate90 };
use rect::Rect;
use std::io::Result;
use std::path::Path;
struct TexturePacker<P: Packer, U: Pixel> {
	packer: P,
	texture: ImageBuffer<U, Vec<U::Subpixel>>,
	margin: u32,
}

pub enum SubTexture {
	R0(Rect),
	R90(Rect)
}

impl<P: Packer, U: Pixel> TexturePacker<P, U>
  where U::Subpixel: 'static, U: 'static {
	fn new(w: u32, h: u32, margin: u32) -> Self {
		TexturePacker {
			packer: P::new(w, h),
			texture: ImageBuffer::new(w, h),
			margin: margin,
		}
	}
	fn insert<T2: GenericImage<Pixel=U>>(&mut self, t: &T2) -> Option<SubTexture>
	  where T2: 'static {
		let (w, h) = (t.width()+self.margin*2, t.height()+self.margin*2);
		match self.packer.alloc(w, h) {
			Some(r) => {
				let mut sub = self.texture.sub_image(r.x, r.y, r.w, r.h);
				sub.copy_from(t, 0, 0);

				Some(SubTexture::R0(r))
			},
			_ => match self.packer.alloc(h, w) {
				Some(r) => {
					let mut sub = self.texture.sub_image(r.x, r.y, r.w, r.h);
					let rotated = rotate90(t);
					sub.copy_from(&rotated, 0, 0);

					Some(SubTexture::R90(r))
				},
				_ => None
			}
		}
	}
}

impl<P: Packer, U: Pixel<Subpixel=u8>> TexturePacker<P, U> where U: 'static {
	fn write_to_file(&mut self, name: &str) -> Result<()> {
		let (w, h) = (self.texture.width(), self.texture.height());
		self.texture.sub_image(0, 0, w, h).to_image().save(&Path::new(name))
	}
}
