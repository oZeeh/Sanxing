use bevy_math::Vec2;

#[derive(Clone, Copy, Debug)]
pub struct Body {
    pub position: Vec2,
    pub velocity: Vec2,
    pub mass: f32,
}
