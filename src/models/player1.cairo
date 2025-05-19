use starknet::{ContractAddress, contract_address_const};
use core::num::traits::zero::Zero;
use crate::models::healing_item::HealingItem;


#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct InventoryEntry {
    #[key]
    pub player_id: ContractAddress,
    pub token_id: felt252,
    pub quantity: u32,
}


#[generate_trait]
pub impl InventoryEntryImpl of InventoryEntryTrait {
    fn has_sufficient_quantity(self: @InventoryEntry, quantity: u32) -> bool {
        *self.quantity >= quantity
    }
}


#[derive(Copy, Drop, Serde, IntrospectPacked, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    pub address: ContractAddress,
    pub level: u8,
    pub xp: u32,
    pub hp: u16,
    pub max_hp: u16,
    pub coins: u128,
    pub starks: u128,
}

pub fn ZERO_ADDRESS() -> ContractAddress {
    contract_address_const::<0x0>()
}

#[generate_trait]
pub impl PlayerImpl of PlayerTrait {
    fn add_xp(ref self: Player, amount: u32) {
        self.xp += amount;
    }

    fn take_damage(ref self: Player, damage: u16) {
        if damage >= self.hp {
            self.hp = 0;
        } else {
            self.hp -= damage;
        }
    }

    fn heal(ref self: Player, amount: u16) {
        self.hp = core::cmp::min(self.hp + amount, self.max_hp);
    }

    fn heal_using_item(
        ref self: Player, ref inventory_entry: InventoryEntry, healing_item: HealingItem,
    ) -> bool {
        // Check if the inventory entry token_id matches the healing item id
        if inventory_entry.token_id != healing_item.id {
            return false;
        }

        // Check if player has the item
        if !inventory_entry.has_sufficient_quantity(1) {
            return false;
        }

        let healing_amount = healing_item.effect_strength;
        self.heal(healing_amount);

        inventory_entry.quantity -= 1;

        return true;
    }
}


#[generate_trait]
pub impl PlayerAssert of AssertTrait {
    #[inline(always)]
    fn assert_exists(self: Player) {
        assert(self.is_non_zero(), 'Player: Does not exist');
    }

    #[inline(always)]
    fn assert_not_exists(self: Player) {
        assert(self.is_zero(), 'Player: Already exists');
    }
}

pub impl ZeroablePlayerTrait of Zero<Player> {
    #[inline(always)]
    fn zero() -> Player {
        Player { address: ZERO_ADDRESS(), level: 0, xp: 0, hp: 0, max_hp: 0, coins: 0, starks: 0 }
    }

    #[inline(always)]
    fn is_zero(self: @Player) -> bool {
        *self.address == ZERO_ADDRESS()
    }

    #[inline(always)]
    fn is_non_zero(self: @Player) -> bool {
        !self.is_zero()
    }
}


pub fn spawn_player(address: ContractAddress) -> Player {
    Player { address, level: 1, xp: 0, hp: 100, max_hp: 100, coins: 0, starks: 0 }
}

#[cfg(test)]
mod tests {
    use super::{Player, PlayerImpl, ZeroablePlayerTrait, InventoryEntry, InventoryEntryImpl};
    use starknet::{ContractAddress, contract_address_const};
    use crate::models::healing_item::HealingItem;

    #[test]
    fn test_player_initialization() {
        let addr: ContractAddress = contract_address_const::<0x123>();

        let player = Player {
            address: addr, level: 1, xp: 0, hp: 100, max_hp: 100, coins: 0, starks: 0,
        };

        assert(player.address == addr, 'Address mismatch');
        assert(player.level == 1, 'Invalid level');
        assert(player.hp == 100, 'Invalid hp');
        assert(player.coins == 0, 'Invalid coins');
    }

    #[test]
    fn test_zero_player() {
        let zero_player = ZeroablePlayerTrait::zero();
        assert(zero_player.is_zero(), 'Should be zero');
    }

    #[test]
    fn test_non_zero_player() {
        let addr: ContractAddress = contract_address_const::<0xABC>();

        let player = Player {
            address: addr, level: 1, xp: 0, hp: 100, max_hp: 100, coins: 0, starks: 0,
        };

        assert(player.is_non_zero(), 'Should be non-zero');
    }

    #[test]
    fn test_heal_using_item_success() {
        let addr: ContractAddress = contract_address_const::<0x123>();
        let mut player = Player {
            address: addr, level: 1, xp: 0, hp: 50, max_hp: 100, coins: 0, starks: 0,
        };

        let healing_potion = HealingItem {
            id: 1,
            name: 'Health Potion',
            description: 'Restores health when consumed',
            effect_strength: 30,
            consumable: true,
        };

        // Setup inventory with the healing item
        let mut inventory = InventoryEntry {
            player_id: addr, token_id: healing_potion.id, quantity: 3,
        };

        // Use the healing item
        let result = player.heal_using_item(ref inventory, healing_potion);

        assert(result == true, 'Healing should succeed');
        assert(player.hp == 80, 'HP should be 80 after healing');
        assert(inventory.quantity == 2, 'Item should be consumed');
    }

