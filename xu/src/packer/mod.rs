use rect::Rect;
pub mod guillotine;
pub trait Packer {
	fn new(w: u32, h: u32) -> Self;
	fn alloc(&mut self, w: u32, h: u32) -> Option<Rect>;
}
