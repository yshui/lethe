use packer::Packer;
use rect::Rect;
use std::iter::Iterator;
pub struct Guillotine {
	free_areas: Vec<Rect>,
}

impl Guillotine {
	// Best Area Fit
	fn find_free_area(&self, w: u32, h: u32) -> Option<(usize, Rect)> {
		let mut index = None;
		let mut min_area = None;
		let mut rect = Rect::new(0, 0, 0, 0);

		for (i, ref area) in (&self.free_areas).into_iter().enumerate() {
			let a = area.area();

			if w <= area.w && h <= area.h {
				if min_area.is_none() || a < min_area.unwrap() {
					index = Some(i);
					min_area = Some(a);
					rect.x = area.x;
					rect.y = area.y;
					rect.w = w;
					rect.h = h;
				}
			}
		}

		match index {
			Some(i) => {
				Some((i, rect))
			},
			_ => {
				None
			},
		}
	}

	// Shorter Axis Split
	fn split(&mut self, index: usize, rect: &Rect) {
		let area = self.free_areas.remove(index);

		if area.w < area.h {
			// Split horizontally
			self.free_areas.push(Rect {
				x: area.x + rect.w,
				y: area.y,
				w: area.w - rect.w,
				h: rect.h,
			});

			self.free_areas.push(Rect {
				x: area.x,
				y: area.y + rect.h,
				w: area.w,
				h: area.h - rect.h,
			});
		} else {
			// Split vertically
			self.free_areas.push(Rect {
				x: area.x,
				y: area.y + rect.h,
				w: rect.w,
				h: area.h - rect.h,
			});

			self.free_areas.push(Rect {
				x: area.x + rect.w,
				y: area.y,
				w: area.w - rect.w,
				h: area.h,
			});
		}
	}
}

impl Packer for Guillotine {
	fn new(w: u32, h: u32) -> Guillotine {
		let mut free_areas = Vec::new();
		free_areas.push(Rect {
			x: 0,
			y: 0,
			w: w,
			h: h,
		});

		Guillotine {
			free_areas: free_areas,
		}
	}

	fn alloc(&mut self, w: u32, h: u32) -> Option<Rect> {
		match self.find_free_area(w, h) {
			Some((i, rect)) => {
				self.split(i, &rect);

				Some(rect)
			},
			_ => {
				None
			},
		}
	}
}

