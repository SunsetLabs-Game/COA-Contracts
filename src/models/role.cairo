use core::fmt::{Display, Formatter, Error};

#[derive(Serde, Copy, Drop, Introspect, Debug, PartialEq)]
pub enum Role {
    Vendor,
    Trainer,
    Guide,
    Merchant,
    Mercenary,
    Enemy,
}

impl RoleDisplay of Display<Role> {
    fn fmt(self: @Role, ref f: Formatter) -> Result<(), Error> {
        match self {
            Role::Vendor => write!(f, "Vendor"),
            Role::Trainer => write!(f, "Trainer"),
            Role::Guide => write!(f, "Guide"),
            Role::Merchant => write!(f, "Merchant"),
            Role::Mercenary => write!(f, "Mercenary"),
            Role::Enemy => write!(f, "Enemy"),
        }
    }
}


impl RoleIntoFelt252 of Into<Role, felt252> {
    fn into(self: Role) -> felt252 {
        match self {
            Role::Vendor => 0,
            Role::Trainer => 1,
            Role::Guide => 2,
            Role::Merchant => 3,
            Role::Mercenary => 4,
            Role::Enemy => 5,
        }
    }
}