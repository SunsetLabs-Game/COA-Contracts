use core::starknet::{ContractAddress, get_caller_address};
use starknet::storage::{
    StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait, Map,
};
use core::debug::PrintTrait;
use core::array::ArrayTrait;
use core::array::Array;

const MAX_RARE_Items_CAPACITY: usize = 10;

#[derive(Drop, Serde, Clone)]
#[dojo::model]
pub struct rare_items {
    #[key]
    pub player: ContractAddress,
    pub items: Array<rareItem>,
    
}

#[derive(Serde, Copy, Drop)]
#[dojo::model]
pub struct rareItem {
    #[key]
    pub item_id: u32,
    pub item_source: RareItemSource,
}

#[derive(Copy, Drop, Serde, Introspect)]
pub enum RareItemSource {
    Mission,
    Enemy,
}

#[generate_trait]
impl rareItemImpl of rareItemTrait {
    fn new(item_id: u32, item_source: RareItemSource) -> rareItem {
        rareItem { item_id, item_source, }
    }
}

#[generate_trait]
impl rare_itemsImpl of rare_itemsTrait {
    // New rare_items
    fn new(player: ContractAddress) -> rare_items {
        rare_items { player, items: ArrayTrait::new(), }
    }

    fn has_available_item( self: rare_items, id: u32) -> bool {
        let mut found = false;
        // Check if the item already exists
        for i in 0 ..self.items.len() {
                if self.items[i].item_id == @id {
                    found = true;
                    break;
                }
            };
        return found;
    }

    // New item
    fn add_rare_item(ref self: rare_items, rareItem: rareItem) -> bool {
       
        // Add item
        self.items.append(rareItem);
        true
    }
}


#[cfg(test)]
mod tests {
    use super::{
        rare_items, rare_itemsImpl, rareItem, rareItemImpl, rareItemTrait, RareItemSource,
        MAX_RARE_Items_CAPACITY
    };

    use core::debug::PrintTrait;

    #[test]
    fn test_new_rare_items() {
        let player = starknet::contract_address_const::<
            0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2
        >();
        let inventory = rare_itemsImpl::new(player);
        assert(inventory.player == player, 'Invalid player address');
        // assert(inventory.items == rareItem, 'Should be set');
        // assert(inventory.max_capacity == 10, 'Invalid max capacity');
        assert(inventory.items.len() == 0, 'Should start empty');
    }

    #[test]
    fn test_add_rare_item() {
        let player = starknet::contract_address_const::<
            0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2
        >();
        let mut inventory = rare_itemsImpl::new(player);
        let source = RareItemSource::Mission;
        let item = rareItemImpl::new(1, source);

        assert(inventory.add_rare_item(item), 'Should add item');
        assert(inventory.items.len() == 1, 'Should have one item');

        let i_rareItem = inventory.items[0];
        assert(i_rareItem.item_id == @1, 'item id mismatch');
    //assert(i_rareItem.item_source ==  source, 'source mismatch');
    }

    #[test]
    fn test_has_available_item() {
        let player = starknet::contract_address_const::<
            0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2
        >();
        let mut inventory = rare_itemsImpl::new(player);
        let source = RareItemSource::Mission;
        let id: u32 = 19;
        let item = rareItemImpl::new(id, source);

        assert(inventory.add_rare_item(item), 'Should add item');
        assert(inventory.items.len() == 1, 'Should have one item');

        let has_available = rare_itemsImpl::has_available_item(inventory, id);
        assert!(has_available, "item_id not in items");
    }
    #[test]
    fn test_new_rareItem() {
        let source = RareItemSource::Mission;
        let id: u32 = 19;
        let item = rareItemImpl::new(id, source);
        assert(item.item_id == id, ' mismatch item Id');
        //   assert(item.item_source == source, ' mismatch item source');
    }
}