#[derive(Drop, Serde, Clone)] 
#[dojo::model]
pub struct Item {
    #[key]  
    pub id: u32,               
    pub name: ByteArray,       
    pub description: ByteArray, 
    pub value: u16,             
}

#[generate_trait]
impl ItemImpl of ItemTrait {
    fn new(id: u32, name: ByteArray, description: ByteArray, value: u16) -> Item {
        Item {
            id,
            name,
            description,
            value,
        }
    }

    fn update_value(ref self: Item, new_value: u16) {
        self.value = new_value;
    }
}



