use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Player {
    #[key]
    pub address: ContractAddress,
    pub hp: u16,
    pub max_hp: u16,
    pub is_alive: bool,
}

#[generate_trait]
impl PlayerImpl of PlayerTrait {
    fn new(address: ContractAddress, max_hp: u16) -> Player {
        Player {
            address,
            hp: max_hp,
            max_hp,
            is_alive: true,
        }
    }

    fn take_damage(ref self: Player, damage: u16) {
        if self.hp <= damage {
            self.hp = 0;
            self.is_alive = false;
        } else {
            self.hp -= damage;
        }
    }

    fn resurrect(ref self: Player) {
        assert(self.hp == 0, 'Player is not dead');
        self.hp = self.max_hp;
        self.is_alive = true;
    }
} 