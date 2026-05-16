use bevy_math::Vec2;

#[derive(Clone, Copy, Debug)]
pub struct Boundary {
    pub center: Vec2,
    pub half_size: f32
}

impl Boundary {
    pub fn contains(&self, point: Vec2) -> bool {
        point.x >= self.center.x - self.half_size && 
        point.x <= self.center.x + self.half_size && 
        point.y >= self.center.y - self.half_size && 
        point.y <= self.center.y + self.half_size
    }
}