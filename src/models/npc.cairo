use core::fmt::{Display, Formatter, Error};

use dojo_starter::models::mission::{MissionStatus};
use dojo_starter::models::role::{Role};


#[derive(Drop, Serde)]
#[dojo::model]
pub struct NPC {
    #[key]
    pub id: u32,             
    pub name: ByteArray,        
    pub description: ByteArray,  
    pub dialogue: ByteArray,       
    pub is_active: bool,          
    pub importance_level: u8,      
    pub reward: u16,       
    pub experience_points: u16, 
    pub role: Role,            
    pub mission_status: MissionStatus,
}

// Function to create an NPC
fn create_npc(
    id: u32,
    name: ByteArray,
    description: ByteArray,
    dialogue: ByteArray,
    is_active: bool,
    importance_level: u8,
    reward: u16,
    experience_points: u16,
    role: Role,
    mission_status: MissionStatus,
) -> NPC {
    NPC {
        id,
        name,
        description,
        dialogue,
        is_active,
        importance_level,
        reward,
        experience_points,
        role,
        mission_status,
    }
}


impl NPCDisplay of Display<NPC> {
    fn fmt(self: @NPC, ref f: Formatter) -> Result<(), Error> {
        let name = self.name;
        let description = self.description;
        let dialogue = self.dialogue;
        let reward = self.reward;

        write!(f, "=== NPC Details ===\n")?;
        write!(f, "ID: {}\n", *self.id)?;
        write!(f, "Name: {}\n", name)?;
        write!(f, "Description: {}\n", description)?;
        write!(f, "Role: {}\n", *self.role)?;
        write!(f, "Dialogue: {}\n", dialogue)?;
        write!(f, "Mission Status: {}\n", *self.mission_status)?;
        write!(f, "Is Active: {}\n", *self.is_active)?;
        write!(f, "Reward: {}\n", reward)?;
        write!(f, "Experience Points: {}\n", *self.experience_points)?;
        write!(f, "=================\n")?;
        Result::Ok(())
    }
}


#[cfg(test)]
mod tests {
    use dojo_starter::models::mission::{MissionStatus};
    use dojo_starter::models::role::{Role};
    use dojo_starter::models::npc::{NPC, create_npc};
    use core::fmt::{Display, Formatter, Error};

    #[test]
    fn test_create_npc_function() {
        let id = 1_u32;
        let name = "Gandalf";
        let description = "The Grey Wizard";
        let dialogue = "You shall not pass!";
        let is_active = true;
        let importance_level = 10_u8;
        let reward = 100_u16;
        let experience_points = 500_u16;
        let role = Role::Guide;
        let mission_status = MissionStatus::NotStarted;

        let npc = create_npc(
            id,
            name.clone(), // Clone ByteArray
            description.clone(), // Clone ByteArray
            dialogue.clone(), // Clone ByteArray
            is_active,
            importance_level,
            reward,
            experience_points,
            role,
            mission_status
        );

        assert_eq!(npc.id, id, "ID should match");
        assert_eq!(npc.name, name, "Name should match");
        assert_eq!(npc.description, description, "Description should match");
        assert!(npc.is_active, "NPC should be active");
        assert_eq!(npc.importance_level, importance_level, "Importance level should match");
        assert_eq!(npc.reward, reward, "Reward should match");
        assert_eq!(npc.experience_points, experience_points, "Experience points should match");
        assert_eq!(npc.role, role, "Role should match");
        assert_eq!(npc.mission_status, mission_status, "Mission status should match");
    }

    #[test]
fn test_npc_display_details() {
    let npc = NPC {
        id: 1,
        name: "Gandalf",
        description: "The Grey Wizard",
        role: Role::Guide,
        dialogue: "You shall not pass!",
        is_active: true,
        importance_level: 10,
        reward: 100,
        experience_points: 500,
        mission_status: MissionStatus::NotStarted,
    };

    let details = format!("{}", npc);

    let expected_details: ByteArray = "=== NPC Details ===\n"
        + "ID: 1\n"
        + "Name: Gandalf\n"
        + "Description: The Grey Wizard\n"
        + "Role: Guide\n"
        + "Dialogue: You shall not pass!\n"
        + "Mission Status: NotStarted\n"
        + "Is Active: true\n"
        + "Reward: 100\n"
        + "Experience Points: 500\n"
        + "=================\n";

    println!("Generated Details:\n{}", details);
    println!("Expected Details:\n{}", expected_details);

    assert_eq!(details, expected_details, "NPC details do not match the expected output");
}


    #[test]
    fn test_npc_creation() {
        let npc = NPC {
            id: 1,
            name: "Mago OZ",
            description: "A wise old wizard",
            role: Role::Guide,
            dialogue: "Welcome to Middle-earth!",
            is_active: true,
            importance_level: 5,
            mission_status: MissionStatus::NotStarted,
            reward: 50,
            experience_points: 100,
        };

        assert_eq!(npc.id, 1);
        assert_eq!(npc.name, "Mago OZ");
        assert_eq!(npc.description, "A wise old wizard");
        assert_eq!(npc.role.into(), 2);
        assert!(npc.is_active);
        assert_eq!(npc.importance_level, 5);
        assert_eq!(npc.mission_status.into(), 0); 
        assert_eq!(npc.reward, 50);
        assert_eq!(npc.experience_points, 100);
    }

    #[test]
    fn test_npc_role_conversion() {
        let role_guide: felt252 = Role::Guide.into();
        assert_eq!(role_guide, 2);

        let role_vendor: felt252 = Role::Vendor.into();
        assert_eq!(role_vendor, 0);
    }

    #[test]
    fn test_mission_status_conversion() {
        let status_in_progress: felt252 = MissionStatus::InProgress.into();
        assert_eq!(status_in_progress, 1);

        let status_completed: felt252 = MissionStatus::Completed.into();
        assert_eq!(status_completed, 2);
    }
}