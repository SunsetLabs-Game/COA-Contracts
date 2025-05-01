use starknet::ContractAddress;
use dojo_starter::models::item::{Item, ItemImpl, ItemTrait};

#[derive(Copy, Drop, Serde, Introspect)]
pub enum Slot {
    Head,
    Chest,
    Legs,
    Feet,
    Hands,
    MainHand,
    OffHand,
    Accessory,
    None,
}

impl SlotIntoFelt252 of Into<Slot, felt252> {
    fn into(self: Slot) -> felt252 {
        match self {
            Slot::Head => 0,
            Slot::Chest => 1,
            Slot::Legs => 2,
            Slot::Feet => 3,
            Slot::Hands => 4,
            Slot::MainHand => 5,
            Slot::OffHand => 6,
            Slot::Accessory => 7,
            Slot::None => 8,
        }
    }
}

impl SlotPartialEq of core::traits::PartialEq<Slot> {
    fn eq(lhs: @Slot, rhs: @Slot) -> bool {
        let lhs_felt: felt252 = (*lhs).into();
        let rhs_felt: felt252 = (*rhs).into();
        lhs_felt == rhs_felt
    }

    fn ne(lhs: @Slot, rhs: @Slot) -> bool {
        !(lhs == rhs)
    }
}

// The EquippedItem model associates a player with an item in a specific slot
#[derive(Drop, Serde, Clone)]
#[dojo::model]
pub struct EquippedItem {
    #[key]
    pub player_id: u32,
    #[key]
    pub slot: Slot,
    pub token_id: u256,
    pub is_equipped: bool,
}

#[generate_trait]
impl EquippedItemImpl of EquippedItemTrait {
    fn new(player_id: u32, slot: Slot, token_id: u256) -> EquippedItem {
        EquippedItem {
            player_id,
            slot,
            token_id,
            is_equipped: true,
        }
    }
    
    fn equip(ref self: EquippedItem, token_id: u256) {
        self.token_id = token_id;
        self.is_equipped = true;
    }
    
    fn unequip(ref self: EquippedItem) {
        self.is_equipped = false;
        self.token_id = 0_u256;
    }
}

#[cfg(test)]
mod tests {
    use super::{EquippedItem, EquippedItemImpl, Slot};

    #[test]
    fn test_new_equipped_item() {
        let player_id = 1;
        let slot = Slot::MainHand;
        let token_id = 5_u256;
        
        let equipped_item = EquippedItemImpl::new(player_id, slot, token_id);
        
        assert(equipped_item.player_id == player_id, 'Wrong player_id');
        assert(equipped_item.slot == slot, 'Wrong slot');
        assert(equipped_item.token_id == token_id, 'Wrong token_id');
        assert(equipped_item.is_equipped == true, 'Should be equipped');
    }

    #[test]
    fn test_equip_item() {
        let player_id = 1;
        let slot = Slot::MainHand;
        let old_token_id = 5_u256;
        let new_token_id = 10_u256;
        
        let mut equipped_item = EquippedItemImpl::new(player_id, slot, old_token_id);
        assert(equipped_item.token_id == old_token_id, 'Initial token wrong');
        
        // Equip new item
        equipped_item.equip(new_token_id);
        
        // Check that item was equipped correctly
        assert(equipped_item.token_id == new_token_id, 'New token not set');
        assert(equipped_item.is_equipped == true, 'Should be equipped');
    }

    #[test]
    fn test_unequip_item() {
        let player_id = 1;
        let slot = Slot::MainHand;
        let token_id = 5_u256;
        
        let mut equipped_item = EquippedItemImpl::new(player_id, slot, token_id);
        equipped_item.unequip();
        
        assert(equipped_item.is_equipped == false, 'Should be unequipped');
        assert(equipped_item.token_id == 0_u256, 'Token ID should be reset');
    }
} 