use packer::Packer;
use image::GenericImage;
struct TexturePacker<P: Packer, T: GenericImage> {
	packer: P,
	texture: T,
}
