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
        rareItem { item_id, item_source }
    }
}

