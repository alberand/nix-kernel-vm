use clap::{Parser, Subcommand};
use std::path::PathBuf;
use std::process::Command;
use std::process::Stdio;
use tera::{Context, Tera};
use std::pipe;
use std::io::Write;

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

fn nurl(repo: &str, rev: &str) -> Result<String, std::string::FromUtf8Error> {
    let output = Command::new("nurl")
        .arg(repo)
        .arg(rev)
        .output()
        .expect("Failed to execute command");

    if !output.status.success() {
        // TODO need to throw and error
        println!("failed: {:?}", String::from_utf8(output.stderr));
    }

    String::from_utf8(output.stdout)
}

fn format_nix(code: String) -> Result<String, std::string::FromUtf8Error> {
    // Actually run the command
    let output = Command::new("alejandra")
        .stdin({
            // Unfortunately, it's not possible to provide a direct string as an input to a command
            // We actually need to provide an actual file descriptor (as is a usual stdin "pipe")
            // So we create a new pair of pipes here...
            let (reader, mut writer) = std::pipe::pipe().unwrap();

            // ...write the string to one end...
            writer.write_all(code.as_bytes()).unwrap();

            // ...and then transform the other to pipe it into the command as soon as it spawns!
            Stdio::from(reader)
        })
        .output()
        .expect("Failed to execute command");

    if !output.status.success() {
        // TODO need to throw and error
        println!("failed: {:?}", String::from_utf8(output.stderr));
    }

    String::from_utf8(output.stdout)
}

fn main() {
    let cli = Cli::parse();

    if Command::new("nurl")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_err()
    {
        panic!("No nurl");
    }

    if Command::new("alejandra")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_err()
    {
        println!("No alejandra. Your nix will be ugly");
    }

    let config = Config::load(cli.config).unwrap();

    let xfstests: String = if let Some(subconfig) = config.xfstests {
        let output = if let Some(rev) = subconfig.rev {
            nurl(&subconfig.repo.unwrap(), &rev).expect("Failed to parse xfstests source repo")
        } else {
            println!("no rev");
            String::from("")
        };

        output
    } else {
        println!("no subconfig");
        String::from("")
    };

    let xfsprogs: String = if let Some(subconfig) = config.xfsprogs {
        let output = if let Some(rev) = subconfig.rev {
            nurl(&subconfig.repo.unwrap(), &rev).expect("Failed to parse xfsprogs source repo")
        } else {
            String::from("")
        };

        output
    } else {
        String::from("")
    };

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
    tera.add_raw_template("top", source).unwrap();

    let mut context = Context::new();
    context.insert("xfstests", &xfstests);
    context.insert("xfsprogs", &xfsprogs);
    context.insert("kernel", "");

    let formatted = format_nix(tera.render("top", &context).unwrap()).unwrap();

    println!("{}", formatted);
}
