
use bevy_math::Vec2;

use crate::core::structs::{body::Body, boundary::{Boundary}};

pub struct QuadTree {
    boundary: Boundary,
    capacity: usize,
    bodies: Vec<Body>,
    divided: bool,
    
    total_mass: f32,
    //neede to calculate the grater body
    center_of_mass: Vec2,

    //Box utilized because is recursive
    north_west: Option<Box<QuadTree>>,
    north_east: Option<Box<QuadTree>>,
    south_west: Option<Box<QuadTree>>,
    south_east: Option<Box<QuadTree>>
}

impl QuadTree {
    pub fn new(boundary: Boundary, capacity: usize) -> Self {
        Self {
            boundary,
            capacity,
            bodies: Vec::new(),
            divided: false,
            total_mass: 0.0,
            center_of_mass: Vec2::ZERO,
            north_west: None,
            north_east: None,
            south_west: None,
            south_east: None,
        }
    }

    fn divide(&mut self) {
        let x = self.boundary.center.x;
        let y = self.boundary.center.y;
        let h = self.boundary.half_size / 2.0;

        self.north_west = Some(Box::new(QuadTree::new(
            Boundary {
                center: Vec2 { x: x - h, y: y + h },
                half_size: h,
            },
            self.capacity,
        )));

        self.north_east = Some(Box::new(QuadTree::new(
            Boundary {
                center: Vec2 { x: x + h, y: y + h },
                half_size: h,
            },
            self.capacity,
        )));

        self.south_west = Some(Box::new(QuadTree::new(
            Boundary {
                center: Vec2 { x: x - h, y: y - h },
                half_size: h,
            },
            self.capacity,
        )));

        self.south_east = Some(Box::new(QuadTree::new(
            Boundary {
                center: Vec2 { x: x + h, y: y - h },
                half_size: h,
            },
            self.capacity,
        )));

        self.divided = true;
    }

    fn update_mass_distribution(&mut self, body: Body) {
        let previous = self.total_mass;
        let new = previous + body.mass;

        if new == 0.0 {
            return;
        }
    
        self.center_of_mass.x = 
            self.center_of_mass.x
            * previous 
            + body.position.x 
            * body.mass 
            / new
        ;

        self.center_of_mass.y = 
            self.center_of_mass.y
            * previous 
            + body.position.y 
            * body.mass 
            / new
        ;

        self.total_mass = new;
    }

    fn insert(&mut self, body: Body) -> bool {
        if !self.boundary.contains(body.position) {
            return false;
        }

        if self.bodies.len() < self.capacity && !self.divided {
            self.bodies.push(body);
            return true;
        }

        if !self.divided {
            self.divide();
        }

        if self.north_west.as_mut().unwrap().insert(body) {
            return true;
        }
        
        if self.north_east.as_mut().unwrap().insert(body) {
            return true
        }

        if self.south_west.as_mut().unwrap().insert(body) {
            return true;
        }

        if self.south_east.as_mut().unwrap().insert(body) {
            return true;
        }

        false
    }
}

