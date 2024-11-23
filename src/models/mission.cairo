use core::fmt::{Display, Formatter, Error};

#[derive(Serde, Copy, Drop, Introspect, Debug, PartialEq)]
pub enum MissionStatus {
    NotStarted,
    InProgress,
    Completed,
    Failed,
}

impl MissionDisplay of Display<MissionStatus> {
    fn fmt(self: @MissionStatus, ref f: Formatter) -> Result<(), Error> {
        match self {
            MissionStatus::NotStarted => write!(f, "NotStarted"),
            MissionStatus::InProgress => write!(f, "InProgress"),
            MissionStatus::Completed => write!(f, "Completed"),
            MissionStatus::Failed => write!(f, "Failed"),
        }
    }
}


impl MissionStatusIntoFelt252 of Into<MissionStatus, felt252> {
    fn into(self: MissionStatus) -> felt252 {
        match self {
            MissionStatus::NotStarted => 0,
            MissionStatus::InProgress => 1,
            MissionStatus::Completed => 2,
            MissionStatus::Failed => 3,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{MissionStatus, MissionStatusIntoFelt252};

    #[test]
    fn test_mission_status_into_felt252() {

        let not_started = MissionStatus::NotStarted;
        let in_progress = MissionStatus::InProgress;
        let completed = MissionStatus::Completed;
        let failed = MissionStatus::Failed;

        assert_eq!(not_started.into(), 0, "MissionStatus::NotStarted should be 0");
        assert_eq!(in_progress.into(), 1, "MissionStatus::InProgress should be 1");
        assert_eq!(completed.into(), 2, "MissionStatus::Completed should be 2");
        assert_eq!(failed.into(), 3, "MissionStatus::Failed should be 3");
    }
}