    #[test]
    fn test_heal_using_item_max_hp() {
        // Setup player with almost full health
        let addr: ContractAddress = contract_address_const::<0x123>();
        let mut player = Player {
            address: addr, level: 1, xp: 0, hp: 90, max_hp: 100, coins: 0, starks: 0,
        };

        // Setup healing item with high effect
        let strong_potion = HealingItem {
            id: 2,
            name: 'Strong Health Potion',
            description: 'Restores a lot of health',
            effect_strength: 50,
            consumable: true,
        };

        // Setup inventory with the healing item
        let mut inventory = InventoryEntry {
            player_id: addr, token_id: strong_potion.id, quantity: 1,
        };

        // Use the healing item
        let result = player.heal_using_item(ref inventory, strong_potion);

        assert(result == true, 'Healing should succeed');
        assert(player.hp == 100, 'HP should cap at max_hp');
        assert(inventory.quantity == 0, 'Item should be consumed');
    }

    #[test]
    fn test_heal_using_item_no_item() {
        // Setup player with reduced health
        let addr: ContractAddress = contract_address_const::<0x123>();
        let mut player = Player {
            address: addr, level: 1, xp: 0, hp: 50, max_hp: 100, coins: 0, starks: 0,
        };

        // Setup healing item
        let healing_potion = HealingItem {
            id: 1,
            name: 'Health Potion',
            description: 'Restores health when consumed',
            effect_strength: 30,
            consumable: true,
        };

        // Setup inventory with NO healing items
        let mut inventory = InventoryEntry {
            player_id: addr, token_id: healing_potion.id, quantity: 0,
        };

        let result = player.heal_using_item(ref inventory, healing_potion);

        assert(result == false, 'Healing should fail');
        assert(player.hp == 50, 'HP should remain unchanged');
        assert(inventory.quantity == 0, 'Inventory should be unchanged');
    }

    #[test]
    fn test_heal_using_item_id_mismatch() {
        // Setup player with reduced health
        let addr: ContractAddress = contract_address_const::<0x123>();
        let mut player = Player {
            address: addr, level: 1, xp: 0, hp: 50, max_hp: 100, coins: 0, starks: 0,
        };

        // Setup healing item
        let healing_potion = HealingItem {
            id: 1,
            name: 'Health Potion',
            description: 'Restores health when consumed',
            effect_strength: 30,
            consumable: true,
        };

        // Setup inventory with a DIFFERENT item id than the healing item
        let mut inventory = InventoryEntry { player_id: addr, token_id: 2, quantity: 5 };

        let result = player.heal_using_item(ref inventory, healing_potion);

        assert(result == false, 'Fail on ID mismatch');
        assert(player.hp == 50, 'HP should remain unchanged');
        assert(inventory.quantity == 5, 'Inventory should be unchanged');
    }

    #[test]
    fn test_heal_using_different_item_strengths() {
        // Setup player with reduced health
        let addr: ContractAddress = contract_address_const::<0x123>();
        let mut player = Player {
            address: addr, level: 1, xp: 0, hp: 40, max_hp: 100, coins: 0, starks: 0,
        };

        // Setup weak healing item
        let weak_potion = HealingItem {
            id: 1,
            name: 'Weak Health Potion',
            description: 'small amount of health',
            effect_strength: 10,
            consumable: true,
        };

        // Setup inventory with the weak healing item
        let mut inventory_weak = InventoryEntry {
            player_id: addr, token_id: weak_potion.id, quantity: 1,
        };

        let result_weak = player.heal_using_item(ref inventory_weak, weak_potion);

        assert(result_weak == true, 'Weak healing should succeed');
        assert(player.hp == 50, 'should be 50 after healing');

        // Setup strong healing item
        let strong_potion = HealingItem {
            id: 2,
            name: 'Strong Health Potion',
            description: 'large amount of health',
            effect_strength: 30,
            consumable: true,
        };

        // Setup inventory with the strong healing item
        let mut inventory_strong = InventoryEntry {
            player_id: addr, token_id: strong_potion.id, quantity: 1,
        };

        let result_strong = player.heal_using_item(ref inventory_strong, strong_potion);

        assert(result_strong == true, 'Strong healing should succeed');
        assert(player.hp == 80, 'should be 80 after healing');
    }
}
