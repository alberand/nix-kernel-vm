use serde::{Serialize, Deserialize};
use toml;
use std::path::PathBuf;
use std::fs;
use std::io::{Write,Error,ErrorKind};

#[derive(Serialize, Deserialize, Default)]
struct KernelConfig {
    kernel: String,
}

#[derive(Serialize, Deserialize, Default)]
struct XfstestsConfig {
    repo: String,
    rev: String,
    args: String,
    test_dev: String,
    scratch_dev: String,
    hooks: String,
}

#[derive(Serialize, Deserialize, Default)]
struct XfsprogsConfig {
    repo: String,
    rev: String,
}

#[derive(Serialize, Deserialize, Default)]
struct DummyConfig {
    script: String,
}


#[derive(Serialize, Deserialize, Default)]
pub struct Config {
   kernel: KernelConfig,
   xfstests: XfstestsConfig,
   xfsprogs: XfsprogsConfig,
   dummy: DummyConfig,
}

impl Config {
    pub fn load(path: Option<PathBuf>) -> Result<Self, Error> {
        if path.is_none() {
            return Ok(Config::default());
        }
        let path = path.unwrap();

        if !path.exists() {
            return Err(Error::new(ErrorKind::NotFound, "config file not found"))
        }
        println!("Loading config: {}", path.display());

        let data = fs::read_to_string(path).expect("Unable to read file");
        let config: Config = toml::from_str(&data).unwrap();

        Ok(config)
    }

    pub fn _save(&self, path: PathBuf) -> Result<(), Error> {
        let mut buffer = std::fs::File::create(path)?;
        buffer.write_all(toml::to_string(self).unwrap().as_bytes())
    }
}
