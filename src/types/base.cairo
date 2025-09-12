pub const CREDITS: u256 = 0x1;

pub mod Ammo {
    /// from 0x100 to 0x1ff
    pub const HAND_GUN: u256 = 0x100;
    pub const MACHINE_GUN: u256 = 0x101;
}

pub trait ModelsTrait<T> {
    fn use_item(ref self: T);
}
