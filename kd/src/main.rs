use std::path::PathBuf;
use clap::{Parser, Subcommand};
use tera::{Context, Tera};
use std::process::Command;

// kd config CONFIG_XFS_FS=y
// kd build [vm|iso]
// kd run
// kd deploy [path]
//

mod config;
use config::Config;


#[derive(Parser)]
#[command(version)]
#[command(name = "kd")]
#[command(about = "linux kernel development tool", long_about = None)]
struct Cli {
    /// Sets a custom config file
    #[arg(short, long, value_name = "FILE")]
    config: Option<PathBuf>,

    /// Turn debugging information on
    #[arg(short, long, action = clap::ArgAction::Count)]
    debug: u8,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// does testing things
    Test {
        /// lists test values
        #[arg(short, long)]
        list: bool,
    },

    Build {
        /// lists test values
        target: String,
    },

    Run,
}

fn main() {
    let cli = Cli::parse();

    let config = Config::load(cli.config).unwrap();

    // You can see how many times a particular flag or argument occurred
    // Note, only flags can have multiple occurrences
    match cli.debug {
        0 => println!("Debug mode is off"),
        1 => println!("Debug mode is kind of on"),
        2 => println!("Debug mode is on"),
        _ => println!("Don't be crazy"),
    }

    // You can check for the existence of subcommands, and if found use their
    // matches just as you would the top level cmd
    match &cli.command {
        Some(Commands::Test { list }) => {
            if *list {
                println!("Printing testing lists...");
            } else {
                println!("Not printing testing lists...");
            }
        }
        Some(Commands::Build { target }) => {
                println!("build command {:?}", target);
        }
        Some(Commands::Run) => {
                println!("Run command");
        }
        None => {}
    }

    // Continued program logic goes here...

    let mut tera = Tera::default();

    let source = r#"
        {pkgs}: with pkgs; {
            programs.xfstests.src = {{ xfstests }};
            programs.xfsprogs.src = {{ xfsprogs }};
            kernel = {
              version = "v6.13";
              modDirVersion = "6.13.0";
              src = {{ kernel }};
              kconfig = with pkgs.lib.kernel; {
                XFS_FS = yes;
                FS_VERITY = yes;
              };
            };
        }
    "#;
    tera.add_raw_template("hello", source).unwrap();

    let mut context = Context::new();
    context.insert("name", "Rust");

    println!("{}", tera.render("hello", &context).unwrap());
}
